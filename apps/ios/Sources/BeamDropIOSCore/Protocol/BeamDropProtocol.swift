import Foundation

public enum BeamDropProtocol {
    public static let version = "1.0"
    public static let serviceName = "_beamdrop._tcp"
    public static let defaultPort = 49320
    public static let defaultChunkSizeBytes = 4 * 1024 * 1024
    public static let appGroupIdentifier = "group.com.beamdrop.ios"
}

public enum BeamDropPlatform: String, Codable, CaseIterable, Equatable, Sendable {
    case android
    case ios
    case macos
    case windows
    case unknown
}

public enum TrustState: String, Codable, Equatable, Sendable {
    case unknown
    case pairing
    case trusted
    case revoked
}

public enum TransferKind: String, Codable, Equatable, Sendable {
    case text = "TEXT"
    case url = "URL"
    case file = "FILE"
    case clipboardText = "CLIPBOARD_TEXT"
}

public enum TransferStatus: String, Codable, Equatable, Sendable {
    case queued = "Queued"
    case waitingForApproval = "WaitingForApproval"
    case transferring = "Transferring"
    case verifying = "Verifying"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"
    case rejected = "Rejected"
    case corrupted = "Corrupted"
    case incomplete = "Incomplete"
}

public enum TransferDirection: String, Codable, Equatable, Sendable {
    case sent = "Sent"
    case received = "Received"
}

public struct EndpointHint: Codable, Equatable, Hashable, Sendable {
    public var host: String?
    public var port: Int?
    public var route: String

    public init(host: String?, port: Int?, route: String = "local") {
        self.host = host
        self.port = port
        self.route = route
    }

    public var isUsable: Bool {
        guard let host, !host.isEmpty, let port else { return false }
        return (1...65535).contains(port)
    }
}
