import CryptoKit
import Foundation

public enum RegistrationError: Error, Equatable {
    case manifestUnreadable(path: String, reason: String)
    case manifestHasNoKey(path: String)
    case notExecutable(path: String)
    case writeFailed(path: String, reason: String)
}

/// Lets Chrome start Porter's native-messaging relay for the Porter extension, and tells the relay which extension
/// it may talk to. This is the install script's work, done by the app itself so no script has to be run.
public enum ChromeNativeHostRegistration {
    public static let hostName = "com.porter.bridge"
    private static let idByteCount = 16
    private static let alphabetOffset = UInt8(ascii: "a")

    public struct Result: Equatable, Sendable {
        public let extensionId: String
        public let hostManifestPath: String
        public let allowedOriginsPath: String
    }

    public static var defaultChromeDirectory: String {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Google/Chrome").path
    }

    /// The id Chrome derives from an extension's public key: the first 16 bytes of its SHA-256, each nibble a letter a-p.
    public static func extensionId(manifestKey: String) -> String? {
        guard let der = Data(base64Encoded: manifestKey), !der.isEmpty else { return nil }
        let bytes = Array(SHA256.hash(data: der).prefix(idByteCount))
        let letters = bytes.flatMap { [$0 >> 4, $0 & 0x0f] }.map { Character(UnicodeScalar(alphabetOffset + $0)) }
        return String(letters)
    }

    public static func extensionId(manifestAt path: String) throws(RegistrationError) -> String {
        let key: String?
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            key = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["key"] as? String
        } catch {
            throw .manifestUnreadable(path: path, reason: String(describing: error))
        }
        guard let key, let id = extensionId(manifestKey: key) else { throw .manifestHasNoKey(path: path) }
        return id
    }

    public static func hostManifest(hostPath: String, extensionId: String) throws(RegistrationError) -> Data {
        let manifest: [String: Any] = [
            "name": hostName,
            "description": "Porter bridge between the Chrome connector and the Porter registry",
            "path": hostPath,
            "type": "stdio",
            "allowed_origins": ["chrome-extension://\(extensionId)/"],
        ]
        do {
            return try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        } catch {
            throw .writeFailed(path: hostPath, reason: String(describing: error))
        }
    }

    /// Writes the two files the dev install script writes. Existing ones are replaced, which re-points a development
    /// registration at this app's helper; nothing else in Chrome's folders is touched.
    @discardableResult
    public static func register(
        hostBinary: String, extensionManifest: String,
        chromeDirectory: String = defaultChromeDirectory, supportDirectory: String = PorterPaths.supportDirectory()
    ) throws(RegistrationError) -> Result {
        guard FileManager.default.isExecutableFile(atPath: hostBinary) else { throw .notExecutable(path: hostBinary) }
        let id = try extensionId(manifestAt: extensionManifest)
        let manifestData = try hostManifest(hostPath: hostBinary, extensionId: id)
        let hostsDirectory = chromeDirectory + "/NativeMessagingHosts"
        let manifestPath = hostsDirectory + "/\(hostName).json"
        let originsPath = supportDirectory + "/allowed-origins.txt"
        do {
            try FileManager.default.createDirectory(atPath: hostsDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                atPath: supportDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
            )
            try manifestData.write(to: URL(fileURLWithPath: manifestPath), options: .atomic)
            try Data("chrome-extension://\(id)/\n".utf8).write(to: URL(fileURLWithPath: originsPath), options: .atomic)
        } catch {
            throw .writeFailed(path: manifestPath, reason: String(describing: error))
        }
        return Result(extensionId: id, hostManifestPath: manifestPath, allowedOriginsPath: originsPath)
    }
}
