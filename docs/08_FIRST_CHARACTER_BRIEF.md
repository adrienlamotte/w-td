# 08 — First character brief (pipeline test)

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

The owner generates the first character with an external tool and imports it (D-060). This file says exactly what to produce. It extends the import spec in `03_ART_PIPELINE.md` section 7; if the two disagree, this file wins for this asset.

## 1. Purpose and scope **[D]**
- Asset id: `waifu_test01`. It is a **pipeline test character**, not a roster member and not final art. It may be reused or dropped later.
- Goal: prove the full chain (generate, validate, separate into parts, rig in Godot, show in-game at tower scale) before real roster art is made.
- Do not give her a name, personality or story. Roster design is a separate task (`backlog/001-roster-proposal.md`).

## 2. Character design constraints **[P]**
- **Adult woman, adult proportions, about 6.5 to 7 heads tall.** No chibi, nothing childlike (D-030).
- Cute and comedic fantasy tone (D-014). Generic adventurer look is fine.
- **Default outfit: modest and fully covered** (for example tunic, skirt or shorts, boots). Suggestive outfits are not part of this test (see `05_STEAM_AND_COMPLIANCE.md`).
- Strong silhouette, one dominant hair colour and one dominant outfit colour so she stays readable at about 250 px tall on screen.
- Front view, facing the camera, standing, arms slightly away from the body (A-pose) so the arms can be separated. No dramatic perspective or foreshortening.
- Flat even lighting, clean outlines, soft cel shading. No cast shadow on the ground, no background, no glow or effects baked in.

## 3. What to deliver

### Level 1 (required)
| File | Spec |
|---|---|
| `waifu_test01__master.png` | Full body, front view, **2048 px tall**, transparent background, character centred, feet near the bottom (see section 4) |
| `waifu_test01__face_neutral.png`, `__face_happy.png`, `__face_hurt.png`, `__face_angry.png` | The 4 expressions. Either full-body images identical to the master except the face, or head-only crops at the same scale |
| `waifu_test01__portrait.png` | 1024x1536, upper body or three-quarter, same character, transparent or plain flat background |
| `meta.yaml` | See section 6 |

### Level 2 (preferred; if you cannot, deliver Level 1 and the ComfyUI pipeline will separate the parts, stage 4 in the art pipeline doc)
One PNG per part, **all on the same 1024x2048 canvas and the same coordinates as the master**, transparent everywhere except the part. Hidden areas must be completed (the torso under the arms, `hair_back` in full, the legs under the skirt), so a part can rotate without a hole showing.

Required parts (canonical names from `03_ART_PIPELINE.md`):
`body_torso`, `body_arm_l`, `body_arm_r`, `body_leg_l`, `body_leg_r`, `head`, `hair_back`, `hair_front`, `face_neutral`, `face_happy`, `face_hurt`, `face_angry`, `outfit_top`, `outfit_bottom`.
Optional: `outfit_extra_<n>`, `accessory_<n>`.
File names: `waifu_test01__<part>.png`.

Plus `parts.json` (format below). Pivots are the joint positions in canvas pixels (shoulder for the arms, hip for the legs, neck for the head).
```json
{"schema_version": 1, "canvas": [1024, 2048],
 "parts": [{"name": "body_torso", "pivot": [512, 1100], "z": 10, "parent": null},
           {"name": "head", "pivot": [512, 700], "z": 20, "parent": "body_torso"}]}
```
`z` is the draw order (higher is in front). `parent` is the part it rotates with. These example numbers are placeholders.

## 4. Technical requirements **[P]**
- PNG, RGBA, 8 bits per channel, sRGB. No palette or indexed PNG.
- **Clean edges:** no white or black fringe around the character (remove the halo left by background removal), no semi-transparent junk pixels away from the outline.
- Canvas for parts: **1024x2048**. Master: same canvas. Character centred horizontally at x = 512; feet baseline at about y = 1990; top of the head at y = 60 or lower, so nothing touches the canvas edge.
- All files share the same scale, lighting direction and palette. Generate the parts from the master (inpainting or image-to-image with the master as reference), do not generate each part independently.
- No text, signature, watermark, border or UI.
- Keep the original generation file if the tool gives one (layered PSD or similar), but it is optional and not needed for import.

## 5. Content check (owner, before handing over) **[D]**
- Clearly adult, with adult proportions and features.
- No nudity, no explicit pose, no see-through clothing.
- No real person, existing character or recognisable franchise design, and no real artist's name in the prompt.
- If the tool or model has licence terms, confirm commercial use is allowed (record the answer in `meta.yaml`).

## 6. `meta.yaml` **[D]**
```yaml
asset_id: waifu_test01
tool: <tool name and version, or comfyui>
model: <model / LoRA names and versions>
commercial_use_allowed: <yes | no | unknown>
prompt: "<positive prompt>"
negative_prompt: "<negative prompt>"
seed: <number or unknown>
workflow: <name or link, or none>
created: <date>
human_edits: "<what you changed by hand, or none>"
notes: "<anything else>"
```
Missing metadata keeps the asset in `needs_review`. The record is also the source for the Steam AI disclosure (`05_STEAM_AND_COMPLIANCE.md`).

## 7. Handover
1. Put the files in `assets_src/incoming/waifu_test01/` of the repo (or attach them in a design session and I will place them).
2. Until the Asset Forge tool exists (M4), an agent validates by hand against this brief and reports: sizes, alpha, edges, missing parts, consistency.
3. On success it creates a `needs_review` entry in `assets_src/manifest.yaml`; the owner approves.
4. Large PNG files: the storage choice (Git LFS or not) is deferred (Q-37). Until then, commit this small test character as plain files on a branch.

## 8. Prompt starter (adapt to your tool)
```
Adult anime woman, adult proportions, about 7 heads tall, <hair colour and style>, <eye colour>,
wearing a modest adventurer outfit (<top>, <bottom>, boots), full body, front view, A-pose,
flat even lighting, clean line art, soft cel shading, plain white or transparent background,
cute and cheerful expression.
Negative: chibi, child, childlike, nudity, explicit, extra limbs, text, watermark, cropped,
dark background, shadow on the ground, perspective distortion.
```
For parts: re-generate or inpaint "<part> only, isolated, transparent background" using the master as the reference image.

## 9. What I will check on receipt
- Image sizes and alpha; edge quality; transparency outside the character.
- Parts line up on the master when stacked (no gaps, no drift in scale or colour).
- Every required part exists, hidden areas are complete, pivots are plausible.
- Readability when scaled to about 250 px tall.
- Content rules (section 5) and that `meta.yaml` is complete.

## 10. Optional follow-up
A first horde enemy for the same test, as a sprite-sheet strip (256 px cells, `walk` 6-8 frames, faces right), specified in `03_ART_PIPELINE.md` section 3 and section 7. Not needed for this first delivery.
