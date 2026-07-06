import Foundation

public enum TransferServiceError: Error, Equatable, LocalizedError {
    case unknownPeer(String)
    case revokedPeer(String)
    case publicKeyMismatch(String)
    case receiverRejected
    case hashVerificationFailed
    case incompleteTransfer(expected: Int64, actual: Int64)
    case cancelled
    case missingEndpoint

    public var errorDescription: String? {
        switch self {
        case .unknownPeer(let id): "Unknown peer rejected: \(id)."
        case .revokedPeer(let id): "Revoked peer rejected: \(id)."
        case .publicKeyMismatch(let id): "Peer public key did not match trusted record: \(id)."
        case .receiverRejected: "Receiver rejected transfer."
        case .hashVerificationFailed: "Final SHA-256 verification failed."
        case .incompleteTransfer(let expected, let actual): "Transfer incomplete. Expected \(expected) bytes but received \(actual)."
        case .cancelled: "Transfer cancelled."
        case .missingEndpoint: "Trusted peer has no usable local endpoint."
        }
    }
}

public struct TransferService {
    public var trustedPeers: TrustedPeerRepository
    public var history: TransferHistoryRepository

    public init(trustedPeers: TrustedPeerRepository, history: TransferHistoryRepository) {
        self.trustedPeers = trustedPeers
        self.history = history
    }

    public func requireTrusted(deviceId: String, publicKey: String) throws -> TrustedPeer {
        guard let peer = trustedPeers.peer(deviceId: deviceId) else {
            throw TransferServiceError.unknownPeer(deviceId)
        }
        switch peer.trustState {
        case .trusted:
            guard peer.publicKey == publicKey else { throw TransferServiceError.publicKeyMismatch(deviceId) }
            return peer
        case .revoked:
            throw TransferServiceError.revokedPeer(deviceId)
        case .unknown, .pairing:
            throw TransferServiceError.unknownPeer(deviceId)
        }
    }

    public func verifyReceivedPayload(envelope: TransferEnvelope, payload: Data, from peer: TrustedPeer) throws -> TransferHistoryRecord {
        try TransferEnvelopeCodec.validate(envelope)
        guard peer.canTransfer(publicKey: envelope.senderPublicKey) else {
            throw peer.trustState == .revoked ? TransferServiceError.revokedPeer(peer.deviceId) : TransferServiceError.unknownPeer(peer.deviceId)
        }
        guard Int64(payload.count) == envelope.payloadMetadata.sizeBytes else {
            throw TransferServiceError.incompleteTransfer(expected: envelope.payloadMetadata.sizeBytes, actual: Int64(payload.count))
        }
        guard Fingerprint.sha256Hex(data: payload) == envelope.payloadMetadata.sha256 else {
            throw TransferServiceError.hashVerificationFailed
        }
        return TransferHistoryRecord(
            transferId: envelope.transferId,
            direction: .received,
            peerDeviceId: peer.deviceId,
            peerDeviceName: peer.deviceName,
            kind: envelope.transferType,
            fileName: envelope.payloadMetadata.fileName,
            sizeBytes: envelope.payloadMetadata.sizeBytes,
            status: .completed,
            sha256: envelope.payloadMetadata.sha256,
            errorMessage: nil,
            createdAt: envelope.createdAt,
            completedAt: Date()
        )
    }

    public func persistFailure(envelope: TransferEnvelope, peer: TrustedPeer, status: TransferStatus, error: Error) throws -> TransferHistoryRecord {
        let record = TransferHistoryRecord(
            transferId: envelope.transferId,
            direction: .received,
            peerDeviceId: peer.deviceId,
            peerDeviceName: peer.deviceName,
            kind: envelope.transferType,
            fileName: envelope.payloadMetadata.fileName,
            sizeBytes: envelope.payloadMetadata.sizeBytes,
            status: status,
            sha256: envelope.payloadMetadata.sha256,
            errorMessage: error.localizedDescription,
            createdAt: envelope.createdAt,
            completedAt: Date()
        )
        try history.upsert(record)
        return record
    }
}
