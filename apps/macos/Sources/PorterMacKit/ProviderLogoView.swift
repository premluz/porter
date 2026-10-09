import AppKit
import PorterPanelModel
import SwiftUI

/// The assistant's logo, taken from the app installed on this Mac rather than a copy bundled with Porter. Without that
/// app a plain symbol stands in, so a missing app never leaves a gap or a wrong logo.
struct ProviderLogoView: View {
    let provider: String

    var body: some View {
        icon
            .frame(width: Tokens.Size.providerLogo, height: Tokens.Size.providerLogo)
            .clipShape(Circle())
            .help(ProviderNames.display(provider))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var icon: some View {
        if let image = ProviderIcons.image(for: ProviderNames.brand(for: provider)) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(systemName: "sparkles").resizable().scaledToFit().padding(2).foregroundStyle(Palette.textSecondary)
        }
    }
}

@MainActor
enum ProviderIcons {
    private static var cache: [String: NSImage] = [:]

    static func image(for brand: ProviderNames.Brand) -> NSImage? {
        let bundleId: String
        switch brand {
        case .claude: bundleId = HostApplication.claudeApp.bundleIdentifier
        case .chatgpt: bundleId = HostApplication.chatgptApp.bundleIdentifier
        case .other: return nil
        }
        if let cached = cache[bundleId] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else { return nil }
        let image = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleId] = image
        return image
    }
}

/// A small rounded label, used for the project an agent chat belongs to.
struct PillView: View {
    let text: String

    var body: some View {
        Text(text).font(.caption2.weight(.medium)).lineLimit(1)
            .padding(.horizontal, Tokens.Space.s).padding(.vertical, 1)
            .background(Capsule().fill(Palette.pillBacking))
            .frame(maxWidth: Tokens.Size.pillMaximumWidth, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
    }
}
