---
id: "PLAN-003"
type: "plan"
title: "Docked, floating and open: moving the panel and snapping it to the edge"
status: "active"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/macos", "area/ux", "phase/r1"]
summary: "Three panel states (docked tab, floating capsule, open pane), dragging with a magnetic pull to the edge, reflow to a horizontal strip near the top or bottom, and hover to peek."
related: ["DOC-PLAN", "DOC-UX", "PLAN-002"]
---

# PLAN-003 — Dock states

## What Prem asked for (2026-10-10, with a sketch)

Three states. **Docked**: a small tab on the screen edge that shows a few marks (the sketch shows a needs-you dot and a working spinner) and flares into the edge with concave curves. **Minimised, detached**: the capsule, free to move anywhere. **Maximised**: the open pane. The capsule can be dragged; near the edge it is pulled in magnetically and morphs into the docked tab with a liquid animation. Near the top or bottom of the screen the dots reflow into a horizontal strip, depending on the room available. Hovering a docked tab expands it to the capsule.

## Assumptions (stated, not asked)

- Docking is on the left and right edges only (the existing two edges). The top and bottom are for reflow, not docking.
- Hover peek: pointer enters the docked tab, the capsule grows out of it; leaving returns to the tab after a short delay. A peek capsule can be dragged away, which detaches it.
- The open pane from a docked or peeking capsule opens at its edge, as now; from a floating capsule it opens at the capsule's place, kept on screen, and closes back to it.
- Where it rests (docked edge and height, or floating position) is remembered across launches, as the edge and height are now.

## Order (each step committed with its tests; the app stays usable between steps)

1. A pure model: rest states, frames for each (docked tab with its flare, peek capsule, floating capsule in either orientation), orientation from the room available, the snap decision and the magnetic pull while dragging. Tests only.
2. One shape that can be a capsule, a docked tab with flares, or the pane, and a motion between any two of them, replacing the fixed capsule-to-pane morph. Existing open and close behave as before.
3. Floating and dragging: drag the capsule anywhere, the pull towards the edge, release to dock; drag a docked tab or peek capsule away to detach.
4. The docked tab and hover peek, with the marks it shows.
5. Horizontal reflow near the top or bottom.
6. Remembering the resting state, menu items to dock or float, the settings and the validation notes.

## Progress

Steps 1 to 6 are built, tested and committed (LOG-20261010-005). Left out on purpose: docking to the top or bottom, a menu item to float, dragging by the pane. The step 2 outline (rounded rectangle plus stitched flares) was replaced by a liquid outline, a rounded box fused with the screen edge by a smooth minimum and traced each frame (ADR-007, LOG-20261010-008). Still not done from the demo: a neck while dragging near the edge, the velocity stretch, and the spatial blend from black to glass. The thresholds are guesses until batch R in docs/VALIDATION_RELEASE.md has been run by a person.

The docked tab shows one mark for all the chats together (a waiting question over work in progress), or its face; this replaced the first design of up to three marks on Prem's instruction (LOG-20261010-009).

## Not verifiable here

The feel of the drag, the pull and the liquid shape need a pointer and eyes. Each step has tests for the geometry and a headless check; the rest goes to the validation batch.
