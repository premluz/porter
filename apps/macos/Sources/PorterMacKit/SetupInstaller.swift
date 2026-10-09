import AppKit
import BridgeTransport
import Foundation

/// Runs a command and returns how it ended. A protocol so the installer can be tested without touching real editors.
public protocol CommandRunning: Sendable {
    func run(_ executable: String, arguments: [String], environment: [String: String]) async -> CommandResult
}

public struct CommandResult: Sendable, Equatable {
    public let status: Int32
    public let output: String
    public var succeeded: Bool { status == 0 }
}

public struct ProcessCommandRunner: CommandRunning {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 60) { self.timeout = timeout }

    public func run(_ executable: String, arguments: [String], environment: [String: String]) async -> CommandResult {
        let limit = timeout
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do { try process.run() } catch {
                    continuation.resume(returning: CommandResult(status: -1, output: "could not start \(executable): \(error)"))
                    return
                }
                let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + limit, execute: watchdog)
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                watchdog.cancel()
                continuation.resume(returning: CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

/// The files the app carries so it can set up the optional pieces itself. Any of them can be absent when the app
/// runs unbundled during development, and then the matching setup action is not offered.
public struct BundledAssets: Sendable, Equatable {
    public var vsix: String?
    public var hookScript: String?
    public var porterctl: String?
    public var nativeHost: String?
    public var chromeExtensionFolder: String?
    /// The extension packed and signed, for Chrome to install by itself after one approval.
    public var chromeExtensionCrx: String?

    public init(
        vsix: String? = nil, hookScript: String? = nil, porterctl: String? = nil, nativeHost: String? = nil,
        chromeExtensionFolder: String? = nil, chromeExtensionCrx: String? = nil
    ) {
        self.chromeExtensionCrx = chromeExtensionCrx
        self.vsix = vsix
        self.hookScript = hookScript
        self.porterctl = porterctl
        self.nativeHost = nativeHost
        self.chromeExtensionFolder = chromeExtensionFolder
    }

    public static func from(_ bundle: Bundle = .main) -> BundledAssets {
        func existing(_ path: String?) -> String? { path.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil } }
        let resources = bundle.resourcePath
        let helpers = bundle.bundlePath + "/Contents/Helpers"
        return BundledAssets(
            vsix: existing(resources.map { $0 + "/porter-vscode.vsix" }),
            hookScript: existing(resources.map { $0 + "/claude-hooks.sh" }),
            porterctl: existing(helpers + "/porterctl"),
            nativeHost: existing(helpers + "/porter-native-host"),
            chromeExtensionFolder: existing(resources.map { $0 + "/ChromeExtension" }),
            chromeExtensionCrx: existing(resources.map { $0 + "/porter-extension.crx" })
        )
    }
}

/// The three setup steps that change something outside Porter. Each is a deliberate user action and says what it did.
public struct SetupInstaller: Sendable {
    let assets: BundledAssets
    let runner: any CommandRunning
    let chromeDirectory: String
    let supportDirectory: String

    public init(
        assets: BundledAssets = .from(), runner: any CommandRunning = ProcessCommandRunner(),
        chromeDirectory: String = ChromeNativeHostRegistration.defaultChromeDirectory, supportDirectory: String = PorterPaths.supportDirectory()
    ) {
        self.assets = assets
        self.runner = runner
        self.chromeDirectory = chromeDirectory
        self.supportDirectory = supportDirectory
    }

    /// Installs the companion in each editor that has a command-line installer; returns one line of outcome.
    public func installEditorCompanions(_ editors: [SetupEnvironment.Editor]) async -> String {
        guard let vsix = assets.vsix else { return "The companion is not bundled with this build." }
        guard !editors.isEmpty else { return "No VS Code-family editor was found." }
        var done: [String] = []
        var failed: [String] = []
        for editor in editors {
            let result = await runner.run(editor.cliPath, arguments: ["--install-extension", vsix, "--force"], environment: [:])
            if result.succeeded { done.append(editor.name) } else { failed.append("\(editor.name): \(result.output.prefix(120))") }
        }
        var parts: [String] = []
        if !done.isEmpty { parts.append("Installed in \(done.joined(separator: ", ")). Reload its window (Developer: Reload Window) to start it.") }
        if !failed.isEmpty { parts.append("Could not install in " + failed.joined(separator: "; ") + ".") }
        return parts.joined(separator: " ")
    }

    /// Adds Porter's hooks to Claude Code's settings through the bundled script, which backs the file up first.
    public func enableClaudeCodeStatus() async -> String {
        guard let script = assets.hookScript, let porterctl = assets.porterctl else { return "The hook installer is not bundled with this build." }
        let result = await runner.run("/bin/bash", arguments: [script, "--apply"], environment: ["PORTERCTL": porterctl])
        return result.succeeded
            ? "Claude Code's settings now include Porter's hooks (a backup was made). Start a new Claude Code session to use them."
            : "Could not change Claude Code's settings; nothing was changed. \(result.output.prefix(200))"
    }

    /// Registers the relay with Chrome and has Chrome install the extension itself when the app carries a signed copy;
    /// otherwise returns the folder to load by hand. Chrome asks the user to enable it in each profile either way.
    public func prepareChromeExtension() -> (message: String, folder: String?) {
        guard let host = assets.nativeHost, let folder = assets.chromeExtensionFolder else {
            return ("The extension is not bundled with this build.", nil)
        }
        do {
            let result = try ChromeNativeHostRegistration.register(
                hostBinary: host, extensionManifest: folder + "/manifest.json",
                chromeDirectory: chromeDirectory, supportDirectory: supportDirectory
            )
            if let crx = assets.chromeExtensionCrx {
                try ChromeNativeHostRegistration.registerExternalExtension(
                    crx: crx, extensionManifest: folder + "/manifest.json", chromeDirectory: chromeDirectory
                )
                return ("Chrome will offer to add the Porter extension the next time it starts (quit and reopen it, then approve it in each profile you want).", nil)
            }
            return ("Registered with Chrome. In each profile: open chrome://extensions, turn on Developer mode, choose Load unpacked, and pick the folder that just opened (extension \(result.extensionId)).", folder)
        } catch {
            return ("Could not register the extension with Chrome: \(error).", nil)
        }
    }
}
