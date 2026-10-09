# M2 review pack: Core loop vertical slice

For the owner, at checkpoint CP-M2. Branch `m2/dev`, PR to `main` linked in the session. Roadmap "done when": **a full 15-minute run is playable start to finish.**

## What was built
- **A full run:** start screen, then a 15-minute run with 60 s waves and 15 s breaks, mini-bosses at 5:00 and 10:00, and the final boss at 15:00. The horde keeps coming while she is alive. Win when she dies; lose when the Guardian's HP reaches 0. Then a win or lose screen with "time survived" and Restart or Main menu.
- **Enemies:** swarmer, brute and ranged, plus 2 mini-bosses and the final boss. Soft crowding; enemies queue behind the front row instead of crushing together.
- **Maze tower defense (your Q-50 choice):** towers are solid; enemies path around them. You may wall the Guardian in completely; walled-in enemies then attack the tower in their way. Dead towers leave walkable husks you can rebuild. Towers block ranged enemies' line of sight.
- **3 tower types** (single target, splash, slow), bought with gold that counts the moment an enemy dies. Each extra copy costs more. You can sell, and you can't build while paused.
- **Guardian skills:** Area blast and Shield, on cooldowns.
- **UI:** a HUD (HP, gold, clock, wave or break, skill cooldowns), a build bar and gamepad radial menu, a placement ghost (green or red with the reason), a pause menu and the slow-time-while-placing option.
- **Controls:** mouse and keyboard, and gamepad, as specified in `docs/09_CONTROLS.md` (PROPOSED, for your approval).
- **Tooling:** `scripts\balance.ps1` runs headless bot games; `scripts\bench.ps1` now includes maze and combat scenarios.
- All art is placeholder shapes; all numbers are placeholders in data.

## How to play it
1. `git fetch` then `git switch m2/dev`, or check out the PR branch.
2. `scripts\run.ps1`, then **Start run**.
3. **Mouse and keyboard:** WASD or arrows to pan, the wheel to zoom, Space to recentre. **1/2/3** pick a tower; **left click** places it; right click or Esc cancels. **X** sells the tower under the mouse. **Q/E** fire the skills. **P** or Esc pauses.
4. **Gamepad (Xbox layout, same as the Steam Deck):** right stick to pan, LB/RB to zoom, R3 to recentre. **Hold Y** for the radial menu and release to choose. **A** places or rebuilds at the screen centre; B cancels; X sells. **LT/RT** fire the skills; Start pauses.
5. Try a full 15 minutes at least once, and try walling the Guardian in.

## What to look at (playtest)
- **Fun or not:** the first real verdict for the game.
- **Maze:** does building a maze feel worth it? Walled-in enemies chewing through a ring. Husk gaps.
- **Crowd:** the front ring attacks while the rest queue. Ranged enemies stuck behind melee, or blocked by towers.
- **Controls:** mouse and a real gamepad (never tested on real hardware), the radial menu, stick and trigger feel (deadzones are placeholders), and slow time (off by default, 0.5 speed).
- **Readability:** the HUD at your resolution; the Guardian stays almost white under constant melee hits (one-line fix available); spawns may pop in at the widest zoom near the pan edge.
- **Skills:** both are ready at run start and can't be used while paused (D-110).

## Balance (`reports/balance_m2.md`, headless bots, 5 seeds each)
| Bot | Wins | Notes |
|---|---|---|
| passive (skills only) | 0 / 5 | dies around 3:02 |
| spread (spiral of towers) | 5 / 5 | wins 15:28-15:53, about 50 towers |
| ring (maze ring at radius 4, kill zone first) | 5 / 5 | wins 15:33-15:46, about 50 towers |

The economy was tuned in placeholder data so a run can be won (gold drops, starting gold, Guardian HP, boss HP). Two rules to confirm (D-099): tower cost grows **linearly** per copy, and the **last wave repeats** once the wave list runs out.

## Performance (`reports/perf_m2.md`)
On your PC (release build), the typical and combat scenarios run at 4.5-7.0 ms per tick against the 8 ms budget. The maze scenarios sit at the budget line (7.6-8.1 ms); you accepted that as within noise for M2 (D-124), so the report's "gate not met" line is superseded by that decision. The Steam Deck estimate stays within 60 FPS (worst 15.6 ms of 25 ms; still an estimate, no Deck). No native-code trigger fired.

## Questions for you
1. Do you accept M2 (merge `m2/dev` into `main`)?
2. Fun or not? What felt best and worst?
3. Balance: is winning 5/5 with both builder bots too easy? Should the maze pay off more than spreading towers in M2, or wait for M3?
4. Do you approve the controls spec (`docs/09_CONTROLS.md`) and the proposed M2 decisions (D-099, D-100, D-106 to D-110, D-114 to D-116, D-119 to D-123, D-125, D-126)?

## Known limits (by design in M2)
- No XP, cards, upgrades, synergies, hub, saves or real art and audio: those are M3 and later.
- A real gamepad and a real Steam Deck run have not been tested by the agents.
