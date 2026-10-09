import PorterPanelModel
import SwiftUI

/// The setup window's content: one line per source, what state it is in, and the one thing to do about it.
struct SetupView: View {
    let model: SetupModel

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Porter").font(.title2.bold())
                Text(model.summary).foregroundStyle(Palette.textSecondary)
            }
            if model.sections.isEmpty {
                Text("Porter is showing sample data, so there is nothing to set up.").foregroundStyle(Palette.textSecondary)
            }
            ForEach(model.sections) { section in
                VStack(alignment: .leading, spacing: Tokens.Space.s) {
                    Text(section.title).font(.caption).textCase(.uppercase).foregroundStyle(Palette.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(section.rows) { row in SetupRowView(row: row, perform: model.perform) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.xl)
        .frame(width: Tokens.Size.setupWidth, alignment: .topLeading)
    }
}

private struct SetupRowView: View {
    let row: SetupRow
    let perform: (SetupAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: Tokens.Size.setupIcon)
                .accessibilityLabel(stateLabel)
            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text(row.title).font(.headline)
                Text(row.detail).font(.callout).foregroundStyle(Palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Tokens.Space.s)
            if let action = row.action, let title = row.actionTitle {
                Button(title) { perform(action) }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch row.state {
        case .ready: "checkmark.circle.fill"
        case .needsAction: "exclamationmark.triangle.fill"
        case .waiting: "moon.zzz"
        case .optional: "circle.dashed"
        case .checking: "ellipsis.circle"
        }
    }

    private var tint: Color {
        switch row.state {
        case .ready: Palette.statusWorking
        case .needsAction: Palette.statusAttention
        case .waiting, .optional, .checking: Palette.textSecondary
        }
    }

    private var stateLabel: String {
        switch row.state {
        case .ready: "Ready"
        case .needsAction: "Needs your permission"
        case .waiting: "Waiting for the app to open"
        case .optional: "Optional, not set up"
        case .checking: "Checking"
        }
    }
}
