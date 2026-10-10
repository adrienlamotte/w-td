class_name SignatureSkills
extends RefCounted
## Guardian skill casts (D-110, D-146), in the COMMANDS phase. A cast reads the modifier store
## once; timed effects store an absolute run-clock `until` in GuardianSkills that existing code
## checks (damage_tower, _hit_guardian, _deaths, TowerAttacks.fire).


## Cooldown in ticks of skill slot `slot` with the skill_cooldown modifiers (D-144 clamp).
static func cooldown_ticks(w: SimWorld, slot: int) -> int:
	var run := w.run
	var s := w.modifiers.skill_sums("skill_cooldown", run.skill_ids[slot], slot == run.signature_slot)
	return TowerStats.clamped_ticks(run.skill_cooldown[slot], s)


static func cast(w: SimWorld, slot: int) -> void:
	var run := w.run
	var sk := w.skills
	var id := run.skill_ids[slot]
	var sig := slot == run.signature_slot
	# Signature power (rule 3): multiplies only the fields her power_stats list.
	var p := w.modifiers.skill_sums("skill_power", id, true).y if sig else 0.0
	var powered := run.skill_power_stats[slot]
	var duration := DataFiles.ticks(run.skill_duration[slot] / float(SimWorld.TICK_RATE) \
			* (1.0 + p if powered.has("duration_sec") else 1.0))
	match run.skill_kind[slot]:
		RunData.Skill.AREA_BLAST:
			var dmg := run.skill_damage[slot] * (1.0 + p if powered.has("damage") else 1.0)
			_area(w, run.skill_radius[slot], dmg, 0.0, 0)
		RunData.Skill.SNARE:
			_area(w, run.skill_radius[slot], 0.0, run.skill_slow_factor[slot], duration)
		RunData.Skill.GUARD:
			sk.guard_until = w.clock + duration
		RunData.Skill.HASTE:
			sk.haste_until = w.clock + duration
		RunData.Skill.BOUNTY:
			sk.bounty_until = w.clock + duration
			sk.bounty_gold = floori(run.skill_gold_per_kill[slot] * (1.0 + p if powered.has("gold_per_kill") else 1.0))
		RunData.Skill.REBUILD:
			var towers := w.towers
			for t in towers.count():
				if towers.husk[t] and towers.type_id[t] >= 0:
					TowerBuilding.restore(w, t)
			heal(w, run.skill_guardian_heal[slot] * (1.0 + p if powered.has("guardian_heal") else 1.0))
		RunData.Skill.SHIELD:
			var mods := w.modifiers
			var absorb := run.skill_absorb[slot] * (1.0 + mods.skill_sums("shield_absorb", id, sig).y)
			var secs := run.skill_duration[slot] / float(SimWorld.TICK_RATE) + mods.skill_sums("shield_duration", id, sig).x
			sk.raise_shield(w.clock, absorb, DataFiles.ticks(secs))
			heal(w, mods.skill_sums("shield_heal", id, sig).x)  # Mending (D-044)


## Capped at max HP; 0 changes nothing (tests and the bench may set hp above max).
static func heal(w: SimWorld, amount: float) -> void:
	if amount > 0.0:
		w.guardian_hp = minf(w.guardian_max_hp, w.guardian_hp + amount)


# Every enemy whose body touches the disk around the Guardian (D-107 edge rule), index order:
# damage (Area blast) or the D-117 slow (Tangle; bosses too).
# ponytail: linear scan, once per cooldown; the grid cannot reach boss radii.
static func _area(w: SimWorld, reach: float, dmg: float, slow: float, slow_ticks: int) -> void:
	var enemies := w.enemies
	var px := enemies.pos_x
	var pz := enemies.pos_z
	var radius := w.catalog.radius
	for i in enemies.count():
		if sqrt(px[i] * px[i] + pz[i] * pz[i]) - radius[enemies.type_id[i]] > reach:
			continue
		if dmg > 0.0:
			w.damage_enemy(i, dmg)
		if slow_ticks > 0:
			TowerAttacks.apply_slow(enemies, i, slow, slow_ticks)
