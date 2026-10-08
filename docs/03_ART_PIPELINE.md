# 03 — Art Pipeline

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Decisions
- Art is **AI-generated**, **local** (ComfyUI on the owner's machine, NVIDIA 16 GB+ VRAM) **[D]**.
- The owner can also generate assets with **external tools** and import them manually; this doc defines the import spec (section 7) **[D]**.
- Animation: **hybrid** — **skeletal/layered waifus** (parts animated in-engine), **sprite-frame animation for the horde** **[D]**.
- Style: cute and comedic fantasy, **adult proportions, no chibi** (D-030) **[D]**; 2.5D billboards **[P]**.
- Human approval is required for every waifu (character design, outfits) before integration **[D]**.

## 2. Why this approach
- Frame-to-frame consistency is the weak point of AI-generated anime art. Layered waifus avoid it: parts are generated once, motion is made in-engine, so the character never "drifts".
- Outfits become layer swaps instead of a new sprite sheet per outfit.
- The horde is many small, simple sprites; short frame cycles are acceptable and cheap.

## 3. Asset types and specs **[P]**
| Asset | Method | Source size | In-game size | Notes |
|---|---|---|---|---|
| Waifu (tower + Guardian) | Layered parts, skeletal animation in Godot | Parts on 2048 px tall canvas | ~160-200 px tall on screen | Parts: head, face expressions, hair front/back, torso, arms, legs, outfit layers, accessories |
| Waifu portraits (UI, level-up cards, hub) | Full illustration | 1024x1536 | scaled | One per outfit, plus a few expressions |
| Enemies (horde) | Sprite sheet | 256 px frames | ~64-96 px | 2 directions only (flip horizontally). Cycles: walk 6-8 frames, attack 4 frames, death 4-6 frames |
| Bosses | Layered or large sprite sheet | per boss | ~200-300 px | Decide per boss |
| Projectiles/VFX | Sprite sheets or particles | 128 px | varies | Prefer shaders/particles when possible |
| Ground tiles/props | Static textures | 512 px | varies | Must keep horde readable |
| UI | Vector/PNG | per UI spec | | Gamepad-friendly sizing |

Note: the "In-game size" column is given at a 1080p reference. The base resolution is 2560x1440 (D-039), so multiply on-screen sizes by about 1.33 (waifus ~215-265 px tall, horde ~85-130 px). Source sizes are unchanged. Because there is no chibi style (D-030), readability of adult-proportioned waifus at tower scale must be validated in the M4 art spike.

All sprites: **transparent background (PNG, RGBA)**, consistent light direction, consistent outline style, feet on a defined pivot. **Pivot [P]:** bottom-centre of the frame for enemies, props and bosses; for waifu layers each part carries its own pivot in `parts.json` and the root pivot is the feet on the ground.

### Canonical names **[P]**
- *Waifu part names:* `body_torso`, `body_arm_l`, `body_arm_r`, `body_leg_l`, `body_leg_r`, `head`, `hair_back`, `hair_front`, `face_neutral`, `face_happy`, `face_hurt`, `face_angry`, `outfit_top`, `outfit_bottom`, `outfit_extra_<n>`, `accessory_<n>`. A missing optional part is allowed; the validator lists required ones.
- *Enemy animation names:* `walk` (6-8 frames), `attack` (4), `death` (4-6); `idle` optional. Frame cells are 256x256 and the sheet is one horizontal strip.
- *`parts.json` example:*
```json
{"schema_version": 1, "canvas": [1024, 2048],
 "parts": [{"name": "body_torso", "pivot": [512, 1100], "z": 10, "parent": null},
           {"name": "head", "pivot": [512, 700], "z": 20, "parent": "body_torso"}]}
```
- *Enemy `<asset_id>.json` example:*
```json
{"schema_version": 1, "frame_size": 256, "faces": "right",
 "anims": [{"name": "walk", "frames": 8, "fps": 12, "loop": true}]}
```
These are proposals for the validator to enforce; the canvas width of the waifu layers is not yet defined (only 2048 px height is) and will be fixed in the M4 art spike.

## 4. Local generation pipeline (ComfyUI) **[P]**
Stages (each stage's output is stored; every stage can be rerun):
1. **Character design:** prompt + style reference to concept art. Human picks the winner.
2. **Consistent character sheet:** generate turnaround/expressions from the chosen design (a "consistent character" workflow in ComfyUI).
3. **Outfit variants:** generate outfit versions of the same character. Human approval.
4. **Part separation:** split the approved character into layers (segmentation + background removal + inpainting of hidden areas). Output: layered PNG set + a `parts.json` manifest (names, pivots, draw order).
5. **Rig in Godot:** parts assembled as a 2D skeleton scene; idle/attack/hit/win animations authored as Godot animation resources (can be scripted by agents from a template).
6. **Enemies:** reference image to short motion clip (image-to-video) or direct sprite-sheet workflow, then frame extraction, background removal (BiRefNet-style), pixel/size normalization, packing into a sheet + `.json` metadata.
- Existing community ComfyUI pipelines for image → sprite sheets (with background removal and segmentation for separable cosmetic layers) are a good starting reference for stages 4 and 6; evaluate in the art spike (milestone M4) and record the chosen workflow files in `assets_src/workflows/`.
- Workflows are saved as **ComfyUI API-format JSON** in `assets_src/workflows/` so a script can run them headless through ComfyUI's HTTP API.

## 5. Asset Forge (dev tool) **[P]**
A Python CLI in `/tools/asset_forge` that:
- submits a workflow + parameters to the local ComfyUI API and collects outputs,
- post-processes (trim, normalize size, pivot, pack atlas),
- validates specs from section 3 (size, transparency, frame count, naming),
- writes/updates the **asset manifest** (section 6),
- imports validated assets into `game/` with correct import settings.
Agents use this tool; they never hand-edit generated binaries without recording it in the manifest.

## 6. Asset manifest and provenance **[D]**
Every asset has an entry in `assets_src/manifest.yaml`:
```yaml
- id: waifu_aria_outfit_default
  type: waifu_layers
  status: approved   # draft | needs_review | approved | rejected
  tool: comfyui      # comfyui | external
  model: <model name + version>
  workflow: workflows/waifu_layers_v1.json
  prompt: "<prompt>"
  seed: 123456
  created: 2026-10-07
  human_edits: "none"   # describe manual touch-ups
  approved_by: <name>   # required before status approved
```
Reasons: Steam AI disclosure (see `05_STEAM_AND_COMPLIANCE.md`), reproducibility, and evidence of human creative input.

## 7. External-tool import spec (for manual generation by the owner) **[D]**
You can generate art with any outside tool and drop it in. Follow this so agents can ingest it without guessing.

**Drop folder:** `assets_src/incoming/<asset_id>/`

**Required files per asset type**
- *Waifu layers:* one PNG per part, transparent background, same canvas size (2048 px tall), named `<asset_id>__<part>.png`, plus a `parts.json` (part name, pivot x/y in px, draw order, parent part). Part list: see section 3.
- *Waifu portrait:* `<asset_id>__portrait.png`, 1024x1536, transparent or flat removable background.
- *Enemy sprite sheet:* `<asset_id>__<anim>.png`, frames in one horizontal strip, equal cell size (256 px), plus `<asset_id>.json` (anim name, frame count, fps, loop). Enemy faces right.
- *Static (props/tiles/UI):* single PNG per item at the sizes in section 3.

**Always add** `meta.yaml` with: tool and model used, prompt, seed if known, any manual edits. Missing metadata = asset stays `needs_review` and cannot be marked approved.

**Content check before dropping files (human):** no nudity, no explicit poses, clearly adult character, stays within limits in `05_STEAM_AND_COMPLIANCE.md`.

**What happens next:** an agent runs `asset_forge validate` on the folder, reports problems (wrong size, no alpha, missing parts), and on success imports it and creates a `needs_review` manifest entry. A human approves.

### Prompt template (starting point, adapt per tool)
```
Adult anime woman with adult proportions, <hair/eyes/personality>, wearing <outfit>, full body, front view,
flat even lighting, clean line art, soft cel shading, transparent or plain white background,
adult character, <style reference>.
Negative: nudity, explicit, child, childlike, chibi, extra limbs, text, watermark, cropped, dark background.
```
For parts: generate the full character first, then separate parts or re-generate "<part> only, isolated, transparent background" using the full character as image reference.

## 8. Open questions **[O]**
- Final art style reference (a few reference images from the owner would help).
- Specific models/LoRAs for the style (choose in the art spike).
- Whether to hand-touch key characters (recommended for IP protection; see compliance doc).
