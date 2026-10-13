import PorterPanelModel
import SwiftUI

/// What the docked tab's face says about all the chats together.
enum MascotTone: Equatable {
    case attention, working, quiet

    /// A question to answer outranks work in progress, which outranks nothing.
    init(_ status: ItemStatus?) {
        switch status?.display {
        case .needsUser: self = .attention
        case .working: self = .working
        default: self = .quiet
        }
    }

    var color: Color {
        switch self {
        case .attention: Palette.statusAttention
        case .working: Palette.statusWorking
        case .quiet: Palette.mascotQuiet
        }
    }
}

/// The docked tab's face: a round body, coloured by the state of all the chats, with two eyes that look towards the
/// middle of the screen.
struct MascotView: View {
    let tone: MascotTone
    let opensFrom: PanelEdge
    var speaking = false
    var listening = false

    /// The eyes turn away from the edge the tab is docked on, towards where the panel will open.
    static func gaze(opensFrom edge: PanelEdge) -> CGFloat {
        edge == .right ? -Tokens.Mascot.gaze : Tokens.Mascot.gaze
    }

    var body: some View {
        Circle().fill(tone.color)
            .frame(width: Tokens.Mascot.size, height: Tokens.Mascot.size)
            .overlay {
                HStack(spacing: Tokens.Mascot.eyeGap) { eye; eye }
                    .offset(x: Self.gaze(opensFrom: opensFrom), y: -Tokens.Mascot.eyeLift)
            }
            .overlay(alignment: .bottom) {
                if speaking {
                    Capsule().fill(Palette.mascotEye)
                        .frame(width: Tokens.Mascot.mouthWidth, height: Tokens.Mascot.mouthHeight)
                        .padding(.bottom, Tokens.Mascot.mouthInset)
                }
            }
            .overlay {
                if listening {
                    Circle().stroke(Palette.statusWorking, lineWidth: Tokens.Size.edgeLine)
                        .frame(width: Tokens.Mascot.listeningSize, height: Tokens.Mascot.listeningSize)
                }
            }
            .accessibilityHidden(true)
    }

    private var eye: some View {
        Capsule().fill(Palette.mascotEye).frame(width: Tokens.Mascot.eyeWidth, height: Tokens.Mascot.eyeHeight)
    }
}
