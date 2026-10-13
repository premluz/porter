---
id: "ADR-007"
type: "decision"
title: "The panel outline is a traced distance field, fused with the screen edge"
status: "accepted"
updated: "2026-10-10"
owner: "project-maintainer"
tags: ["area/macos", "area/ux", "phase/r1"]
summary: "The docked tab, the capsule and the pane are one rounded box fused with the screen edge by a gradient-aware smooth minimum, traced into a path on the CPU each frame, so the native material, the clip and the edge line keep working and no move ever shows a seam."
related: ["PLAN-003"]
---

# ADR-007 — The panel outline is a traced distance field, fused with the screen edge

- Date: 2026-10-10.
- Status: accepted by Prem's direction ("something like metaball liquid") after the stitched outline showed gaps.
- Owner: Prem (direction), assistant (technique).

## Context

PLAN-003 step 2 drew the docked tab as a rounded rectangle unioned with two quarter-circle flares. At rest that can be made seamless, but during the fold from capsule to tab the flares hang beside a body that is not yet at the edge, and gaps show. Prem pointed to a WebGL demo (github.com/aaaa-zhen/glsl-playground, MIT) that gets the liquid look from distance fields: the screen edge is a half-plane, the blob a rounded box, joined by a gradient-aware smooth minimum (a line-by-line translation of QuartzCore's `sdf_union`).

Apple's public liquid APIs (SwiftUI `GlassEffectContainer`, `glassEffectID`, `glassEffectUnion`, `glassEffectTransition`; AppKit `NSGlassEffectContainerView`) merge glass shapes the same way, but only Liquid Glass with Liquid Glass. They cannot fuse a shape with the screen edge, cannot make the docked tab solid black, and Liquid Glass adapts to the backdrop, which Prem rejected for this panel.

## Decision

1. The outline is the zero line of one field: a rounded box (the panel's rectangle, reaching past the screen edge by its corner as it fuses) joined to the region beyond the screen edge with the gradient-aware smooth minimum. Its reach is half of `k` where the box's sides meet the edge at a right angle (the fillets), all of `k` where the box faces the edge across a gap (the neck), and nothing along a straight run.
2. The field is traced into a `Path` with marching squares on the CPU each frame (`LiquidField`, `ContourTracer`), no finer than 1 pt and at most 24,000 cells, so a large shape is traced more coarsely. A shape with no fusion is the plain rounded rectangle.
3. The shape carries its fusion explicitly (`EdgeFusion`: which edge, where it is in window coordinates, reach), because the window during a move is inflated past the screen edge and cannot stand in for it.
4. Not a Metal shader: the native menu material sits under the clip, and a shader would need a metallib that `swift build` does not produce; the CPU trace is fast enough (FACT-033).

## Consequences

- The fold, the peek and the open from a docked tab are one continuous liquid shape with no seams; the edge visibly reaches for the capsule just before they join.
- The capsule and tab corners are circular where fused and continuous (squircle) where not; the switch happens at a reach of 0.25 pt and differs by a fraction of a point.
- Debug builds trace slowly (about 14 ms for the largest frame) and drop frames; judge the motion only in release builds.
- Not done: the demo's velocity stretch, its spatial blend from black at the edge to glass on the blob, and a neck while dragging near the edge (the floating window does not reach the edge yet).
