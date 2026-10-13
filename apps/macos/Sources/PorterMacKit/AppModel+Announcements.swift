import Foundation
import PorterPanelModel

extension AppModel {
    func observeCompletions() {
        let now = clock()
        let events = completionDetector.update(items: observedItems, now: now)
        if let latest = events.max(by: { $0.end.at < $1.end.at }) { lastCompletion = latest }
        publish(completionCoalescer.append(events, now: now))
        scheduleCompletionFlush()
    }

    func flushCompletions() {
        publish(completionCoalescer.flush(now: clock()))
        scheduleCompletionFlush()
    }

    private func publish(_ batches: [CompletionBatch]) {
        for batch in batches {
            if batch.kind == .completed, voiceSettings?.completedNotices == true { completionAnnouncer?.announce(batch) }
            speechAnnouncer?.announce(batch)
        }
    }

    private func scheduleCompletionFlush() {
        completionTimer?.cancel()
        guard let deadline = completionCoalescer.nextFlushAt else { completionTimer = nil; return }
        let delay = max(0, deadline.timeIntervalSince(clock()))
        completionTimer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) }
            catch is CancellationError { return }
            catch { self?.reportProblem("Could not schedule completion notice: \(error)"); return }
            self?.flushCompletions()
        }
    }

    public func openCompletion(ids: [String]) async {
        query = ""
        let matches = observedItems.filter { ids.contains($0.id) }
        guard let item = matches.first else { reportProblem("That completed chat is no longer available."); return }
        select(item)
        if ids.count == 1 { await activateSelected() }
    }
}
