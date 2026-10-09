# 012 — Sim: command queue, events and run state
- Status: review
- Milestone: M2
- Depends on: 011
- PR: #17

## Goal
Give the sim its only input channel (commands that carry the tick they apply to) and its output channel (events), plus the run state machine.

## Context
- `02_TECH_ARCHITECTURE.md` 3, 3a (sim contract, commands, events, tick order D-083)

## Acceptance criteria
- Commands: StartRun{seed, config}, Pause{bool}, PlaceTower, SellTower, UseSkill (handlers can be stubs filled by later tasks); each command carries its tick.
- Events out for the view: at least EnemyDied, EnemyHit, TowerPlaced, TowerDied, SkillUsed, GuardianHit, WaveStarted, RunEnded (emitted by later tasks).
- Run state: clock, paused, running, won, lost.
- Replay test: the same seed and the same command list give the same state hash.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Depends on 011 (StartRun loads `RunData`; both tasks append to `DECISIONS.md` and 3a). Decision ID: **D-100**. No data file or schema change.

### Files
1. `sim` (new) `game/sim/sim_command.gd`, `class_name SimCommand extends RefCounted`: `enum Type { START_RUN, PAUSE, PLACE_TOWER, SELL_TOWER, USE_SKILL }`; fields `tick: int`, `type: Type`, `run_seed: int`, `run_id: String` (the StartRun config = a `data/runs` id), `paused: bool`, `tower_id: String` (a `data/towers` id), `x: float`, `z: float`, `tower_uid: int` (a **stable** tower id that 015 assigns on placement, never an array index: indices change on removal, D-081), `skill_id: String` (a `data/skills` id). Static constructors, one per type: `start_run(tick, run_seed, run_id)`, `pause(tick, on)`, `place_tower(tick, tower_id, x, z)`, `sell_tower(tick, tower_uid)`, `use_skill(tick, skill_id)`. About 50 lines. `PickCard` (M3) and `ChooseGuardian` (the run file names the Guardian in M2) are not added.
2. `sim` (new) `game/sim/sim_events.gd`, `class_name SimEvents extends RefCounted`: events of the last `step()` as SoA, no object per event (EnemyHit can be hundreds per tick). `enum Kind { ENEMY_DIED, ENEMY_HIT, TOWER_PLACED, TOWER_DIED, SKILL_USED, GUARDIAN_HIT, WAVE_STARTED, RUN_ENDED }`; `kind: PackedInt32Array`, `a: PackedInt32Array`, `x`, `z`, `value: PackedFloat32Array`; `count: int`; `clear()` sets `count = 0` and keeps capacity; `push(kind, a, x, z, value)` writes at `count`, growing the arrays (doubling) only when full. No allocation once the peak is reached. Payload per kind (documented in 3a; later tasks fill it):
   | Kind | a | x, z | value |
   |---|---|---|---|
   | ENEMY_DIED | enemy type_id | position | gold gained |
   | ENEMY_HIT | enemy type_id | position | damage |
   | TOWER_PLACED | tower_uid | position | tower type |
   | TOWER_DIED | tower_uid | position | 0 |
   | SKILL_USED | skill slot | 0, 0 | 0 |
   | GUARDIAN_HIT | source enemy type_id | source position | damage after shield |
   | WAVE_STARTED | wave index (0-based) | 0, 0 | 0 |
   | RUN_ENDED | 1 won, 0 lost | 0, 0 | 0 |
   Enemy indices are never put in events (valid one tick only, D-081). About 40 lines.
