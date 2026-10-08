# 04 — Agent Workflow (Claude Code, automated loops)

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Principles
- Maximum automation, with **explicit human checkpoints** where taste or money is involved **[D]**.
- Agents work from **written specs**: docs + a markdown backlog. If a spec is missing, the agent asks via `OPEN_QUESTIONS.md`, not by guessing.
- Small tasks, small changes, always tested.

## 2. Collaboration process between the owner and the design assistant **[D]**
- When there are questions, the assistant prepares a **form** for the owner to answer.
- The assistant chooses the docs format: **markdown in the repo** (easy to diff, edit and read by agents).
- Decisions go to `DECISIONS.md`; unanswered items to `OPEN_QUESTIONS.md`.

## 2a. Development loop roles **[D]** (D-070, D-077)
| Role | Runs as | Does | Never does |
|---|---|---|---|
| Product owner / supervisor | `/dev-loop` skill (`.claude/skills/dev-loop/SKILL.md`), in the owner's Claude Code session | plans each milestone (`docs/plans/M<n>.md` + task files), picks the next step, asks the owner questions, approvals and checkpoints in the session and records the answers, writes review packs, stops for humans | write gameplay code, decide design alone |
| Lead developer | `lead-dev` subagent (`.claude/agents/lead-dev.md`) | writes each task's technical plan, splits big tasks, reviews PRs (runs the tests itself), merges approved task PRs into the milestone branch | implement features, touch `main` |
| Senior game developer | `game-dev` subagent (`.claude/agents/game-dev.md`) | implements one planned task per branch and PR, with tests and docs | merge, change scope, guess design |

- Start a run with `/dev-loop`. It keeps going until a stop (D-074).
- **Stops:** milestone checkpoint; previous checkpoint not accepted; everything blocked on the owner; red tests on the milestone branch; anything that would publish, spend, touch credentials or push to `main`.
- **Owner questions (D-077):** the product owner asks the owner directly in the Claude Code session with a multiple-choice form (up to 4 questions per form, recommended option first, the owner can always answer "Other"). The agents never ask the owner themselves: they write their questions into the task file and the product owner asks them. Questions are batched: the loop keeps working on whatever is not blocked and asks when nothing else can move, at a stop, or at the end of a run. Every question also lives in `OPEN_QUESTIONS.md` until answered, then becomes a `DECISIONS.md` entry.

## 3. Plans and backlog **[D]** (D-071)
Three levels:
1. **Global roadmap:** `06_ROADMAP.md`: milestones, acceptance criteria, checkpoints, current milestone.
2. **Milestone plan:** `docs/plans/M<n>.md`, written by the product owner when the milestone starts. Sections: goal and "done when" (copied from the roadmap), scope in and out, task list (number, title, depends on, status), human gates (checkpoint, approvals), open questions that block it, risks.
3. **Task:** `/backlog/NNN-short-title.md`, one file per task, global numbering. Format:
```
# NNN — Title
- Status: todo | planned | review | changes | done | blocked
- Milestone: M<n>
- Depends on: NNN, ...
- PR: #n
- Blocked on: Q-nn (only when blocked)
- Labels: needs-human:<playtest|art|balance|steam> (only when needed)

## Goal
## Context (links to docs and decisions)
## Acceptance criteria
## Plan            <- lead-dev
## Questions       <- game-dev or lead-dev, when blocked
## Review log      <- lead-dev
```
- Lifecycle: `todo` → lead-dev plans → `planned` → game-dev implements and opens a PR → `review` → lead-dev reviews → `done` (merged) or `changes` (back to game-dev). Any role can set `blocked` with questions.
- Task files are edited only on the milestone branch, never on a task branch.
- The loop only runs tasks whose `Milestone:` is the current one. Tasks without a milestone (for example design proposals like `001`) are run on request.
- Alternative: Trello board (connector exists). Not chosen; revisit if the owner wants a visual board.

