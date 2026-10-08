import Foundation

/// JSON coding shared by every contract type, so RFC 3339 timestamps with or
/// without fractional seconds decode identically on every platform.
public enum ContractCoding {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(decodeTimestamp)
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    @Sendable
    private static func decodeTimestamp(_ decoder: any Decoder) throws -> Date {
        let text = try decoder.singleValueContainer().decode(String.self)
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        if let date = try? fractional.parse(text) { return date }
        do {
            return try Date.ISO8601FormatStyle().parse(text)
        } catch {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "Expected an RFC 3339 timestamp, got \(text)",
                underlyingError: error
            ))
        }
    }
}
