import Foundation

public struct TrustedPeer: Codable, Equatable, Identifiable, Sendable {
    public var id: String { deviceId }
    public var deviceId: String
    public var deviceName: String
    public var platform: BeamDropPlatform
    public var publicKey: String
    public var fingerprint: String
    public var trustState: TrustState
    public var endpoint: EndpointHint?
    public var autoAcceptTransfers: Bool
    public var trustedAt: Date?
    public var revokedAt: Date?
    public var lastSeenAt: Date?

    public init(deviceId: String, deviceName: String, platform: BeamDropPlatform, publicKey: String, fingerprint: String, trustState: TrustState, endpoint: EndpointHint?, autoAcceptTransfers: Bool = false, trustedAt: Date?, revokedAt: Date?, lastSeenAt: Date?) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.fingerprint = fingerprint
        self.trustState = trustState
        self.endpoint = endpoint
        self.autoAcceptTransfers = autoAcceptTransfers
        self.trustedAt = trustedAt
        self.revokedAt = revokedAt
        self.lastSeenAt = lastSeenAt
    }

    public func canTransfer(publicKey: String) -> Bool {
        trustState == .trusted && self.publicKey == publicKey
    }
}

public protocol TrustedPeerStoring {
    func loadPeers() throws -> [TrustedPeer]
    func savePeers(_ peers: [TrustedPeer]) throws
}

public final class JSONTrustedPeerStore: TrustedPeerStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadPeers() throws -> [TrustedPeer] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([TrustedPeer].self, from: Data(contentsOf: fileURL))
    }

    public func savePeers(_ peers: [TrustedPeer]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(peers).write(to: fileURL, options: [.atomic])
    }
}

public final class InMemoryTrustedPeerStore: TrustedPeerStoring {
    public var peers: [TrustedPeer]

    public init(peers: [TrustedPeer] = []) {
        self.peers = peers
    }

    public func loadPeers() throws -> [TrustedPeer] { peers }
    public func savePeers(_ peers: [TrustedPeer]) throws { self.peers = peers }
}

public final class TrustedPeerRepository {
    private let store: TrustedPeerStoring
    private var peers: [TrustedPeer]

    public init(store: TrustedPeerStoring) throws {
        self.store = store
        self.peers = try store.loadPeers()
    }

    public func list() -> [TrustedPeer] {
        peers.sorted { $0.deviceName.localizedCaseInsensitiveCompare($1.deviceName) == .orderedAscending }
    }

    public func peer(deviceId: String) -> TrustedPeer? {
        peers.first { $0.deviceId == deviceId }
    }

    public func trustState(deviceId: String, publicKey: String) -> TrustState {
        guard let peer = peer(deviceId: deviceId), peer.publicKey == publicKey else { return .unknown }
        return peer.trustState
    }

    @discardableResult
    public func approve(_ request: PairingRequest, allowRepairOfRevokedPeer: Bool = false, now: Date = Date()) throws -> TrustedPeer {
        if let existing = peer(deviceId: request.remoteIdentity.deviceId) {
            if existing.trustState == .trusted, existing.publicKey == request.remoteIdentity.publicKey {
                throw PairingError.alreadyTrusted
            }
            if existing.trustState == .revoked, !allowRepairOfRevokedPeer {
                throw PairingError.previouslyRevoked
            }
        }

        let peer = TrustedPeer(
            deviceId: request.remoteIdentity.deviceId,
            deviceName: request.remoteIdentity.deviceName,
            platform: request.remoteIdentity.platform,
            publicKey: request.remoteIdentity.publicKey,
            fingerprint: request.fingerprint,
            trustState: .trusted,
            endpoint: request.endpoint,
            trustedAt: now,
            revokedAt: nil,
            lastSeenAt: request.receivedAt
        )
        peers.removeAll { $0.deviceId == peer.deviceId }
        peers.append(peer)
        try store.savePeers(peers)
        return peer
    }

    public func revoke(deviceId: String, now: Date = Date()) throws {
        guard let index = peers.firstIndex(where: { $0.deviceId == deviceId }) else { return }
        peers[index].trustState = .revoked
        peers[index].revokedAt = now
        try store.savePeers(peers)
    }
}
