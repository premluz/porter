import PorterPanelModel
import SwiftUI

struct PhoneDetailView: View {
    let item: PanelItem
    let isSample: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Provider", value: ProviderNames.display(item.provider))
                    if let alias = item.profileAlias { LabeledContent("Profile", value: alias) }
                    LabeledContent("Status", value: StatusPresentation.label(for: item.status))
                }
                Section {
                    if let link = openableLink {
                        Link(destination: link) { Label("Open link on this iPhone", systemImage: "arrow.up.right.square") }
                    } else {
                        Text(isSample ? "This is a sample, so there is no real chat to open." : "No saved link for this conversation.")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("It opens with whichever account you are signed into on this iPhone, which may differ from the one on your Mac.")
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    /// Only secure web links, and never for sample data whose addresses go nowhere.
    private var openableLink: URL? {
        guard !isSample, let text = item.canonicalUrl, let url = URL(string: text), url.scheme == "https" else { return nil }
        return url
    }
}
