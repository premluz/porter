import Foundation
import Testing
@testable import ConversationCore

@Suite("Status freshness and precedence")
struct StatusTests {
    private let id = UUID()

    private func status(_ projection: StatusProjection, reach: Reachability = .connected, at offset: TimeInterval)
        -> DestinationStatus {
        projection.status(for: id, reachability: reach, now: Sample.start.addingTimeInterval(offset))
    }

    @Test("no observation is unknown, not idle")
    func noObservationIsUnknown() {
        let result = status(StatusProjection(), at: 0)
        #expect(result.display == .unknown)
        #expect(result.freshness == .unknown)
    }

    @Test("a working observation goes stale and stops claiming activity")
    func staleWorkingIsNotWorking() {
        var projection = StatusProjection()
        projection.record(Sample.observation(destinationId: id, activity: .working, lifetime: 15))
        #expect(status(projection, at: 10).display == .working)
        let later = status(projection, at: 16)
        #expect(later.display == .unknown)
        #expect(later.freshness == .stale)
        #expect(later.lastKnown?.activity == .working)
    }

    @Test("a page clock far ahead cannot extend freshness past the cap")
    func pageClockCannotExtendFreshness() {
        var projection = StatusProjection()
        let skewed = Sample.observation(destinationId: id, lifetime: 3_600, pageClockOffset: 86_400)
        projection.record(skewed)
        #expect(status(projection, at: FreshnessPolicy.defaultMaximumLifetime).freshness == .stale)
    }

    @Test("a disconnected connector makes fresh evidence stale")
    func disconnectedIsStale() {
        var projection = StatusProjection()
        projection.record(Sample.observation(destinationId: id))
        let result = status(projection, reach: .disconnected, at: 1)
        #expect(result.display == .unknown)
        #expect(result.freshness == .stale)
    }

    @Test("evidence kind none never yields a status claim")
    func noEvidenceIsUnknown() {
        var projection = StatusProjection()
        projection.record(Sample.observation(destinationId: id, activity: .idle, evidence: .none))
        #expect(status(projection, at: 1).display == .unknown)
    }

    @Test("needsUser outranks working on the same observation")
    func needsUserPrecedence() {
        var projection = StatusProjection()
        projection.record(Sample.observation(destinationId: id, activity: .working, attention: .needsUser))
        #expect(status(projection, at: 1).display == .needsUser)
    }

    @Test("a late older observation does not overwrite a newer one")
    func lateOlderObservationIgnored() {
        var projection = StatusProjection()
        projection.record(Sample.observation(destinationId: id, activity: .idle, sequence: 5))
        let accepted = projection.record(Sample.observation(destinationId: id, activity: .working, sequence: 4))
        #expect(!accepted)
        #expect(status(projection, at: 1).display == .idle)
    }

    @Test("after a gap status is uncertain until a snapshot reconciles it")
    func gapSuppressesUntilSnapshot() {
        var projection = StatusProjection()
        projection.record(Sample.observation(destinationId: id, activity: .working))
        projection.markUncertain([id])
        #expect(status(projection, at: 1).freshness == .unknown)
        projection.applySnapshot([Sample.observation(destinationId: id, activity: .idle, sequence: 9)], covering: [id])
        #expect(status(projection, at: 1).display == .idle)
    }

    @Test("conflicting routes: only fresh ones vote, highest precedence wins")
    func conflictingRoutes() {
        let fresh = DestinationStatus(display: .idle, freshness: .fresh, reachability: .connected, lastKnown: nil)
        let stale = DestinationStatus(display: .needsUser, freshness: .stale, reachability: .connected, lastKnown: nil)
        let working = DestinationStatus(display: .working, freshness: .fresh, reachability: .connected, lastKnown: nil)
        #expect(StatusProjection.conversationDisplay([fresh, stale]) == .idle)
        #expect(StatusProjection.conversationDisplay([fresh, working]) == .working)
        #expect(StatusProjection.conversationDisplay([stale]) == .unknown)
    }
}
