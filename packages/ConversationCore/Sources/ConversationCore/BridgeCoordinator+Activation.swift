import Foundation

public enum ActivationStart: Sendable, Equatable {
    /// The request is on the wire; the outcome arrives later as a `.activation` event.
    case dispatched(requestId: UUID, outbound: [Outbound])
    /// Same, but the host must first bring an editor window forward and give it a moment.
    case dispatchedAfterPreparation(requestId: UUID, outbound: [Outbound], preparation: ActivationPreparation)
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
        guard destination.supports(.activate), let connectorId = destination.connectorId else {
            return refuse(.unsupported)
        }
        guard let connection = connectionByInstallation[connectors[connectorId]?.installationId ?? UUID()] else {
            return refuse(.connectorOffline)
        }
        guard let conversation = conversations[destination.conversationId],
              let payload = Self.activationPayload(requestId, destination, conversation) else {
            return refuse(.unsupported)
        }
        pending[requestId] = PendingActivation(
            connection: connection, destinationId: destinationId, destinationRevision: expectedRevision,
            deadline: now.addingTimeInterval(activationTimeout)
        )
        let outbound = send(.activateRequest, payload, to: connection).outbound
        if case .editorTab(let editor) = destination.locator {
            let preparation = ActivationPreparation(bundleId: editor.bundleId, workspacePath: editor.workspacePath)
            return .dispatchedAfterPreparation(requestId: requestId, outbound: outbound, preparation: preparation)
        }
        // A thread of a project is opened in that project's editor window, which must be in front first.
        if case .appEntry(let entry) = destination.locator, let path = entry.workspacePath, entry.bundleId == LocatorPolicy.vscodeBundleId {
            let preparation = ActivationPreparation(bundleId: entry.bundleId, workspacePath: path)
            return .dispatchedAfterPreparation(requestId: requestId, outbound: outbound, preparation: preparation)
        }
        return .dispatched(requestId: requestId, outbound: outbound)
    }

    private static func activationPayload(
        _ requestId: UUID, _ destination: Destination, _ conversation: Conversation
    ) -> ActivateRequestPayload? {
        guard let providerConversationId = conversation.providerConversationId else { return nil }
        switch destination.locator {
        case .browserTab(let tab):
            return ActivateRequestPayload(
                requestId: requestId, destinationId: destination.id, destinationRevision: destination.revision,
                tabId: tab.tabId, windowId: tab.windowIdHint ?? 0, expectedProvider: conversation.provider,
                expectedConversationId: providerConversationId, editor: nil, app: nil
            )
        case .editorTab(let editor):
            return ActivateRequestPayload(
                requestId: requestId, destinationId: destination.id, destinationRevision: destination.revision,
                tabId: nil, windowId: nil, expectedProvider: conversation.provider,
                expectedConversationId: providerConversationId,
                editor: EditorTarget(
                    workspacePath: editor.workspacePath, viewColumn: editor.viewColumn, index: editor.index,
                    expectedTitle: conversation.title
                ),
                app: nil
            )
        case .appEntry(let entry):
            return ActivateRequestPayload(
                requestId: requestId, destinationId: destination.id, destinationRevision: destination.revision,
                tabId: nil, windowId: nil, expectedProvider: conversation.provider,
                expectedConversationId: providerConversationId, editor: nil,
                app: AppTarget(bundleId: entry.bundleId, expectedTitle: entry.title, ordinal: entry.ordinal)
            )
        case .desktopLink, .mobileLink:
            return nil
        }
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
