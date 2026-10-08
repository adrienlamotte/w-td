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

## 3. Backlog **[P]**
- `/backlog/NNN-short-title.md`, one file per task, with: goal, context links (docs), acceptance criteria, status (`todo | doing | review | done | blocked`), owner (`agent | human`).
- An agent picks the lowest-numbered `todo` task whose dependencies are done, sets `doing`, works on a branch, then sets `review`.
- Alternative: Trello board (connector exists). Not chosen; revisit if the owner wants a visual board.

## 4. Git and review **[P]**
- Branch per task: `task/NNN-short-title`. Commits small and descriptive.
- Merge to `main` only if: headless tests pass, data validator passes, docs updated.
- Tasks that need human validation are labeled `needs-human:<playtest|art|balance|steam>` and are not merged until the human signs off (or are merged behind a feature flag).

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

All routines except the daily docs review and the weekly doc drift check run on the owner's PC (D-035); they need the PC on and the Claude desktop app open. How they are triggered: Q-35.

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
- Where the automation runs: decided, the owner's PC for builds/tests/balance/perf/ComfyUI and the cloud only for docs and design work (D-035). Cloud routines such as the daily docs review (D-029) cannot reach the owner's PC or local ComfyUI. How local routines are scheduled: Q-35.
- Repo host and CI: the repo is on GitHub; builds and tests run locally (D-035).
- Who covers asset generation time (agents can run ComfyUI jobs on the owner's machine, but only when it is on).
