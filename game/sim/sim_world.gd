class_name SimWorld
extends RefCounted
## Root of the headless simulation. Nothing in sim/ may touch Node or scenes
## (02_TECH_ARCHITECTURE.md section 3). Deterministic for a given seed.

const TICK_RATE: int = 30  # D-038
const SIM_DT: float = 1.0 / TICK_RATE

## Phases of step(), in tick order (D-083).
enum Phase { COMMANDS, PATH, SEPARATE, MOVE, DEATHS, SPAWN, GRID, TARGETING, ATTACKS }
## IDLE: no run started; still simulates (M1 demo, bench, tests). D-100.
enum RunState { IDLE, RUNNING, WON, LOST }

## Command clock: advances on every step(), paused or not, so replays address the same ticks.
var tick: int = 0
## Run clock: advances only while RUNNING and not paused (D-100).
var clock: int = 0
var run_state: RunState = RunState.IDLE
var paused: bool = false
## Loaded by StartRun; null before.
var run: RunData = null
var catalog: EnemyCatalog
var tower_catalog: TowerCatalog
## Events of the last step(), cleared at its start.
var events: SimEvents = SimEvents.new()
var enemies: SimEnemies = SimEnemies.new()
## Derived each tick from enemy positions; not part of state_hash().
var grid: SpatialGrid
var separation: EnemySeparation = EnemySeparation.new()
var towers: SimTowers = SimTowers.new()
## Card and meta effects on towers (D-144); reset at StartRun. Add through add_modifier().
var modifiers: SimModifiers = SimModifiers.new()
## Created at StartRun from the run's build radius and grid step; null before (D-109).
var build: BuildGrid = null
## Flow field over `build` (D-115); created (full first computation) in the PATH phase when
## `build` exists and the field does not match it. Derived: not in state_hash().
var field: FlowField = null
## Uid of the next placed tower: starts at 0, never reused (D-109).
var next_tower_uid: int = 0
var movement: EnemyMovement = EnemyMovement.new()
var tower_attacks: TowerAttacks = TowerAttacks.new()
## Skill cooldowns and the Shield; reset at StartRun (D-110).
var skills: GuardianSkills = GuardianSkills.new()
## Set from the run at StartRun (D-107); 0 before.
var guardian_hp: float = 0.0
var gold: int = 0
## Wall-clock usec of each phase of the last step(), indexed by Phase.
## Diagnostics only: never read by rules, not in state_hash(). A missing phase reads 0.
var phase_usec: PackedInt64Array = PackedInt64Array()
## Running sum of phase_usec over every step() (benchmark, task 008). Diagnostics only,
## not in state_hash(); the caller resets it.
var phase_usec_sum: PackedInt64Array = PackedInt64Array()
## Test/benchmark/demo setting: when > 0, every stopped enemy (ATTACKING or QUEUED) is moved back to a
## ring of this radius each tick (MOVING again), so a demo horde never empties.
## 0 = off. Runs spawn from their timeline instead (WaveSpawner).
var recycle_radius: float = 0.0
var _grid_count: int = -1
var _t: int = 0
# One RNG per concern, each seeded from the run seed (3a). Others add theirs the same way.
var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Sorted by tick, then enqueue order.
var _queue: Array[SimCommand] = []


func _init(run_seed: int, p_catalog: EnemyCatalog = null) -> void:
	catalog = p_catalog if p_catalog else EnemyCatalog.load_dir()
	tower_catalog = TowerCatalog.load_dir()
	phase_usec.resize(Phase.size())
	phase_usec_sum.resize(Phase.size())
	_seed_rngs(run_seed)
	movement.set_stop(catalog, 0.0)  # IDLE: no Guardian body, stop at own radius (M1)
	# Cell size = largest horde collision diameter (3a, D-108).
	grid = SpatialGrid.new(2.0 * catalog.max_radius)


func _seed_rngs(run_seed: int) -> void:
	_spawn_rng.seed = hash([run_seed, "spawns"])
	_loot_rng.seed = hash([run_seed, "loot"])


