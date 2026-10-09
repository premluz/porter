import ConversationCore
import Darwin
import Foundation

public enum LocalConnectorError: Error {
    case socketPairFailed(errno: Int32)
}

extension RegistryService {
    /// Joins an in-app connector to the registry. It appears and behaves exactly like a connector that
    /// reached the bridge socket from another process.
    public func attach(_ connector: any HostConnector) throws(LocalConnectorError) -> LocalConnectorSession {
        var descriptors: [Int32] = [0, 0]
        guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else { throw .socketPairFailed(errno: errno) }
        let session = LocalConnectorSession(connector: connector, connection: FramedConnection(fd: descriptors[1]), log: log)
        let registryEnd = FramedConnection(fd: descriptors[0])
        spawn("local-conn") { [self] in serveBridge(registryEnd) }
        session.start()
        return session
    }
}
