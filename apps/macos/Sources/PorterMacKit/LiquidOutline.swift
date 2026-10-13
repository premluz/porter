import CoreGraphics
import SwiftUI

/// A signed distance with the direction it grows in: negative inside, positive outside.
struct FieldSample {
    var distance: CGFloat
    var gradient: CGVector
}

/// The panel as a liquid: a rounded box fused with the screen edge, the way Apple's render server joins glass shapes.
/// The edge is a half-plane; the two are joined by a smooth minimum whose reach depends on how much the surfaces face
/// each other, so where the box's side meets the edge at a right angle a fillet forms, and where the box faces the
/// edge across a gap a neck forms. Nothing is stitched together, so there is never a seam or a gap at any point of a
/// move.
enum LiquidField {
    /// Distance to a box with rounded corners, and the outward direction.
    static func roundedBox(_ p: CGPoint, _ box: CGRect, corner: CGFloat) -> FieldSample {
        let r = min(corner, box.width / 2, box.height / 2)
        let lx = p.x - box.midX, ly = p.y - box.midY
        let qx = abs(lx) - box.width / 2 + r, qy = abs(ly) - box.height / 2 + r
        let mx = max(qx, 0), my = max(qy, 0)
        let outside = (mx * mx + my * my).squareRoot()
        let distance = outside + min(max(qx, qy), 0) - r
        let sx: CGFloat = lx < 0 ? -1 : 1, sy: CGFloat = ly < 0 ? -1 : 1
        let gradient = outside > 1e-4
            ? CGVector(dx: mx / outside * sx, dy: my / outside * sy)
            : (qx > qy ? CGVector(dx: sx, dy: 0) : CGVector(dx: 0, dy: sy))
        return FieldSample(distance: distance, gradient: gradient)
    }

    /// Distance to the region beyond the screen edge at `x`.
    static func beyondEdge(_ p: CGPoint, x: CGFloat, edge: PanelEdge) -> FieldSample {
        edge == .right
            ? FieldSample(distance: x - p.x, gradient: CGVector(dx: -1, dy: 0))
            : FieldSample(distance: p.x - x, gradient: CGVector(dx: 1, dy: 0))
    }

    /// Smooth union whose reach is `k` where the surfaces face each other, half that at a right angle, and none
    /// where they run side by side, so the shape never bulges along a straight run.
    static func union(_ a: FieldSample, _ b: FieldSample, k: CGFloat) -> FieldSample {
        let facing = 0.5 - 0.5 * (a.gradient.dx * b.gradient.dx + a.gradient.dy * b.gradient.dy)
        let reach = k * min(max(facing, 0), 1) + 1e-4
        let h = min(max(0.5 + 0.5 * (b.distance - a.distance) / reach, 0), 1)
        let distance = b.distance + (a.distance - b.distance) * h - reach * h * (1 - h)
        let gx = b.gradient.dx + (a.gradient.dx - b.gradient.dx) * h
        let gy = b.gradient.dy + (a.gradient.dy - b.gradient.dy) * h
        let length = max((gx * gx + gy * gy).squareRoot(), 1e-5)
        return FieldSample(distance: distance, gradient: CGVector(dx: gx / length, dy: gy / length))
    }
}

/// Traces where a distance field crosses zero (marching squares), as closed outlines. Values on the region's border
/// are treated as outside, so every outline closes inside the region; fill it even-odd.
enum ContourTracer {
    static func path(region: CGRect, step: CGFloat, field: (CGPoint) -> CGFloat) -> Path {
        let columns = Int((region.width / step).rounded(.up)) + 1
        let rows = Int((region.height / step).rounded(.up)) + 1
        guard columns > 2, rows > 2 else { return Path() }
        var values = [CGFloat](repeating: 1, count: columns * rows)
        for j in 1..<(rows - 1) {
            for i in 1..<(columns - 1) {
                values[j * columns + i] = field(CGPoint(x: region.minX + CGFloat(i) * step, y: region.minY + CGFloat(j) * step))
            }
        }
        let grid = Grid(origin: region.origin, step: step, columns: columns, values: values)
        return grid.loops(rows: rows)
    }

    private struct Grid {
        let origin: CGPoint
        let step: CGFloat
        let columns: Int
        let values: [CGFloat]

        func value(_ i: Int, _ j: Int) -> CGFloat { values[j * columns + i] }
        func point(_ i: Int, _ j: Int) -> CGPoint { CGPoint(x: origin.x + CGFloat(i) * step, y: origin.y + CGFloat(j) * step) }

        /// Edge ids: even for the edge from (i, j) to (i+1, j), odd for the edge from (i, j) to (i, j+1).
        func crossing(_ id: Int) -> CGPoint {
            let cell = id / 2, i = cell % columns, j = cell / columns
            let (i2, j2) = id % 2 == 0 ? (i + 1, j) : (i, j + 1)
            let a = value(i, j), b = value(i2, j2)
            let t = a / (a - b)
            let p = point(i, j), q = point(i2, j2)
            return CGPoint(x: p.x + (q.x - p.x) * t, y: p.y + (q.y - p.y) * t)
        }

        func loops(rows: Int) -> Path {
            var links: [Int: [Int]] = [:]
            for j in 0..<(rows - 1) {
                for i in 0..<(columns - 1) {
                    for (a, b) in segments(i, j) {
                        links[a, default: []].append(b)
                        links[b, default: []].append(a)
                    }
                }
            }
            return walk(links)
        }

        /// The pieces of outline inside one cell, as pairs of edge ids.
        private func segments(_ i: Int, _ j: Int) -> [(Int, Int)] {
            let v00 = value(i, j), v10 = value(i + 1, j), v11 = value(i + 1, j + 1), v01 = value(i, j + 1)
            let mask = (v00 < 0 ? 1 : 0) | (v10 < 0 ? 2 : 0) | (v11 < 0 ? 4 : 0) | (v01 < 0 ? 8 : 0)
            let top = (j * columns + i) * 2, left = top + 1
            let bottom = ((j + 1) * columns + i) * 2, right = ((j * columns) + i + 1) * 2 + 1
            let centreInside = (v00 + v10 + v11 + v01) / 4 < 0
            switch mask {
            case 0, 15: return []
            case 1, 14: return [(left, top)]
            case 2, 13: return [(top, right)]
            case 3, 12: return [(left, right)]
            case 4, 11: return [(right, bottom)]
            case 6, 9: return [(top, bottom)]
            case 7, 8: return [(left, bottom)]
            case 5: return centreInside ? [(left, bottom), (top, right)] : [(left, top), (right, bottom)]
            default: return centreInside ? [(left, top), (right, bottom)] : [(top, right), (left, bottom)]
            }
        }

        private func walk(_ links: [Int: [Int]]) -> Path {
            var path = Path()
            var visited = Set<Int>()
            for start in links.keys.sorted() where !visited.contains(start) {
                var previous = start, current = start
                path.move(to: crossing(start))
                visited.insert(start)
                while let next = links[current]?.first(where: { $0 != previous && !visited.contains($0) }) {
                    path.addLine(to: crossing(next))
                    visited.insert(next)
                    previous = current
                    current = next
                }
                path.closeSubpath()
            }
            return path
        }
    }
}