## Queues a command. A late command (tick already passed) is stamped to the current
## tick, and that stamped tick is what a replay must record (D-100).
func queue(cmd: SimCommand) -> void:
	cmd.tick = maxi(cmd.tick, tick)
	var i := _queue.size()
	while i > 0 and _queue[i - 1].tick > cmd.tick:
		i -= 1
	_queue.insert(i, cmd)


## Spawns count enemies of type_id on a ring of ring_radius around the Guardian,
## at angles drawn from the spawn RNG. Test/benchmark API; runs spawn through WaveSpawner.
func spawn_ring(p_type_id: int, count: int, ring_radius: float) -> void:
	var type_hp := catalog.hp[p_type_id]
	for n in count:
		var angle := _spawn_rng.randf() * TAU
		enemies.add(p_type_id, cos(angle) * ring_radius, sin(angle) * ring_radius, type_hp)


## Advances the simulation by exactly one tick of SIM_DT.
## Phase order and the grid invariant: 02_TECH_ARCHITECTURE.md 3a (D-083).
func step() -> void:
	events.clear()
	_t = Time.get_ticks_usec()
	# View interpolation (D-120). Packed arrays are shared on assignment: copy explicitly.
	enemies.prev_x = enemies.pos_x.duplicate()
	enemies.prev_z = enemies.pos_z.duplicate()
	while not _queue.is_empty() and _queue[0].tick <= tick:
		_apply(_queue.pop_front())
	_lap(Phase.COMMANDS)
	if paused or run_state == RunState.WON or run_state == RunState.LOST:
		tick += 1
		return
	_path()
	if towers.stats_dirty:  # once, after any layout, level or modifier change (D-144)
		TowerStats.recompute(self)
	_lap(Phase.PATH)
	if _grid_count != enemies.count():  # safety net: enemies added/removed outside step()
		_rebuild_grid()
		_t = Time.get_ticks_usec()
	separation.apply(enemies, grid, catalog, field)
	_lap(Phase.SEPARATE)
	movement.steer(enemies, field, build, towers, tower_catalog)
	movement.advance(enemies, catalog.speed, SIM_DT, separation.blocked)
	if field:
		movement.push_out(enemies, build, field)
	if recycle_radius > 0.0:
		_recycle()
	_lap(Phase.MOVE)
	_deaths()
	_lap(Phase.DEATHS)
	if run_state == RunState.RUNNING:
		WaveSpawner.step(clock, run, catalog, enemies, _spawn_rng, events)
	_lap(Phase.SPAWN)
	_rebuild_grid()
	_lap(Phase.GRID)
	towers.retarget(grid, enemies.pos_x, enemies.pos_z)
	_lap(Phase.TARGETING)
	if run_state == RunState.RUNNING:
		tower_attacks.fire(self)  # towers first: an enemy killed this tick does not attack (D-114)
		_enemy_attacks()
	_lap(Phase.ATTACKS)
	if run_state == RunState.RUNNING:
		clock += 1
	tick += 1


# A new build grid (StartRun, or set by a test or the bench) gets a new field, computed in
# full at once; then at most CELLS_PER_TICK units per tick, only after a layout change.
func _path() -> void:
	if build == null:
		return
	if field == null or field.grid != build:
		field = FlowField.new(build, run.guardian_contact_radius if run else 0.0)
		field.update(FlowField.FULL)
	field.update(FlowField.CELLS_PER_TICK)
	towers.refresh_uid_index(next_tower_uid)  # for steer and enemy attacks (D-116)


