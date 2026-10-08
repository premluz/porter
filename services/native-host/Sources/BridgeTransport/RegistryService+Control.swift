import ConversationCore
import Foundation
import Synchronization

/// Lets a control request block until the connector answers or the coordinator times it out.
final class ActivationWaiter: Sendable {
    private let signal = DispatchSemaphore(value: 0)
    private let answer = Mutex<ActivationResult?>(nil)

    func fulfill(_ result: ActivationResult) {
        answer.withLock { $0 = result }
        signal.signal()
    }

    func wait(timeout: TimeInterval) -> ActivationResult? {
        _ = signal.wait(timeout: .now() + timeout)
        return answer.withLock { $0 }
    }
}

public struct RegistryListing: Sendable, Equatable {
    public let connectors: [ConnectorSummary]
    public let rows: [DestinationRow]

    public init(connectors: [ConnectorSummary], rows: [DestinationRow]) {
        self.connectors = connectors
        self.rows = rows
    }
}

public struct ActivationReport: Sendable, Equatable {
    public let outcome: ActivationOutcome
    /// Result of asking macOS to bring Chrome forward; nil when the tab was not activated.
    public let appActivation: String?

    public init(outcome: ActivationOutcome, appActivation: String?) {
        self.outcome = outcome
        self.appActivation = appActivation
    }
}

extension RegistryService {
    public func listing() -> RegistryListing {
        coordinator.withLock { RegistryListing(connectors: $0.connectorSummaries(), rows: $0.rows()) }
    }

    /// Blocks until the connector answers or times out; call from a background context.
    public func activate(destinationId: UUID, expectedRevision: Int) -> ActivationReport {
        let waiter = ActivationWaiter()
        let start = coordinator.withLock {
            $0.requestActivation(destinationId: destinationId, expectedRevision: expectedRevision, now: Date())
        }
        switch start {
        case .refused(let result):
            return ActivationReport(outcome: result.outcome, appActivation: nil)
        case .dispatched(let requestId, let outbound):
            return sendAndAwait(requestId, outbound, waiter, afterPreparation: nil)
        case .dispatchedAfterPreparation(let requestId, let outbound, let preparation):
            let prepared = prepareActivation(preparation)
            log("prepared \(preparation.bundleId): \(prepared)")
            Thread.sleep(forTimeInterval: windowSettleDelay)
            return sendAndAwait(requestId, outbound, waiter, afterPreparation: prepared)
        }
    }

    /// Sends the request and blocks until the connector answers or the coordinator times it out.
    /// A browser activation then asks macOS to bring the browser forward; an editor one already did.
    private func sendAndAwait(
        _ requestId: UUID, _ outbound: [Outbound], _ waiter: ActivationWaiter, afterPreparation: String?
    ) -> ActivationReport {
        waiters.withLock { $0[requestId] = waiter }
        defer { waiters.withLock { $0[requestId] = nil } }
        apply(BridgeResult(outbound: outbound))
        guard let result = waiter.wait(timeout: activationTimeout + Self.waitMargin) else {
            return ActivationReport(outcome: .timeout, appActivation: nil)
        }
        guard result.outcome == .activated else { return ActivationReport(outcome: result.outcome, appActivation: nil) }
        return ActivationReport(outcome: .activated, appActivation: afterPreparation ?? focusApplication())
    }

    func serveControl(_ connection: FramedConnection) {
        defer { connection.closeDescriptor() }
        do {
            guard let frame = try connection.receive(maximumBytes: ControlLimits.maximumRequestBytes) else { return }
            let response = respond(to: frame)
            try connection.send(try JSONEncoder().encode(response))
        } catch {
            log("control: request failed: \(error)")
        }
    }

    private func respond(to frame: Data) -> ControlResponse {
        let request: ControlRequest
        do {
            request = try JSONDecoder().decode(ControlRequest.self, from: frame)
        } catch {
            return .failure("Unreadable control request: \(error)")
        }
        switch request.command {
        case .list:
            return coordinator.withLock { .listing($0.connectorSummaries(), $0.rows()) }
        case .activate:
            guard let destinationId = request.destinationId, let revision = request.revision else {
                return .failure("activate needs destinationId and revision")
            }
            let report = activate(destinationId: destinationId, expectedRevision: revision)
            return .activation(report.outcome, appActivation: report.appActivation)
        }
    }
}
