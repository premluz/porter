import Foundation

extension BridgeCoordinator {
    /// A report that a turn is in progress is trusted for this long without another. Connectors repeat it more often
    /// than this while it is true, so a connector that stops reporting (it died, or lost its source) stops claiming
    /// work within one lifetime rather than showing a chat as working for good.
    static let appWorkingLifetime: TimeInterval = 45
    static let appConnectionEpoch = "app-activity"

    /// Records or withdraws the claim for a route, and says whether what is visible changed. A repeated claim
    /// refreshes its time and changes nothing visible.
    mutating func setWorking(_ destinationId: UUID, _ working: Bool?, now: Date) -> Bool {
        if working == true {
            return appWorking.updateValue(now, forKey: destinationId) == nil
        }
        return appWorking.removeValue(forKey: destinationId) != nil
    }

    mutating func setTurnEnd(_ destinationId: UUID, entry: AppEntryReport) -> Bool {
        guard let at = entry.lastTurnEndedAt, let kind = entry.lastTurnEndKind else { return false }
        if let previous = appTurnEnds[destinationId], previous.at >= at { return false }
        appTurnEnds[destinationId] = TurnEnd(at: at, kind: kind)
        return true
    }

    /// Activity from positive turn evidence only. Withdrawal alone never supplies idle or an end marker.
    public func appStatuses(now: Date) -> [UUID: DestinationStatus] {
        var projection = StatusProjection(policy: FreshnessPolicy(maximumLifetime: Self.appWorkingLifetime))
        var reachability: [UUID: Reachability] = [:]
        for id in Set(appWorking.keys).union(appTurnEnds.keys) {
            guard let destination = registry.destination(id), let connectorId = destination.connectorId,
                  let connector = connectors[connectorId] else { continue }
            if let reportedAt = appWorking[id] ?? appTurnEnds[id]?.at { projection.record(StatusObservation(
                id: UUID(), destinationId: id, activity: appWorking[id] == nil ? .idle : .working, attention: .none, evidenceKind: .providerEvent,
                observedAt: reportedAt, receivedAt: reportedAt, expiresAt: reportedAt.addingTimeInterval(Self.appWorkingLifetime),
                sequence: 1, connectionEpoch: Self.appConnectionEpoch, adapterVersion: Self.agentAdapterVersion
            )) }
            reachability[id] = connectionByInstallation[connector.installationId] != nil ? .connected : .disconnected
        }
        return Dictionary(uniqueKeysWithValues: reachability.map { id, reach in
            (id, projection.status(for: id, reachability: reach, now: now).withTurnEnd(appTurnEnds[id]))
        })
    }
}
