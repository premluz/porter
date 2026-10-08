import ConversationCore
import PorterPanelModel
import SwiftUI

/// The review step for a context packet: every source with its citation, the exact text size, and
/// the chosen destination, before anything is copied. Nothing here sends anything.
struct PacketReviewView: View {
    @Bindable var model: AppModel
    let review: PacketReview

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Tokens.Space.m) {
                header
                if let instruction = review.packet.instruction {
                    Text(instruction).font(.callout).foregroundStyle(Palette.textSecondary)
                }
                sources
                ForEach(review.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Palette.statusAttention)
                }
                destination
                actions
            }
            .padding(Tokens.Space.m)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Review before copying").font(.caption).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
            Text(review.packet.title).font(.headline)
            Text("From \(review.packet.createdBy.rawValue.capitalized). Nothing is sent from here.")
                .font(.caption).foregroundStyle(Palette.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var sources: some View {
        if review.packet.sources.isEmpty {
            Text("This packet has no cited sources.").font(.callout).foregroundStyle(Palette.textSecondary)
        }
        ForEach(Array(review.packet.sources.enumerated()), id: \.offset) { index, source in
            Toggle(isOn: Binding(
                get: { review.included.contains(index) }, set: { _ in model.togglePacketSource(index) }
            )) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(source.citation).font(.callout)
                    Text("\(source.freshness.rawValue.capitalized) · \(source.excerpt.prefix(120))…")
                        .font(.caption).foregroundStyle(Palette.textSecondary).lineLimit(2)
                }
            }
        }
    }

    private var destination: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text("Destination").font(.caption).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
            if let chosen = model.packetDestination {
                Text(summary(of: chosen)).font(.callout)
            } else if review.packet.requestedDestination != nil {
                Text(model.items.isEmpty ? "The requested chat is not open." : "Choose which open chat to use.")
                    .font(.callout).foregroundStyle(Palette.textSecondary)
            }
            Menu("Choose a different chat…") {
                ForEach(model.items.filter(\.isOpenable)) { item in
                    Button(summary(of: item)) { model.choosePacketDestination(item) }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text("\(review.characterCount) of \(PacketReview.maximumCharacters) characters")
                .font(.caption).foregroundStyle(review.isOverLimit ? Palette.statusAttention : Palette.textSecondary)
            HStack {
                Button("Copy") { model.copyPacket() }
                Button("Copy and open chat") { Task { await model.copyPacketAndOpen() } }
                    .disabled(model.packetDestination == nil)
                Spacer()
                Button("Close") { model.endPacketReview() }
            }
        }
    }

    /// Profile is always included: two profiles can have chats with identical titles.
    private func summary(of item: PanelItem) -> String {
        [ProviderNames.display(item.provider), item.profileAlias, item.title].compactMap { $0 }.joined(separator: " · ")
    }
}
