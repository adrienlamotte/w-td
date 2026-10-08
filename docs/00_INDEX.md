# Documentation index

Status legend: **DECIDED** = confirmed by the owner. **PROPOSED** = our recommendation, awaiting confirmation. **OPEN** = not yet discussed.

Last updated: 2026-10-08 (daily docs review; open questions restructured with stable `Q-nn` IDs).

## Files
- `CLAUDE.md` — agent entry point, hard rules, doc map. Place at repo root.
- `01_GAME_DESIGN.md` — game design document.
- `02_TECH_ARCHITECTURE.md` — engine, architecture, performance, testing.
- `03_ART_PIPELINE.md` — AI art generation (local ComfyUI), asset specs, external-tool import.
- `04_AGENT_WORKFLOW.md` — automation loops/routines and human checkpoints.
- `05_STEAM_AND_COMPLIANCE.md` — Steam release, content limits, AI disclosure.
- `06_ROADMAP.md` — milestones and acceptance criteria.
- `DECISIONS.md` — decision log (append-only).
- `OPEN_QUESTIONS.md` — unresolved questions.

## Suggested repo layout
```
/CLAUDE.md
/docs/            <- all numbered docs + DECISIONS.md + OPEN_QUESTIONS.md
/game/            <- Godot project
/tools/           <- asset forge CLI, balance sim runner, validators
/assets_src/      <- source art, ComfyUI workflows, manifests
/backlog/         <- one markdown file per task
/reports/         <- generated nightly/milestone reports
```

## Doc conventions (for agents)
- Plain markdown, short sections, tables for specs. No images required to understand a doc.
- Every spec states its **status**. Do not implement OPEN items.
- Append to `DECISIONS.md`, never rewrite history; supersede with a new entry.