func _apply(cmd: SimCommand) -> void:
	match cmd.type:
		SimCommand.Type.START_RUN:
			if run_state != RunState.IDLE:
				return
			_seed_rngs(cmd.run_seed)
			run = RunData.load_id(cmd.run_id, catalog, tower_catalog)
			movement.set_stop(catalog, run.guardian_contact_radius)
			guardian_hp = run.guardian_hp
			gold = run.starting_gold
			build = BuildGrid.new(run.build_radius, run.grid_step)
			modifiers = SimModifiers.new()
			skills.reset(run.skill_ids.size())
			clock = 0
			run_state = RunState.RUNNING
		SimCommand.Type.PAUSE:
			paused = cmd.paused
		SimCommand.Type.PLACE_TOWER, SimCommand.Type.SELL_TOWER, SimCommand.Type.REBUILD_TOWER, \
				SimCommand.Type.UPGRADE_TOWER:
			if run_state != RunState.RUNNING or paused:  # no building while paused (D-105)
				return
			if cmd.type == SimCommand.Type.PLACE_TOWER:
				TowerBuilding.place(self, cmd)
			elif cmd.type == SimCommand.Type.SELL_TOWER:
				TowerBuilding.sell(self, cmd.tower_uid)
			elif cmd.type == SimCommand.Type.UPGRADE_TOWER:
				TowerUpgrade.upgrade(self, cmd.tower_uid)
			else:
				TowerBuilding.rebuild(self, cmd.tower_uid)
		SimCommand.Type.USE_SKILL:
			_use_skill(cmd.skill_id)


# Only while RUNNING and not paused; unknown id or cooldown: ignored, no event (D-110).
func _use_skill(skill_id: String) -> void:
	if run_state != RunState.RUNNING or paused:
		return
	var slot := run.skill_ids.find(skill_id)
	if slot < 0 or not skills.try_use(slot, clock, run):
		return
	events.push(SimEvents.Kind.SKILL_USED, slot, 0.0, 0.0, 0.0)
	if run.skill_kind[slot] == RunData.Skill.AREA_BLAST:
		_area_blast(slot)


# Every enemy whose body touches the disk around the Guardian (D-107 edge rule), index order.
# ponytail: linear scan, once per cooldown; the grid cannot reach boss radii.
func _area_blast(slot: int) -> void:
	var reach := run.skill_radius[slot]
	var dmg := run.skill_damage[slot]
	var px := enemies.pos_x
	var pz := enemies.pos_z
	for i in enemies.count():
		if sqrt(px[i] * px[i] + pz[i] * pz[i]) - catalog.radius[enemies.type_id[i]] <= reach:
			damage_enemy(i, dmg)


# In index order, no swap-remove: indices and count stay stable.
func _recycle() -> void:
	var st := enemies.state
	for i in st.size():
		if st[i] == SimEnemies.State.MOVING:
			continue
		var angle := _spawn_rng.randf() * TAU
		enemies.pos_x[i] = cos(angle) * recycle_radius
		enemies.pos_z[i] = sin(angle) * recycle_radius
		enemies.state[i] = SimEnemies.State.MOVING


## Adds a modifier entry (D-144); tower stats are recomputed in the next PATH phase.
func add_modifier(stat: String, op: SimModifiers.Op, value: float, target: String) -> void:
	modifiers.add(stat, op, value, target)
	towers.stats_dirty = true


## Single entry point for every damage source (towers, skills; D-107).
## A corpse (hp <= 0) ignores it; it is removed in the next DEATHS phase.
func damage_enemy(i: int, amount: float) -> void:
	if enemies.hp[i] <= 0.0:
		return
	enemies.hp[i] -= amount
	enemies.hit_tick[i] = tick
	events.push(SimEvents.Kind.ENEMY_HIT, enemies.type_id[i], enemies.pos_x[i], enemies.pos_z[i], amount)


## Single entry point for damage to towers (walled-in enemies, D-116). A lethal hit leaves a husk (D-104, D-109).
func damage_tower(t: int, amount: float) -> void:
	TowerBuilding.damage(self, t, amount)


