import ConversationCore
import Foundation
import PorterPanelModel

extension AppModel {
    /// Reads a packet the user chose. The file is size-checked before it is read at all.
    public func importPacket(from url: URL) {
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= ContextPacketDecoder.maximumBytes else { throw PacketRejection.tooLarge(bytes: size) }
            try beginReview(of: ContextPacketDecoder.decode(Data(contentsOf: url)))
        } catch let rejection as PacketRejection {
            problem = "That packet was refused: \(describe(rejection))"
        } catch {
            problem = "Could not read that file: \(error)"
        }
    }

    public func beginReview(of packet: ContextPacket) {
        let review = PacketReview(packet: packet)
        packetReview = review
        problem = nil
        let candidates = review.destinationCandidates(in: items)
        packetDestinationId = candidates.count == 1 ? candidates[0].id : nil
    }

    public func togglePacketSource(_ index: Int) {
        packetReview?.toggle(index)
    }

    public func choosePacketDestination(_ item: PanelItem?) {
        packetDestinationId = item?.id
    }

    public func endPacketReview() {
        packetReview = nil
        packetDestinationId = nil
    }

    public var packetDestination: PanelItem? {
        items.first { $0.id == packetDestinationId }
    }

    /// Copy only. The user pastes it wherever they choose.
    public func copyPacket() {
        guard let text = renderedPacket() else { return }
        performer.copyToPasteboard(text)
        notice = "Copied. Paste it where you want it; Porter never sends it for you."
    }

    /// Copy, then open the destination the user chose. A destination that cannot be opened leaves the
    /// text on the pasteboard and says so.
    public func copyPacketAndOpen() async {
        guard let text = renderedPacket() else { return }
        guard let destination = packetDestination else {
            problem = "Choose one open destination first."
            return
        }
        guard destination.routes.count == 1 else {
            problem = "That chat is open in \(destination.routes.count) tabs. Open it from the list to choose which one."
            return
        }
        performer.copyToPasteboard(text)
        await activate(destination, destination.routes[0])
        if feedback != nil { notice = "The text is copied, but the destination could not be opened." }
    }

    private func renderedPacket() -> String? {
        guard let review = packetReview else { return nil }
        do throws(PacketReviewError) {
            return try review.rendered()
        } catch {
            switch error {
            case .nothingToCopy:
                problem = "Nothing is included, so there is nothing to copy."
            case .overLimit(let count, let limit):
                problem = "The included text is \(count) characters; the limit is \(limit). Turn some sources off."
            }
            return nil
        }
    }

    private func describe(_ rejection: PacketRejection) -> String {
        switch rejection {
        case .tooLarge(let bytes): "it is \(bytes) bytes, over the limit."
        case .unsupportedVersion(let version): "version \(version) is not supported."
        case .malformed(let detail): "it is not a valid packet (\(detail))."
        case .invalid(let detail): detail
        }
    }
}
