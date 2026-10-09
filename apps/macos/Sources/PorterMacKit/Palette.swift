import AppKit
import SwiftUI

/// Semantic colours from docs/UX_DESIGN.md. They resolve to system colours, so appearance,
/// contrast and accent settings are followed without any fixed values here.
enum Palette {
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let borderSubtle = Color(nsColor: .separatorColor)
    static let surfaceOpaque = Color(nsColor: .windowBackgroundColor)
    /// A calm backing under rows so text stays readable over bright or busy windows.
    static let contentBacking = Color(nsColor: .windowBackgroundColor).opacity(0.38)
    static let selection = Color.accentColor.opacity(0.22)
    static let pillBacking = Color.secondary.opacity(0.2)
    static let glassEdge = Color.primary.opacity(0.22)
    static let dotHover = Color.primary.opacity(0.16)
    static let rowHover = Color.primary.opacity(0.07)
    static let statusAttention = Color.orange
    static let statusUnread = Color.accentColor
    static let statusWorking = Color.green
}