3. `sim` `game/sim/sim_world.gd`:
   - `enum RunState { IDLE, RUNNING, WON, LOST }`; `run_state := RunState.IDLE`, `paused := false`, `clock: int = 0` (run ticks: advances only while RUNNING and not paused; 013's timeline reads it), `run: RunData = null`, `tower_catalog: TowerCatalog` (loaded in `_init`, like `catalog`), `events := SimEvents.new()`, `_queue: Array[SimCommand]`.
   - `queue(cmd: SimCommand)`: stamps `cmd.tick = maxi(cmd.tick, tick)` (a late command applies at the next step, and the stamped tick is what a replay must record), then inserts after every queued command with tick <= `cmd.tick` (stable: tick order, then enqueue order).
   - `_seed_rngs(run_seed)`: the existing `hash([run_seed, "spawns"])` seeding, used by `_init` and StartRun. Later concerns (loot, combat) add their line here.
   - `step()`: `events.clear()`; phase COMMANDS (new first phase): pop and apply every queued command with `tick <= self.tick`; if `paused` or `run_state` is WON or LOST: `tick += 1` and return (nothing moves; `tick` is the command clock and always advances, so a replay addresses the same ticks). Otherwise the existing phases, then `clock += 1` if RUNNING, then `tick += 1`. IDLE still runs the phases, so the M1 demo, bench and tests (which never send StartRun) behave as today.
   - `_apply(cmd)` with `match`: START_RUN (ignored unless IDLE): `_seed_rngs`, `run = RunData.load_id(cmd.run_id, catalog, tower_catalog)`, `clock = 0`, `run_state = RUNNING`. PAUSE: `paused = cmd.paused`. PLACE_TOWER / SELL_TOWER / USE_SKILL: stubs (`pass  # task 015` / `# task 017`).
   - `Phase` gets `COMMANDS` first: `phase_usec` / `phase_usec_sum` become size 5; `view/bench/bench.gd` resets `phase_usec_sum` with a 4-element literal (line 50) and names phases in `PHASES`: reset with `resize(SimWorld.Phase.size())` + `fill(0)` and add `commands` to `PHASES` (the bench report gains a `commands` phase).
   - `state_hash()` adds `run_state`, `paused`, `clock`. Run data is constant per run id, so `run` itself is not hashed; the id is (`run.id`, or "" when null; add `id` to `RunData` if 011 did not).
   - No `RunEnded` emission here (014 owns win/lose); no handler logic beyond the above.
4. `view`: only the bench fix above. 019 reads `world.events` after **each** `step()` (the driver can run up to 5 per frame and the buffer is cleared at the start of every step); a note is added to 019's Context.

### Tests (`game/tests/sim/`)
- `test_sim_commands.gd`: a command for tick 5 applies at the 6th `step()` (when `tick == 5`), not before; a late command (tick 2 queued at tick 10) is stamped 10; same-tick commands apply in enqueue order (Pause true then false leaves `paused == false`, reversed leaves true); StartRun moves IDLE -> RUNNING and loads `run_m2` (`run.wave_ticks > 0`); a second StartRun is ignored; `clock` advances only while RUNNING and not paused while `tick` always advances; paused world: enemy positions unchanged across steps; stub commands do not crash.
- `test_sim_events.gd`: push past the initial capacity keeps every value; `clear()` resets `count` and keeps the array size (no shrink).
- `test_replay.gd` (the acceptance test): a fixed command list (StartRun seed 7 `run_m2` at 0, PlaceTower at 30, Pause true at 100, Pause false at 160, UseSkill at 200, SellTower at 210) plus the same `spawn_ring` setup as `test_determinism`; run 600 ticks in two fresh worlds -> equal `state_hash`. A third world gets the same list queued in shuffled order -> equal hash. A fourth with Pause false at 190 -> different hash (clock differs). A fifth with a different StartRun seed -> different hash.
- `test_sim_world.gd`: `phase_usec.size() == 5`.

### Performance
One `events.clear()` and one queue check per tick: negligible. The event buffer never allocates after its peak; no per-event objects. Commands are rare (player input), so an `Array[SimCommand]` with sorted insert is fine.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: "Commands" bullet: the M2 set, `SimCommand` fields, tick stamping and ordering, stable `tower_uid`; "Events out": `SimEvents` SoA, cleared each step, the payload table, read after each step; new "Run state" bullet (IDLE/RUNNING/WON/LOST, `paused`, `clock` vs `tick`, IDLE still simulates for demo/bench); tick order (D-083): phase (0) commands before separation; `Phase` list.
- `DECISIONS.md`: **D-100 PROPOSED**: commands carry a tick and apply at the start of that tick (late ones stamped to the current tick; tick then enqueue order); `tick` always advances, the run `clock` only while running and not paused; pausing freezes the simulation but still applies commands; events are SoA in the world, cleared at each step; StartRun{seed, run id} reseeds and loads the run data; towers are addressed by a stable uid in commands.
- Note for the owner: whether building (PlaceTower) is allowed while paused is not decided; the sim applies queued commands while paused, and 020/021 decide what the UI sends.

### Order
1. `SimCommand`, `SimEvents` + their tests.
2. `SimWorld`: queue, COMMANDS phase, run state, `_seed_rngs`, hash; fix phase-array users.
3. `test_replay.gd`.
4. Docs, D-100. `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 170 lines of code, about 150 of tests. One PR.

## Questions

## Review log
