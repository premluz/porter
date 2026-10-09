import Foundation
import Testing
@testable import BridgeTransport

@Suite("Registering the native host with Chrome from the app")
struct ChromeRegistrationTests {
    private let repository = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    private func scratch() throws -> String {
        let directory = NSTemporaryDirectory() + "porter-reg-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("the id derived from the shipped manifest key equals the one the extension's own script prints")
    func derivedId() throws {
        let manifest = repository.appending(path: "extensions/chrome/manifest.json").path
        #expect(try ChromeNativeHostRegistration.extensionId(manifestAt: manifest) == "eilmjgagnblkgijjdedkmdnjogggdeij")
    }

    @Test("a missing or key-less manifest is an error with its path, never a made-up id")
    func badManifests() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        #expect(throws: RegistrationError.manifestHasNoKey(path: directory + "/none.json")) {
            try Data(#"{"name":"x"}"#.utf8).write(to: URL(fileURLWithPath: directory + "/none.json"))
            _ = try ChromeNativeHostRegistration.extensionId(manifestAt: directory + "/none.json")
        }
        #expect(ChromeNativeHostRegistration.extensionId(manifestKey: "not base64 !!") == nil)
        #expect(ChromeNativeHostRegistration.extensionId(manifestKey: "") == nil)
    }

    @Test("registration writes the host manifest and the allowed origin, and replaces an older one")
    func registers() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let host = directory + "/porter-native-host"
        try Data("#!/bin/sh\n".utf8).write(to: URL(fileURLWithPath: host))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: host)
        let manifest = repository.appending(path: "extensions/chrome/manifest.json").path
        let chrome = directory + "/Chrome", support = directory + "/Support"
        try FileManager.default.createDirectory(atPath: chrome + "/NativeMessagingHosts", withIntermediateDirectories: true)
        try Data("old".utf8).write(to: URL(fileURLWithPath: chrome + "/NativeMessagingHosts/com.porter.bridge.json"))
        try Data("other host".utf8).write(to: URL(fileURLWithPath: chrome + "/NativeMessagingHosts/com.example.other.json"))

        let result = try ChromeNativeHostRegistration.register(hostBinary: host, extensionManifest: manifest, chromeDirectory: chrome, supportDirectory: support)
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: result.hostManifestPath))) as? [String: Any])
        #expect(json["path"] as? String == host && json["name"] as? String == "com.porter.bridge" && json["type"] as? String == "stdio")
        #expect(json["allowed_origins"] as? [String] == ["chrome-extension://eilmjgagnblkgijjdedkmdnjogggdeij/"])
        #expect(try String(contentsOfFile: result.allowedOriginsPath, encoding: .utf8) == "chrome-extension://eilmjgagnblkgijjdedkmdnjogggdeij/\n")
        #expect(try String(contentsOfFile: chrome + "/NativeMessagingHosts/com.example.other.json", encoding: .utf8) == "other host")
        let mode = try FileManager.default.attributesOfItem(atPath: support)[.posixPermissions] as? Int
        #expect(mode == 0o700)
    }

    @Test("a helper that is not an executable file is refused before anything is written")
    func refusesMissingHelper() throws {
        let directory = try scratch()
        defer { try? FileManager.default.removeItem(atPath: directory) }
        let manifest = repository.appending(path: "extensions/chrome/manifest.json").path
        #expect(throws: RegistrationError.notExecutable(path: directory + "/nope")) {
            try ChromeNativeHostRegistration.register(hostBinary: directory + "/nope", extensionManifest: manifest, chromeDirectory: directory + "/C", supportDirectory: directory + "/S")
        }
        #expect(!FileManager.default.fileExists(atPath: directory + "/C"))
    }
}