# Highest index first, so a swap-remove never moves an unvisited enemy (D-081).
func _deaths() -> void:
	var hp := enemies.hp
	for i in range(enemies.count() - 1, -1, -1):
		if hp[i] > 0.0:
			continue
		var t := enemies.type_id[i]
		var x := enemies.pos_x[i]
		var z := enemies.pos_z[i]
		var chance := catalog.gold_chance[t]
		var gained := 0
		if chance >= 1.0 or _loot_rng.randf() < chance:
			gained = catalog.gold[t]
		if clock < enemies.mark_until[i]:  # D-145: after the base gold, not rolled
			gained += enemies.mark_gold[i]
		gold += gained
		enemies.remove(i)
		events.push(SimEvents.Kind.ENEMY_DIED, t, x, z, gained)
		if run and run_state == RunState.RUNNING and t == run.final_boss_type:
			run_state = RunState.WON
			events.push(SimEvents.Kind.RUN_ENDED, 1, 0.0, 0.0, 0.0)


# Instant hits (D-098): the first on arrival, then one every attack_cooldown ticks.
func _enemy_attacks() -> void:
	var hp := enemies.hp
	var st := enemies.state
	var cd := enemies.cooldown
	for i in enemies.count():
		if hp[i] <= 0.0:
			continue
		if cd[i] > 0:
			cd[i] -= 1
		if cd[i] == 0 and st[i] == SimEnemies.State.ATTACKING:
			var t := enemies.type_id[i]
			var u := enemies.target_id[i]
			if u >= 0:  # walled in: the blocking tower (D-116); gone or a husk: no hit, cd stays 0
				var k := towers.uid_index[u]
				if k < 0 or towers.husk[k]:
					continue
				cd[i] = catalog.attack_cooldown[t]
				events.push(SimEvents.Kind.TOWER_HIT, u, enemies.pos_x[i], enemies.pos_z[i], catalog.damage[t])
				damage_tower(k, catalog.damage[t])
				if towers.thorns[k] > 0.0:  # D-145: every landed hit, the lethal one too
					damage_enemy(i, towers.thorns[k])
				continue
			cd[i] = catalog.attack_cooldown[t]
			_hit_guardian(t, enemies.pos_x[i], enemies.pos_z[i], catalog.damage[t])
			if run_state == RunState.LOST:
				return


# Single path for damage to the Guardian: the Shield absorbs first (D-110).
func _hit_guardian(type_id: int, x: float, z: float, dmg: float) -> void:
	dmg = skills.absorb(dmg, clock)
	guardian_hp -= dmg
	events.push(SimEvents.Kind.GUARDIAN_HIT, type_id, x, z, dmg)
	if guardian_hp <= 0.0:
		run_state = RunState.LOST
		events.push(SimEvents.Kind.RUN_ENDED, 0, 0.0, 0.0, 0.0)


func _rebuild_grid() -> void:
	grid.rebuild(enemies.pos_x, enemies.pos_z)
	_grid_count = enemies.count()


func _lap(phase: Phase) -> void:
	var now := Time.get_ticks_usec()
	phase_usec[phase] = now - _t
	phase_usec_sum[phase] += now - _t
	_t = now


## Fingerprint of the whole sim state, used by determinism tests.
## Extend it with every entity array as they are added.
func state_hash() -> int:
	return hash([tick, clock, run_state, paused, run.id if run else "", _spawn_rng.state, _loot_rng.state,
		guardian_hp, gold, enemies.pos_x, enemies.pos_z, enemies.hp,
		enemies.type_id, enemies.state, enemies.anim_frame, enemies.cooldown, enemies.slow_factor, enemies.slow_ticks,
		enemies.target_id, enemies.mark_gold, enemies.mark_until,
		towers.pos_x, towers.pos_z, towers.attack_range, towers.target, next_tower_uid,
		towers.uid, towers.type_id, towers.hp, towers.husk, towers.paid, towers.cell_i, towers.cell_j,
		towers.cooldown, towers.level, towers.damage, towers.reload, towers.max_hp, towers.splash_radius,
		towers.slow_factor, towers.slow_ticks, towers.thorns, towers.mark_gold, towers.mark_ticks,
		towers.stats_dirty, modifiers.hash_parts(), skills.ready_at, skills.shield_left, skills.shield_until])
