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
| D-020 | 2026-10-07 | Sim/view split with headless deterministic simulation | DECIDED | Confirmed 2026-10-08, see D-037 |
| D-021 | 2026-10-07 | Chibi character style | SUPERSEDED | Replaced by D-030 (no chibi) |
| D-022 | 2026-10-07 | No live-generated AI content in the game; only pre-generated assets | PROPOSED | Simplifies Steam disclosure |
| D-023 | 2026-10-07 | Each run's Guardian is the next locked waifu to rescue; victory unlocks her as a tower. Unlocked waifus are towers only | DECIDED | Refines D-013 |
| D-024 | 2026-10-07 | Only special story bosses are recruitable; regular bosses are just enemies | DECIDED | Which bosses are recruitable is OPEN |
| D-025 | 2026-10-07 | Launch roster target: 8-10 waifus at Early Access | DECIDED | Includes the waifus unlocked as Guardians |
| D-026 | 2026-10-07 | Before each run the player picks the Guardian from a few locked waifus (not a fixed order, not random) | DECIDED | Refines D-023. How many are offered, and how they are chosen: OPEN |
| D-027 | 2026-10-07 | Replay value after full unlock: difficulty tiers, endless mode, challenge modifiers | DECIDED | Replaying with an already-unlocked waifu as Guardian is NOT part of the plan |
| D-028 | 2026-10-07 | No story or campaign: pure gameplay; waifus only have personality lines (barks) | DECIDED | Supersedes the "story" wording in D-024: "story bosses" now means named rival bosses, not a narrative |
| D-029 | 2026-10-07 | A daily cloud routine reviews the docs, updates OPEN_QUESTIONS.md and opens a pull request; the owner answers in a session | DECIDED | See `04_AGENT_WORKFLOW.md` section 5 |
| D-030 | 2026-10-08 | No chibi: all characters use adult proportions everywhere (in-game sprites, portraits, outfit art) | DECIDED | Q-24. Supersedes D-021. Readability of adult-proportioned waifus at small size is to be validated in the M4 art spike |
| D-031 | 2026-10-08 | 2 starter waifus are unlocked from the start as towers and count toward the 8-10 launch roster; Guardians are picked among the remaining locked waifus | DECIDED | Q-13. Which two waifus: Q-23 |
| D-032 | 2026-10-08 | Between waves there is a short break (15-20 s): no new spawns, leftover enemies keep attacking, the clock keeps running; building is allowed at any time | DECIDED | Q-08. Refines D-010 |
| D-033 | 2026-10-08 | Test framework: GUT | DECIDED | Q-01 |
| D-034 | 2026-10-08 | Game content data is JSON files validated with JSON Schema | DECIDED | Q-02 |
| D-035 | 2026-10-08 | Builds, headless tests, balance runs, perf benchmarks and ComfyUI jobs all run on the owner's PC; cloud sessions are used only for docs and design work (daily docs review, brainstorm sessions). GitHub stays the repo host | DECIDED | Q-03. Consequence: nightly routines need the PC on and the Claude desktop app open. How they are scheduled: Q-35 |
| D-036 | 2026-10-08 | The Godot 4.x version is pinned at the start of M0, recorded in `DECISIONS.md` and `tools/`; upgrades only through an explicit task | DECIDED | Q-04. Exact version to be added here when pinned |
| D-037 | 2026-10-08 | The simulation/view split with a headless deterministic sim (D-020) is confirmed. D-019 (2.5D with MultiMesh and 2D fallback) and D-022 stay PROPOSED until the M1 spike | DECIDED | Q-05 |
| D-038 | 2026-10-08 | Simulation runs at a fixed 30 Hz tick; the view interpolates to the render rate | DECIDED | Q-06. To be re-validated by the M1 benchmark |
| D-039 | 2026-10-08 | Base resolution is 2560x1440, scaled down on Steam Deck (1280x800) | DECIDED | Q-07. Asset on-screen sizes in `03_ART_PIPELINE.md` are scaled accordingly |
| D-040 | 2026-10-08 | Tower placement: free placement on a fine grid inside a radius around the Guardian; no tower cap; towers can be sold for a partial gold refund but not moved; the player can move the camera | DECIDED | Q-09 (with the owner's changes: no cap, movable camera). Open follow-ups: camera controls Q-33, radius and performance budget Q-34 |
| D-041 | 2026-10-08 | Camera: PC uses WASD/arrows, edge scroll and mouse-wheel zoom; gamepad uses the right stick to pan, bumpers to zoom and a button to recentre on the Guardian; the placement cursor is at the screen centre (the world moves under it, snapped to the grid). Camera limited to the buildable radius plus a margin; 3 zoom levels | DECIDED | Q-33. Exact button mapping goes in the controls spec |
| D-042 | 2026-10-08 | Build radius starts at about 20 world units around the Guardian and can grow via meta upgrades or cards; each additional copy of a tower costs more (soft limit through the economy); performance stress target is 300 towers on PC and 150 on Steam Deck, to be validated in M1 | DECIDED | Q-34. All numbers are placeholders in data |
| D-043 | 2026-10-08 | Towers have HP. Enemies attack whatever blocks their straight path, otherwise the Guardian. A dead tower leaves a husk that can be rebuilt for a fraction of the cost. No repair in M2 | DECIDED | Q-10 |
| D-044 | 2026-10-08 | Guardian skills for M2: Area blast (damage ring, about 12 s cooldown) and Shield (absorbs damage, about 25 s cooldown). Heal comes later as an upgrade. The Guardian has no auto-attack; she acts only through skills | DECIDED | Q-11. Numbers are placeholders in data |
| D-045 | 2026-10-08 | M2 tower types: ranged single-target damage, area (splash) damage, crowd control (slow) | DECIDED | Q-12 |
| D-046 | 2026-10-08 | Gamepad building: hold a button to open a radial tower menu, release to select; A places at the centre cursor, B cancels; skills on the triggers. A slow-time-while-placing toggle is an accessibility option | DECIDED | Q-14. Exact mapping goes in the controls spec |
| D-047 | 2026-10-08 | Run end: fixed timeline. The final boss spawns at a data-defined time (15:00 in M2, tuned toward 15-20 min later); the run is won by killing her | DECIDED | Q-15 |
| D-048 | 2026-10-08 | A loss keeps a reduced hearts reward (30-50% depending on time survived) and the player picks a Guardian again from the offered locked waifus | DECIDED | Q-16. Percentages are placeholders |
