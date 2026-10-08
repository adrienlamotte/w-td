# 007 — View: MultiMesh billboard rendering for the horde and towers
- Status: todo
- Milestone: M1
- Depends on: 006
- PR: -

## Goal
Render enemies (and placeholder towers) as billboarded sprites through one MultiMeshInstance3D per type, animated by a shader, never one Node per enemy.

## Context
- `02_TECH_ARCHITECTURE.md` 2: MultiMesh per enemy type/atlas updated from packed arrays; the shader reads the frame index from per-instance custom data
- `03_ART_PIPELINE.md` 3: enemy frames 256 px, walk 6-8 frames, horde about 85-130 px on screen at 1440p, faces right and flips horizontally, bottom-centre pivot

## Acceptance criteria
- One `MultiMeshInstance3D` per enemy type; the instance buffer is filled from the sim arrays each frame (bulk buffer write, no per-instance Node).
- Billboard, frame animation and horizontal flip in a shader using per-instance custom data.
- Placeholder art is generated procedurally at runtime (no binary art files committed).
- Off-screen culling: only on-screen instances are drawn (or a measured reason why it is not needed).
- Sprite size on screen in the 85-130 px range at 2560x1440 at the default zoom.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
