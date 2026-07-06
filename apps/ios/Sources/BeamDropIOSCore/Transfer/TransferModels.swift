import Foundation

public struct TransferPayloadMetadata: Codable, Equatable, Sendable {
    public var fileName: String
    public var mimeType: String
    public var sizeBytes: Int64
    public var chunkSize: Int
    public var totalChunks: Int64
    public var sha256: String

    public init(fileName: String, mimeType: String, sizeBytes: Int64, chunkSize: Int = BeamDropProtocol.defaultChunkSizeBytes, totalChunks: Int64? = nil, sha256: String) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.chunkSize = chunkSize
        self.totalChunks = totalChunks ?? ChunkPlanner.totalChunks(sizeBytes: sizeBytes, chunkSize: chunkSize)
        self.sha256 = sha256
    }
}

public struct TransferEnvelope: Codable, Equatable, Sendable {
    public var protocolVersion: String
    public var transferId: String
    public var transferType: TransferKind
    public var senderDeviceId: String
    public var senderPublicKey: String
    public var receiverDeviceId: String
    public var createdAt: Date
    public var payloadMetadata: TransferPayloadMetadata

    public init(protocolVersion: String = BeamDropProtocol.version, transferId: String, transferType: TransferKind, senderDeviceId: String, senderPublicKey: String, receiverDeviceId: String, createdAt: Date = Date(), payloadMetadata: TransferPayloadMetadata) {
        self.protocolVersion = protocolVersion
        self.transferId = transferId
        self.transferType = transferType
        self.senderDeviceId = senderDeviceId
        self.senderPublicKey = senderPublicKey
        self.receiverDeviceId = receiverDeviceId
        self.createdAt = createdAt
        self.payloadMetadata = payloadMetadata
    }
}

public enum TransferEnvelopeError: Error, Equatable, LocalizedError {
    case unsupportedProtocol
    case invalidChunkSize
    case invalidSize
    case invalidChunkMetadata
    case missingHash
    case invalidFileName

    public var errorDescription: String? {
        switch self {
        case .unsupportedProtocol: "Unsupported BeamDrop protocol version."
        case .invalidChunkSize: "Transfer chunk size is invalid."
        case .invalidSize: "Transfer size must not be negative."
        case .invalidChunkMetadata: "Transfer chunk metadata does not match payload size."
        case .missingHash: "Transfer is missing final SHA-256."
        case .invalidFileName: "File name must not contain path separators or traversal segments."
        }
    }
}

public enum TransferEnvelopeCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    public static func encode(_ envelope: TransferEnvelope) throws -> Data {
        try validate(envelope)
        return try encoder.encode(envelope)
    }

    public static func encodeLine(_ envelope: TransferEnvelope) throws -> Data {
        var data = try encode(envelope)
        data.append(0x0A)
        return data
    }

    public static func decode(_ data: Data) throws -> TransferEnvelope {
        let envelope = try decoder.decode(TransferEnvelope.self, from: data)
        try validate(envelope)
        return envelope
    }

    public static func validate(_ envelope: TransferEnvelope) throws {
        guard envelope.protocolVersion == BeamDropProtocol.version else { throw TransferEnvelopeError.unsupportedProtocol }
        guard envelope.payloadMetadata.sizeBytes >= 0 else { throw TransferEnvelopeError.invalidSize }
        guard envelope.payloadMetadata.chunkSize > 0 else { throw TransferEnvelopeError.invalidChunkSize }
        guard SafeSha256.isHexDigest(envelope.payloadMetadata.sha256) else { throw TransferEnvelopeError.missingHash }
        guard SafeTransferFileName.isSafe(envelope.payloadMetadata.fileName) else { throw TransferEnvelopeError.invalidFileName }
        let expected = ChunkPlanner.totalChunks(sizeBytes: envelope.payloadMetadata.sizeBytes, chunkSize: envelope.payloadMetadata.chunkSize)
        guard envelope.payloadMetadata.totalChunks == expected else { throw TransferEnvelopeError.invalidChunkMetadata }
    }
}

public enum SafeSha256 {
    public static func isHexDigest(_ value: String) -> Bool {
        guard value.count == 64 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        return value.unicodeScalars.allSatisfy { scalar in
            allowed.contains(scalar)
        }
    }
}

public enum SafeTransferFileName {
    public static func isSafe(_ fileName: String) -> Bool {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else { return false }
        if trimmed.contains("/") || trimmed.contains("\\") || trimmed.contains(":") { return false }
        return trimmed.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar)
        }
    }
}

public enum ChunkPlanner {
    public static func totalChunks(sizeBytes: Int64, chunkSize: Int = BeamDropProtocol.defaultChunkSizeBytes) -> Int64 {
        precondition(sizeBytes >= 0)
        precondition(chunkSize > 0)
        if sizeBytes == 0 { return 1 }
        return ((sizeBytes - 1) / Int64(chunkSize)) + 1
    }
}

public struct TransferHistoryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { transferId }
    public var transferId: String
    public var direction: TransferDirection
    public var peerDeviceId: String
    public var peerDeviceName: String
    public var kind: TransferKind
    public var fileName: String
    public var sizeBytes: Int64
    public var status: TransferStatus
    public var sha256: String?
    public var errorMessage: String?
    public var createdAt: Date
    public var completedAt: Date?

    public init(transferId: String, direction: TransferDirection, peerDeviceId: String, peerDeviceName: String, kind: TransferKind, fileName: String, sizeBytes: Int64, status: TransferStatus, sha256: String?, errorMessage: String?, createdAt: Date, completedAt: Date?) {
        self.transferId = transferId
        self.direction = direction
        self.peerDeviceId = peerDeviceId
        self.peerDeviceName = peerDeviceName
        self.kind = kind
        self.fileName = fileName
        self.sizeBytes = sizeBytes
        self.status = status
        self.sha256 = sha256
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

public struct TransferProgressState: Equatable, Sendable {
    public var transferId: String
    public var currentItem: String
    public var bytesTransferred: Int64
    public var totalBytes: Int64
    public var status: TransferStatus

    public var percent: Int {
        guard totalBytes > 0 else { return 0 }
        return min(100, max(0, Int(bytesTransferred * 100 / totalBytes)))
    }
}
