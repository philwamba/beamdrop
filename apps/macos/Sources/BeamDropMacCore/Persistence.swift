import Foundation

public enum TrustedPeerStatus: String, Codable, Sendable {
    case trusted
    case revoked
}

public struct TrustedPeer: Codable, Equatable, Identifiable, Sendable {
    public var id: String { deviceId }
    public var deviceId: String
    public var deviceName: String
    public var platform: BeamDropPlatform
    public var publicKey: String
    public var fingerprint: String?
    public var endpointHost: String?
    public var endpointPort: Int?
    public var autoAcceptTransfers: Bool
    public var status: TrustedPeerStatus
    public var pairedAt: Date
    public var revokedAt: Date?

    public init(
        deviceId: String,
        deviceName: String,
        platform: BeamDropPlatform,
        publicKey: String,
        fingerprint: String?,
        endpointHost: String?,
        endpointPort: Int?,
        autoAcceptTransfers: Bool = false,
        status: TrustedPeerStatus = .trusted,
        pairedAt: Date = Date(),
        revokedAt: Date? = nil
    ) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.fingerprint = fingerprint
        self.endpointHost = endpointHost
        self.endpointPort = endpointPort
        self.autoAcceptTransfers = autoAcceptTransfers
        self.status = status
        self.pairedAt = pairedAt
        self.revokedAt = revokedAt
    }
}

public struct TransferRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { transferId }
    public var transferId: String
    public var direction: TransferDirection
    public var peerDeviceId: String
    public var peerDeviceName: String
    public var fileName: String
    public var transferType: TransferType
    public var sizeBytes: Int64
    public var status: TransferStatus
    public var errorMessage: String?
    public var createdAt: Date
    public var completedAt: Date?

    public init(
        transferId: String,
        direction: TransferDirection,
        peerDeviceId: String,
        peerDeviceName: String,
        fileName: String,
        transferType: TransferType,
        sizeBytes: Int64,
        status: TransferStatus,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.transferId = transferId
        self.direction = direction
        self.peerDeviceId = peerDeviceId
        self.peerDeviceName = peerDeviceName
        self.fileName = fileName
        self.transferType = transferType
        self.sizeBytes = sizeBytes
        self.status = status
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public enum TransferDirection: String, Codable, Sendable {
    case sent
    case received
}

public struct AuditEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var type: String
    public var message: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, type: String, message: String, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.message = message
        self.createdAt = createdAt
    }
}

public final class TrustedPeerStore {
    private let url: URL
    private let lock = NSLock()
    private var peers: [TrustedPeer]

    public init(url: URL = AppStoragePaths.trustedPeersURL) {
        self.url = url
        self.peers = (try? JSONFile.read([TrustedPeer].self, from: url)) ?? []
    }

    public func all() -> [TrustedPeer] {
        lock.withLock { peers.sorted { $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending } }
    }

    public func get(deviceId: String) -> TrustedPeer? {
        lock.withLock { peers.first { $0.deviceId == deviceId } }
    }

    public func approve(_ payload: PairingPayload, autoAcceptTransfers: Bool = false) throws -> TrustedPeer {
        try PairingValidator.validate(payload)
        let peer = TrustedPeer(
            deviceId: payload.deviceId,
            deviceName: payload.deviceName,
            platform: payload.platform,
            publicKey: payload.publicKey,
            fingerprint: payload.fingerprint,
            endpointHost: payload.endpoint?.host,
            endpointPort: payload.endpoint?.port,
            autoAcceptTransfers: autoAcceptTransfers
        )
        try lock.withLock {
            peers.removeAll { $0.deviceId == peer.deviceId }
            peers.append(peer)
            try JSONFile.write(peers, to: url)
        }
        return peer
    }

    public func revoke(deviceId: String) throws {
        try lock.withLock {
            guard let index = peers.firstIndex(where: { $0.deviceId == deviceId }) else { return }
            peers[index].status = .revoked
            peers[index].autoAcceptTransfers = false
            peers[index].revokedAt = Date()
            try JSONFile.write(peers, to: url)
        }
    }
}

public final class TransferHistoryStore {
    private let url: URL
    private let lock = NSLock()
    private var records: [TransferRecord]

    public init(url: URL = AppStoragePaths.transferHistoryURL) {
        self.url = url
        self.records = (try? JSONFile.read([TransferRecord].self, from: url)) ?? []
    }

    public func all() -> [TransferRecord] {
        lock.withLock { records.sorted { $0.createdAt > $1.createdAt } }
    }

    public func upsert(_ record: TransferRecord) throws {
        try lock.withLock {
            records.removeAll { $0.transferId == record.transferId }
            records.append(record)
            try JSONFile.write(records, to: url)
        }
    }
}

public final class AuditLog {
    private let url: URL
    private let lock = NSLock()
    private var events: [AuditEvent]

    public init(url: URL = AppStoragePaths.auditLogURL) {
        self.url = url
        self.events = (try? JSONFile.read([AuditEvent].self, from: url)) ?? []
    }

    public func record(type: String, message: String) throws {
        try lock.withLock {
            events.append(AuditEvent(type: type, message: message))
            try JSONFile.write(events, to: url)
        }
    }
}

public enum PeerTrustPolicy {
    public static func requireTrusted(deviceId: String, store: TrustedPeerStore) throws -> TrustedPeer {
        guard let peer = store.get(deviceId: deviceId) else {
            throw BeamDropError.unknownPeer(deviceId)
        }
        guard peer.status != .revoked else {
            throw BeamDropError.revokedPeer(deviceId)
        }
        return peer
    }
}

public enum AppStoragePaths {
    public static var baseDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return root.appendingPathComponent("BeamDrop", isDirectory: true)
    }

    public static var trustedPeersURL: URL { baseDirectory.appendingPathComponent("trusted-peers.json") }
    public static var transferHistoryURL: URL { baseDirectory.appendingPathComponent("transfer-history.json") }
    public static var auditLogURL: URL { baseDirectory.appendingPathComponent("audit-log.json") }
}

enum JSONFile {
    static func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try BeamDropJSON.decoder.decode(type, from: data)
    }

    static func write<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try BeamDropJSON.encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
