import AppKit
import SwiftUI
import Testing
@testable import PorterMacKit

@MainActor
@Suite("Voice controls and speaking face render artifacts")
struct VoiceRenderTests {
    private static let scale: CGFloat = 2

    private func png<Content: View>(_ view: Content) throws -> Data {
        let renderer = ImageRenderer(content: view)
        renderer.scale = Self.scale
        let tiff = try #require(renderer.nsImage?.tiffRepresentation)
        let image = try #require(NSBitmapImageRep(data: tiff))
        return try #require(image.representation(using: .png, properties: [:]))
    }

    @Test func renderScopedArtifacts() throws {
        let package = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let directory = package.appendingPathComponent(".build/voice-preview/\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let domain = "porter.voice-render.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let model = SetupModel(performer: RecordingPerformer(), voiceSettings: VoiceSettings(defaults: defaults)) {
            SetupInputs(chrome: .ready, notifications: .notAsked)
        }
        let settings = try png(VoiceSettingsView(model: model).padding(Tokens.Space.xl).frame(width: Tokens.Size.setupWidth))
        let quiet = try png(MascotView(tone: .quiet, opensFrom: .right))
        let speaking = try png(MascotView(tone: .quiet, opensFrom: .right, speaking: true))
        #expect(quiet != speaking, "Speaking adds a visible mouth to the same face")
        try settings.write(to: directory.appendingPathComponent("settings.png"))
        try speaking.write(to: directory.appendingPathComponent("speaking.png"))
        print("Voice render artifacts: \(directory.path)")
    }
}