## 4. Git and review **[D]** (D-073)
- **Branches (D-073):** one milestone branch `m<n>/dev`, created from `main` when the milestone starts. One branch per task, `task/NNN-short-title`, with a PR into `m<n>/dev`; the lead dev merges it (squash) after review. At the checkpoint the product owner opens the PR `m<n>/dev` → `main`, and **only the owner merges into `main`**.
- Merge a task PR only if: headless tests pass, data validator passes, docs updated, lead-dev review passed.
- Tasks that need human validation are labeled `needs-human:<playtest|art|balance|steam>` and are not merged until the owner approves them in the session (or are merged behind a feature flag).
- All agents use the owner's GitHub account, so review verdicts are PR comments, not formal GitHub reviews.

## 5. Recurring routines (loops) **[P]**
| Routine | Frequency | What it does | Output |
|---|---|---|---|
| Build and test | on every task, plus nightly | export build, run headless tests, validate data | pass/fail in `/reports/nightly.md` |
| Balance simulation | nightly once M3 exists | N headless runs with bot strategies | `/reports/balance_<date>.md` (win rate, curves, outliers) |
| Perf benchmark | nightly once M1 exists | benchmark scene, FPS and frame time | `/reports/perf_<date>.json`, flag regressions |
| Screenshot capture | on visual tasks | scripted scenes captured for review | images in `/reports/screens/` |
| Asset validation | on every new asset | run `asset_forge validate` | manifest updated, errors listed |
| Daily docs review **[D]** | daily, ~07:00 Paris time, cloud scheduled task | reads all docs, finds gaps, contradictions and missing specs; adds or sharpens questions in `OPEN_QUESTIONS.md` (each with options and a recommended default, so they can become a form); never records a decision on its own; pushes a branch `docs/review-YYYY-MM-DD` and opens a pull request for the owner | PR + short summary of the questions to answer |
| Doc drift check | weekly | compare docs to code/data, list contradictions | `/reports/doc_drift.md` and fixes |
| Backlog grooming | weekly | split big tasks, close stale ones, propose next tasks | updated `/backlog` |
| Milestone report | at each milestone | summary of done/blocked, what needs the human | `/reports/milestone_<n>.md` |

All routines except the daily docs review and the weekly doc drift check run on the owner's PC (D-035); they need the PC on and the Claude desktop app open. They are triggered by scheduled tasks in the Claude desktop app, or manually (D-049).

## 6. Human checkpoints **[D]**
The owner chose all four:
1. **Playtest each milestone:** the owner plays the build and gives "feel" feedback. Agents cannot judge fun.
2. **Art approval:** characters, outfits, key art approved before integration.
3. **Balance review:** the owner reviews balance reports and approves major tuning direction.
4. **Steam page and marketing:** store text, trailer, tags, AI disclosure validated by the owner before publishing.

Agents prepare a short **review pack** for each checkpoint (build instructions, what to look at, specific questions).

## 7. Things agents must never do **[D]**
- Publish to Steam, change store pages, or submit anything externally.
- Spend money, use paid APIs (art is local-only), or handle credentials.
- Add content that breaks the content limits in `05_STEAM_AND_COMPLIANCE.md`.
- Delete assets marked `approved`.

## 8. Reporting format
Every finished task ends with a 3-6 line report (what changed, tests, human action needed, new open questions). Nightly reports are short and list only failures and decisions needed.

## 9. Open questions **[O]**
- Where the automation runs: decided, the owner's PC for builds/tests/balance/perf/ComfyUI and the cloud only for docs and design work (D-035). Cloud routines such as the daily docs review (D-029) cannot reach the owner's PC or local ComfyUI. Local routines are scheduled with desktop-app scheduled tasks, or run manually (D-049).
- Repo host and CI: the repo is on GitHub; builds and tests run locally (D-035).
- Who covers asset generation time (agents can run ComfyUI jobs on the owner's machine, but only when it is on).
