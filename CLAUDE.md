# CLAUDE.md — Agent entry point

Project: **Waifu Tower Defense** (working title "WTD"). A cute/comedic-fantasy roguelite tower defense with a Vampire Survivors-style horde, for Steam (Windows + Steam Deck).

You are an AI agent working on this repo, mostly unattended. Read this file first, then only the docs you need.

## Doc map (read on demand, all files are in `/docs`)
| Need | File |
|---|---|
| What the game is, rules, content | `01_GAME_DESIGN.md` |
| Engine, code structure, perf budgets, testing | `02_TECH_ARCHITECTURE.md` |
| Making/importing sprites & art, external-tool import spec | `03_ART_PIPELINE.md` |
| How you work: loops, routines, branches, human checkpoints | `04_AGENT_WORKFLOW.md` |
| Steam rules, content limits, AI disclosure | `05_STEAM_AND_COMPLIANCE.md` |
| Milestones and current scope | `06_ROADMAP.md` |
| Keyboard/mouse and gamepad mapping | `09_CONTROLS.md` |
| Plan of the current milestone | `plans/M<n>.md` |
| Why things were decided | `DECISIONS.md` |
| What is still undecided | `OPEN_QUESTIONS.md` |

## Hard rules
1. **Do not invent design.** If a design question is not answered in the docs, add it to `OPEN_QUESTIONS.md`, pick the most conservative option, and flag it in your report. Never silently decide.
2. **Content limits (non-negotiable):** no nudity, no explicit sexual content or poses. "Suggestive" (lingerie, swimwear, fanservice) is allowed within the limits in `05_STEAM_AND_COMPLIANCE.md`. All characters are clearly adult.
3. **Gameplay simulation is separate from rendering.** See `02_TECH_ARCHITECTURE.md`. Never put game rules in view/scene code.
4. **Data-driven content.** Waifus, enemies, outfits, towers, cards live in data files, not hard-coded.
5. **Every change keeps the headless test suite green.** Run it before finishing any task.
6. **Never publish, upload to Steam, spend money, or handle credentials.** Those are human-only.
7. **Provenance for every AI-generated asset** goes into the asset manifest (see `03_ART_PIPELINE.md`).
8. **Keep docs in sync.** If you change behavior that a doc describes, update the doc in the same change. Record decisions in `DECISIONS.md`.

## Commands (fill in as the project gets created; keep this section accurate)
Setup (once per machine): Godot **4.7.2-stable** (pinned, D-065; scripts refuse other versions). Download `Godot_v4.7.2-stable_win64.exe.zip` from https://github.com/godotengine/godot/releases/tag/4.7.2-stable and unzip it outside the repo (owner's PC: `C:\DevTools\Godot\4.7.2`). Point `GODOT` at the **console** exe, for example `$env:GODOT = 'C:\DevTools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'` (or put `godot` on PATH). For exports, also install the export templates (Editor > Manage Export Templates, or unzip `templates/` from `Godot_v4.7.2-stable_export_templates.tpz` into `%APPDATA%\Godot\export_templates\4.7.2.stable`). Python 3.10+ on PATH; the scripts create `tools/.venv` with pinned deps on first use. If script execution is blocked, run them as `powershell -ExecutionPolicy Bypass -File scripts\<name>.ps1`.
- Run tests (headless, GUT + Python tools tests): `scripts\test.ps1`
- Validate game data (JSON Schema): `scripts\validate.ps1`
- Run game: `scripts\run.ps1`
- Export Windows build (to `build\windows\WTD.exe`): `scripts\export.ps1`
- Development loop (product owner): `/dev-loop` (runs until a stop; asks the owner questions in the session). Roles: `04_AGENT_WORKFLOW.md` 2a.
- Perf benchmark: `scripts\bench.ps1` (exports and runs the release build `build\windows\WTD.exe --bench`, writes `reports/perf_<date>.json`, about 2.5 min; needs a GPU, not headless)
- M2 balance bot: `scripts\balance.ps1` (`-Runs N`, default 5; headless bot runs of `run_m2`, writes `reports/balance_m2.md`, about 5-11 min). The full balance simulation is M3.
- Asset forge CLI: _TBD in M4_

## When you finish a task
Report in 3-6 lines: what changed, tests status, anything that needs a human (playtest, art approval, balance review), new open questions.
