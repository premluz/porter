import Foundation
import PorterPanelModel

@MainActor final class VoiceRouter {
    private let model: AppModel
    private let controller: PanelController
    private let speech: SpeechAnnouncer

    init(model: AppModel, controller: PanelController, speech: SpeechAnnouncer) {
        self.model = model
        self.controller = controller
        self.speech = speech
    }

    func handle(_ transcript: String) async {
        guard let command = CommandParser.parse(transcript) else {
            speech.respond("I did not catch a command")
            return
        }
        switch command {
        case .showLastTask:
            guard let last = model.lastCompletion else { speech.respond("There is no recently completed task"); return }
            controller.open()
            await model.openCompletion(ids: [last.id])
        case .show(let query):
            await show(query)
        case .showNeedsYou:
            model.query = ""
            controller.open()
            if let first = model.snapshot.needsYou.first { model.select(first) }
        case .describeWorking:
            let count = model.observedItems.filter { $0.status.freshness == .fresh && $0.status.display == .working }.count
            speech.respond(count == 1 ? "One task is working" : "\(count) tasks are working")
        case .cancel:
            speech.cancel()
        case .dictate:
            speech.respond("Replying by voice is not available yet")
        }
    }

    private func show(_ query: String) async {
        switch VoiceCommandMatcher.match(query: query, in: model.observedItems) {
        case .single(let item):
            model.query = ""
            controller.open()
            model.select(item)
            await model.activateSelected()
        case .multiple(let query, let items):
            model.query = query
            controller.open()
            speech.respond("\(items.count) matches")
        case .none:
            speech.respond("No matching task")
        }
    }
}
