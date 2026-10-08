import SwiftUI

/// The outer surface. Real Liquid Glass normally; an opaque semantic surface when the user has
/// asked for reduced transparency.
struct GlassBackground: View {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            shape.fill(Palette.surfaceOpaque).overlay(shape.strokeBorder(Palette.borderSubtle))
        } else {
            shape.fill(.clear).glassEffect(.regular, in: shape)
        }
    }
}
