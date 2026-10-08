import Foundation

extension BridgeCoordinator {
    mutating func acceptHello(
        _ header: EnvelopeHeader, _ hello: HelloPayload, from connection: ConnectionID, now: Date
    ) -> BridgeResult {
        guard bindings[connection] == nil else {
            return violation(connection, .outOfOrder, "second hello on one connection", close: true)
        }
        guard header.sequence == 0 else {
            return violation(connection, .outOfOrder, "hello must open the sequence at 0", close: true)
        }
        let kind = hello.kind
        let connectorId = Self.connectorId(for: hello.installationId, kind: kind)
        guard header.connectorId == connectorId else {
            return violation(connection, .unauthorized, "connectorId does not match installationId", close: true)
        }
        guard connectionByInstallation[hello.installationId] == nil else {
            // Neither claimant can be told apart, so the live one is kept and the newcomer refused.
            return violation(connection, .duplicateInstallation, "installation already connected", close: true)
        }
        retireDestinations(ofConnector: connectorId)
        bindings[connection] = Binding(
            connectorId: connectorId, kind: kind, installationId: hello.installationId, epoch: header.connectionEpoch
        )
        connectionByInstallation[hello.installationId] = connection
        sequencer.begin(connectorId: connectorId, epoch: header.connectionEpoch)
        _ = sequencer.admit(connectorId: connectorId, epoch: header.connectionEpoch, sequence: header.sequence)
        connectors[connectorId] = Connector(
            id: connectorId, deviceId: deviceId, providerType: kind.connectorType, profileAlias: hello.profileAlias,
            installationId: hello.installationId, connectionEpoch: header.connectionEpoch,
            protocolVersion: header.protocolVersion, adapterVersions: hello.adapterVersions,
            connectedAt: now, lastHeartbeatAt: now
        )
        var result = send(.helloAck, HelloAckPayload(accepted: true, connectorId: connectorId), to: connection)
        result.events.append(.connectorConnected(connectorId: connectorId))
        return result
    }

    /// Tab IDs do not survive a browser restart, so a new epoch never inherits old destinations.
    mutating func retireDestinations(ofConnector connectorId: String) {
        for destinationId in (tabDestinations[connectorId] ?? [:]).values {
            registry.remove(destinationId)
        }
        tabDestinations[connectorId] = nil
        for destinationId in (editorDestinations[connectorId] ?? [:]).values { registry.remove(destinationId) }
        editorDestinations[connectorId] = nil
        remembered = remembered.filter { $0.key.connectorId != connectorId }
    }

    mutating func recordHeartbeat(_ binding: Binding, now: Date) -> BridgeResult {
        guard let current = connectors[binding.connectorId] else { return BridgeResult() }
        connectors[binding.connectorId] = Connector(
            id: current.id, deviceId: current.deviceId, providerType: current.providerType,
            profileAlias: current.profileAlias, installationId: current.installationId,
            connectionEpoch: current.connectionEpoch, protocolVersion: current.protocolVersion,
            adapterVersions: current.adapterVersions, connectedAt: current.connectedAt, lastHeartbeatAt: now
        )
        return BridgeResult()
    }
}
