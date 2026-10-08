import Foundation

public enum ActivationStart: Sendable, Equatable {
    /// The request is on the wire; the outcome arrives later as a `.activation` event.
    case dispatched(requestId: UUID, outbound: [Outbound])
    /// Nothing was sent. The result says why, so no one waits on an acknowledgment that cannot come.
    case refused(ActivationResult)
}

extension BridgeCoordinator {
    /// Navigation only. The revision must be the one the user saw, so a changed target is refused
    /// instead of silently opening whatever the tab became.
    public mutating func requestActivation(
        destinationId: UUID, expectedRevision: Int, now: Date
    ) -> ActivationStart {
        let requestId = UUID()
        func refuse(_ outcome: ActivationOutcome) -> ActivationStart {
            .refused(ActivationResult(
                requestId: requestId, destinationId: destinationId,
                destinationRevision: expectedRevision, outcome: outcome
            ))
        }
        let destination: Destination
        switch registry.resolve(destinationId, expectedRevision: expectedRevision) {
        case .current(let resolved): destination = resolved
        case let failed:
            return refuse(failed.failureOutcome ?? .failed)
        }
        guard destination.supports(.activate), case .browserTab(let tab) = destination.locator else {
            return refuse(.unsupported)
        }
        guard let connection = connectionByInstallation[connectors[tab.connectorId]?.installationId ?? UUID()] else {
            return refuse(.connectorOffline)
        }
        guard let conversation = conversations[destination.conversationId],
              let providerConversationId = conversation.providerConversationId else {
            return refuse(.failed)
        }
        let payload = ActivateRequestPayload(
            requestId: requestId, destinationId: destinationId, destinationRevision: expectedRevision,
            tabId: tab.tabId, windowId: tab.windowIdHint ?? 0, expectedProvider: conversation.provider,
            expectedConversationId: providerConversationId
        )
        pending[requestId] = PendingActivation(
            connection: connection, destinationId: destinationId, destinationRevision: expectedRevision,
            deadline: now.addingTimeInterval(activationTimeout)
        )
        return .dispatched(requestId: requestId, outbound: send(.activateRequest, payload, to: connection).outbound)
    }

    /// A late acknowledgment is not an answer: timeout means the focus request may have happened.
    public mutating func sweep(now: Date) -> BridgeResult {
        var result = BridgeResult()
        for (requestId, request) in pending where request.deadline <= now {
            pending[requestId] = nil
            result.events.append(.activation(Self.result(requestId, request, .timeout)))
        }
        return result
    }

    mutating func completeActivation(_ answer: ActivationResult, from connection: ConnectionID) -> BridgeResult {
        guard let request = pending[answer.requestId], request.connection == connection,
              request.destinationId == answer.destinationId,
              request.destinationRevision == answer.destinationRevision else {
            return violation(connection, .outOfOrder, "activation result matches no pending request", close: false)
        }
        pending[answer.requestId] = nil
        return BridgeResult(events: [.activation(answer)])
    }
}
