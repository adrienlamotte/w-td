# 017 — Sim: Guardian skills (Area blast, Shield)
- Status: planned
- Milestone: M2
- Depends on: 014
- PR: -

## Goal
The two M2 Guardian skills, triggered by UseSkill.

## Context
- D-044 (Area blast ~12 s, Shield ~25 s, no auto-attack; Heal later)
- From 014's plan (D-107): Area blast damages through `SimWorld.damage_enemy`; the Shield absorbs inside `SimWorld._hit_guardian` (the only path for damage to the Guardian; `GUARDIAN_HIT` value = damage after shield).

## Acceptance criteria
- Area blast damages enemies in a ring from data; Shield absorbs damage to the Guardian for a data amount and duration.
- Cooldowns; UseSkill during cooldown is rejected; SkillUsed events.
- Tests per skill.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-110**. No data or schema change (`RunData` already loads per slot `skill_kind, skill_cooldown, skill_radius, skill_damage, skill_absorb, skill_duration` from `run_m2`'s Guardian). Independent of 015 in logic, but both edit `SimWorld._apply` and `state_hash()`: whichever merges second rebases (small conflict).

### Rules (D-110 PROPOSED)
- **UseSkill{skill_id}** applies only while RUNNING and not paused (a paused world is frozen, D-100; IDLE has no Guardian). Slot = `run.skill_ids.find(skill_id)`; unknown id ignored. Rejected (ignored, no event) while on cooldown.
- **Cooldown** on the run clock: per slot `ready_at` (clock tick, 0 at StartRun, so both skills are ready at the start of the run); usable when `clock >= ready_at[slot]`; on use `ready_at = clock + skill_cooldown[slot]`. The run clock stops while paused, so the cooldown does too; nothing is decremented per tick. The UI (020) reads `ready_at` and `clock`.
- **Area blast**: every live enemy whose body touches the disk of `skill_radius` around the Guardian (`sqrt(x*x + z*z) - radius[type] <= skill_radius`, the D-107 edge convention) takes `skill_damage` through `damage_enemy` (so `ENEMY_HIT` per enemy, corpses ignored, deaths removed in the next DEATHS phase with their gold). Linear scan in index order over all enemies (once per 12 s; the grid is not worth it, and bosses' radii exceed its reach). Applied in the COMMANDS phase, on this tick's starting positions.
- **Shield**: on use `shield_left = skill_absorb`, `shield_until = clock + skill_duration` (a recast replaces, never stacks). In `_hit_guardian(type, x, z, dmg)`: if `clock < shield_until`, `absorbed = min(dmg, shield_left)`, `shield_left -= absorbed`, `dmg -= absorbed`; then the existing rule (`guardian_hp -= dmg`, `GUARDIAN_HIT` with the damage after shield, even 0, lose check). Expiry is the `clock` compare, no per-tick work.
- **SKILL_USED** event on every accepted use (a = slot), pushed before the blast's `ENEMY_HIT` events.

### Files
1. `sim` (new) `game/sim/guardian_skills.gd`, `class_name GuardianSkills extends RefCounted`: `ready_at: PackedInt32Array`, `shield_left: float`, `shield_until: int`; `reset(slots)`; `try_use(slot, clock, run) -> bool` (cooldown check, sets `ready_at`, starts the Shield for a SHIELD slot); `absorb(dmg, clock) -> float` (returns the damage left). About 40 lines.
2. `sim` `game/sim/sim_world.gd`: `skills := GuardianSkills.new()`, reset at StartRun with `run.skill_ids.size()` slots; `USE_SKILL` routed to `_use_skill(cmd)` (gate, slot, `try_use`, `SKILL_USED`, `_area_blast(slot)` for AREA_BLAST); `_hit_guardian` calls `skills.absorb(dmg, clock)` first; `state_hash()` adds `skills.ready_at, skills.shield_left, skills.shield_until`. About +35 lines.

### Tests (`game/tests/sim/test_guardian_skills.gd`, StartRun `run_m2`)
- Area blast: an enemy just inside the disk (edge touches) and one just outside; the inside one takes `skill_damage` (`ENEMY_HIT`), the outside one is untouched; a boss whose centre is outside but whose body touches is hit; a corpse is not hit again; an enemy with `hp <= skill_damage` is gone after the next step with `ENEMY_DIED` and its gold; `SKILL_USED` (slot) comes before the hits.
- Cooldown: a second blast before `skill_cooldown` ticks is ignored (no event, hp unchanged); at exactly `ready_at` it works; while paused UseSkill is ignored, and pausing does not advance the cooldown; before StartRun and after LOST it is ignored; unknown skill id ignored.
- Shield: an attacker's hit within `absorb` gives `GUARDIAN_HIT` value 0 and no hp loss; a hit bigger than what is left lets the rest through (value = remainder); after `skill_duration` ticks hits go through in full even with absorb left; a recast refills, does not stack; the Guardian can still lose through a used-up Shield.
- Determinism: two worlds, StartRun seed 7 with UseSkill commands (blast and shield at fixed ticks) over 3000 ticks, equal `state_hash`; seed 8 different. Add a UseSkill shield to `test_replay.gd`'s list (it already sends an area blast, which now acts).

### Performance
A blast is one pass over the enemies when used (3000 compares and a sqrt each, once per 12 s). The Shield adds one compare per Guardian hit. No per-tick cost otherwise.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: commands (UseSkill rules and the pause gate; "Handlers: UseSkill task 017" becomes the description); Combat bullet: `_hit_guardian` applies the Shield first; new short "Guardian skills" bullet (cooldown on the run clock, blast disk and edge rule, Shield absorb/duration/recast).
- `DECISIONS.md`: **D-110 PROPOSED** (the rules above; "both skills ready at run start" and "no skill while paused" named as placeholders to confirm at CP-M2).

### Order
1. `GuardianSkills` with cooldown and Shield, tests. 2. UseSkill handler and Area blast, tests. 3. `_hit_guardian` absorb, tests. 4. Hash, determinism, replay. 5. Docs, D-110; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 80 lines of code, about 150 of tests. One PR.

## Questions

## Review log
