import BridgeTransport
import ConversationCore
import Darwin
import Foundation

// porterctl list [--json]
// porterctl activate <destinationId> <revision>

private let usage = "usage: porterctl list [--json] | porterctl activate <destinationId> <revision>"

private func die(_ message: String) -> Never {
    FileHandle.standardError.write(Data("porterctl: \(message)\n".utf8))
    exit(1)
}

private func roundTrip(_ request: ControlRequest) -> ControlResponse {
    do {
        let connection = FramedConnection(fd: try UnixSocket.connect(path: PorterPaths.controlSocket()))
        defer { connection.closeDescriptor() }
        try connection.send(try JSONEncoder().encode(request))
        guard let reply = try connection.receive(maximumBytes: ControlLimits.maximumResponseBytes) else {
            die("registry closed the connection without a reply")
        }
        return try JSONDecoder().decode(ControlResponse.self, from: reply)
    } catch {
        die("cannot reach the registry: \(error)")
    }
}

/// Browser rows have a tab and window; editor rows have neither, so say nothing rather than -1.
private func position(of row: DestinationRow) -> String {
    guard let tab = row.tabId, let window = row.windowId else { return "" }
    return "tab \(tab) window \(window)  "
}

private func printListing(_ response: ControlResponse, json: Bool) {
    if json {
        let data = (try? JSONEncoder().encode(response)) ?? Data()
        print(String(decoding: data, as: UTF8.self))
        return
    }
    for connector in response.connectors ?? [] {
        print("connector \(connector.profileAlias ?? "(no alias)")  \(connector.reachability.rawValue)  \(connector.routeCount) route(s)  \(connector.connectorId)")
    }
    for row in response.rows ?? [] {
        let ambiguity = row.routeCount > 1 ? "  AMBIGUOUS x\(row.routeCount)" : ""
        print("\(row.destinationId) r\(row.revision)  [\(row.profileAlias ?? "?")] \(row.title)  \(position(of: row))\(row.reachability.rawValue)\(ambiguity)")
    }
    if (response.rows ?? []).isEmpty { print("no destinations") }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "list":
    let response = roundTrip(ControlRequest(command: .list))
    guard response.ok else { die(response.error ?? "list failed") }
    printListing(response, json: arguments.contains("--json"))
case "activate":
    guard arguments.count == 3, let id = UUID(uuidString: arguments[1]), let revision = Int(arguments[2]) else { die(usage) }
    let response = roundTrip(ControlRequest(command: .activate, destinationId: id, revision: revision))
    guard response.ok, let outcome = response.outcome else { die(response.error ?? "activate failed") }
    print("outcome: \(outcome.rawValue)  app: \(response.appActivation ?? "n/a")")
    exit(outcome == .activated ? 0 : 3)
default:
    die(usage)
}
