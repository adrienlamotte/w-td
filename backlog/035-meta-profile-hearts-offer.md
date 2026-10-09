# 035 — Meta: profile, hearts, meta tree, Guardian offer and win-unlock
- Status: todo
- Milestone: M3
- Depends on: 033, 034
- PR:

## Goal
A persistent meta profile: hearts earned per run, the 12-node meta tree, the Guardian offer of 3 locked waifus, and the rescued Guardian unlocked as a tower on a win. The run gets everything from the profile through `START_RUN`, so a run stays a pure function of `(seed, start data, commands)`.

## Context
- `docs/10_M3_CONTENT.md` 6.1 (hearts: win 100, loss formula, abandon = loss at the time reached, added at run end only), 6.2 (tree, `requires`, effects applied at StartRun), 7 (profile `user://profile.json`, atomic write, `schema_version` with one migration step per version, `profile.bad.json`, offer derived not stored, bond kept at 0), 2.1 (rescued Guardians become new-tower cards; starters buildable from the start).
- D-023 (win unlocks the Guardian as a tower), D-048 (loss hearts), D-050 (3 locked waifus, fixed until one is rescued), D-052, D-053, D-131 (higher tiers after all 6 rescues: M3 stores only the unlock state), `docs/07_ROSTER.md` 3 (offer order).
- Q-68 (offer once all 6 are rescued): safe to assume ★ A.

## Acceptance criteria
- Pure rules (no file access): the offer from `unlocked` + `offer_order`; hearts from the end state; buying a node (cost, `requires`, enough hearts); the `START_RUN` config (Guardian, starter towers, unlocked waifus, meta effects as modifiers, grid sized for the largest radius).
- Profile file I/O outside `sim/`: atomic write (temp + rename), load with the migration chain, an unreadable file kept as `profile.bad.json` and a fresh profile used.
- Run end: hearts added, stats updated, the Guardian unlocked on a win; written once.
- Tests: offer at 0, 1 and 6 rescues; hearts at 0:00, 7:30, after the final boss spawned, and on a win; tree purchase rules; StartRun applies meta effects; profile round trip; migration from an older fixture; corrupt file handling.
- Headless tests green twice; data validator green; docs (`02_TECH_ARCHITECTURE.md` 7) and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
