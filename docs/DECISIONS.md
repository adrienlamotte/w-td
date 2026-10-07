# Decision log (append-only)

Format: `ID | date | decision | status | notes`. Status: DECIDED (owner confirmed), PROPOSED (assistant recommendation, not yet confirmed).

| ID | Date | Decision | Status | Notes |
|---|---|---|---|---|
| D-001 | 2026-10-07 | Game concept: waifu tower defense with roguelite features and a Vampire Survivors-style horde | DECIDED | Owner's brief |
| D-002 | 2026-10-07 | Publish on Steam, small price | DECIDED | Early Access and exact price still PROPOSED |
| D-003 | 2026-10-07 | Content: no nudity, "suggestive" allowed (lingerie, swimwear) | DECIDED | Limits in `05_STEAM_AND_COMPLIANCE.md` |
| D-004 | 2026-10-07 | Development by Claude Code agents, automated with loops/routines | DECIDED | See `04_AGENT_WORKFLOW.md` |
| D-005 | 2026-10-07 | Art is AI-generated, local ComfyUI (NVIDIA 16 GB+); no paid external APIs. Owner may generate externally and import via the spec | DECIDED | |
| D-006 | 2026-10-07 | Run length 15-20 minutes with meta-progression | DECIDED | |
| D-007 | 2026-10-07 | Platforms: Windows + Steam Deck (gamepad first-class) | DECIDED | |
| D-008 | 2026-10-07 | Core structure: you protect a waifu (the Guardian) at the center; defenses are built by the player | DECIDED | Owner's base idea |
| D-009 | 2026-10-07 | Open field, 360° swarm, no lanes | DECIDED | |
| D-010 | 2026-10-07 | Building happens both in real time and in build phases | DECIDED | |
| D-011 | 2026-10-07 | Towers are other waifus | DECIDED | |
| D-012 | 2026-10-07 | The Guardian does not move; she has active skills the player triggers | DECIDED | |
| D-013 | 2026-10-07 | The protected waifu is unlocked as a tower when the player wins | DECIDED | Whether unlocked waifus can be Guardians later is OPEN |
| D-014 | 2026-10-07 | Tone: cute and comedic fantasy | DECIDED | |
| D-015 | 2026-10-07 | Animation: hybrid, skeletal/layered waifus + sprite frames for the horde | DECIDED | |
| D-016 | 2026-10-07 | Human checkpoints: playtest each milestone, art approval, balance review, Steam page/marketing | DECIDED | |
| D-017 | 2026-10-07 | Docs are markdown files in the repo, agent-oriented | DECIDED | Format chosen by the assistant at the owner's request |
| D-018 | 2026-10-07 | Engine: Godot 4.x with GDScript; GDExtension (Rust/C++) only if profiling requires | DECIDED | Confirmed by owner |
| D-019 | 2026-10-07 | 2.5D rendering: iso camera + billboarded sprites + MultiMesh; fallback to pure 2D | PROPOSED | Validated in M1 |
| D-020 | 2026-10-07 | Sim/view split with headless deterministic simulation | PROPOSED | Strongly recommended for agent automation |
| D-021 | 2026-10-07 | Chibi character style | PROPOSED | |
| D-022 | 2026-10-07 | No live-generated AI content in the game; only pre-generated assets | PROPOSED | Simplifies Steam disclosure |
| D-023 | 2026-10-07 | Each run's Guardian is the next locked waifu to rescue; victory unlocks her as a tower. Unlocked waifus are towers only | DECIDED | Refines D-013 |
| D-024 | 2026-10-07 | Only special story bosses are recruitable; regular bosses are just enemies | DECIDED | Which bosses are recruitable is OPEN |
| D-025 | 2026-10-07 | Launch roster target: 8-10 waifus at Early Access | DECIDED | Includes the waifus unlocked as Guardians |
| D-026 | 2026-10-07 | Before each run the player picks the Guardian from a few locked waifus (not a fixed order, not random) | DECIDED | Refines D-023. How many are offered, and how they are chosen: OPEN |
| D-027 | 2026-10-07 | Replay value after full unlock: difficulty tiers, endless mode, challenge modifiers | DECIDED | Replaying with an already-unlocked waifu as Guardian is NOT part of the plan |
| D-028 | 2026-10-07 | No story or campaign: pure gameplay; waifus only have personality lines (barks) | DECIDED | Supersedes the "story" wording in D-024: "story bosses" now means named rival bosses, not a narrative |
| D-029 | 2026-10-07 | A daily cloud routine reviews the docs, updates OPEN_QUESTIONS.md and opens a pull request; the owner answers in a session | DECIDED | See `04_AGENT_WORKFLOW.md` section 5 |
