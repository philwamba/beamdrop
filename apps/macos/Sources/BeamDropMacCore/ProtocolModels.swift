import Foundation

public enum BeamDropProtocol {
    public static let protocolVersion = "1.0"
    public static let serviceName = "_beamdrop._tcp"
    public static let defaultTransferPort = 49320
    public static let defaultChunkSizeBytes: Int64 = 4 * 1024 * 1024
    public static let sessionEncryptionScheme = "BEAMDROP_SESSION_V1"
}

public enum BeamDropPlatform: String, Codable, Sendable, CaseIterable {
    case android
    case ios
    case macos
    case windows
}

public enum TransferType: String, Codable, Sendable, CaseIterable {
    case text = "TEXT"
    case url = "URL"
    case file = "FILE"
    case folderArchive = "FOLDER_ARCHIVE"
    case image = "IMAGE"
    case screenshot = "SCREENSHOT"
    case clipboardText = "CLIPBOARD_TEXT"
    case clipboardImage = "CLIPBOARD_IMAGE"
    case pairingRequest = "PAIRING_REQUEST"
    case pairingAccepted = "PAIRING_ACCEPTED"
    case transferCancel = "TRANSFER_CANCEL"
    case transferResume = "TRANSFER_RESUME"
    case devicePing = "DEVICE_PING"
}

public enum TransferStatus: String, Codable, Sendable, CaseIterable {
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

public enum BeamDropError: Error, LocalizedError, Equatable {
    case unsupportedProtocolVersion
    case unsupportedTransferType(String)
    case invalidPairingPayload(String)
    case expiredPairingPayload
    case missingRequiredField(String)
    case invalidChunkMetadata
    case invalidTransferSize
    case unknownPeer(String)
    case revokedPeer(String)
    case transferRejected(String)
    case hashMismatch(expected: String, actual: String)
    case cancelled
    case networkUnavailable(String)
    case fileAccessFailed(String)
    case clipboardBlocked(String)
    case invalidFileName
    case invalidEncryptionMetadata(String)
    case encryptionFailure(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedProtocolVersion:
            return "Unsupported BeamDrop protocol version."
        case .unsupportedTransferType(let value):
            return "Unsupported transfer type: \(value)."
        case .invalidPairingPayload(let reason):
            return "Pairing payload is invalid: \(reason)"
        case .expiredPairingPayload:
            return "Pairing QR code expired. Generate a new code and try again."
        case .missingRequiredField(let field):
            return "Missing required BeamDrop field: \(field)."
        case .invalidChunkMetadata:
            return "Transfer chunk metadata does not match the payload size."
        case .invalidTransferSize:
            return "Transfer size must not be negative."
        case .unknownPeer(let deviceId):
            return "Unknown device rejected: \(deviceId). Pair the device before sending."
        case .revokedPeer(let deviceId):
            return "Revoked device blocked: \(deviceId). Re-pair before sending."
        case .transferRejected(let reason):
            return "Transfer rejected: \(reason)"
        case .hashMismatch(let expected, let actual):
            return "SHA-256 verification failed. Expected \(expected), got \(actual)."
        case .cancelled:
            return "Transfer cancelled."
        case .networkUnavailable(let reason):
            return "Local network is unavailable: \(reason)"
        case .fileAccessFailed(let reason):
            return "File access failed: \(reason)"
        case .clipboardBlocked(let reason):
            return "Clipboard was not sent: \(reason)"
        case .invalidFileName:
            return "File name must not contain path separators or control characters."
        case .invalidEncryptionMetadata(let reason):
            return "Transfer encryption metadata is invalid: \(reason)"
        case .encryptionFailure(let reason):
            return "Transfer encryption failed: \(reason)"
        }
    }
}

public struct PairingEndpoint: Codable, Equatable, Sendable {
    public var host: String?
    public var port: Int?
    public var route: String

    public init(host: String?, port: Int?, route: String = "local") {
        self.host = host
        self.port = port
        self.route = route
    }
}

public struct PairingPayload: Codable, Equatable, Sendable {
    public var type: String
    public var protocolVersion: String
    public var serviceName: String
    public var pairingSessionId: String
    public var deviceId: String
    public var deviceName: String
    public var platform: BeamDropPlatform
    public var publicKey: String
    public var fingerprint: String?
    public var endpoint: PairingEndpoint?
    public var expiresAtEpochMillis: Int64

    public init(
        type: String = "beamdrop_pairing",
        protocolVersion: String = BeamDropProtocol.protocolVersion,
        serviceName: String = BeamDropProtocol.serviceName,
        pairingSessionId: String,
        deviceId: String,
        deviceName: String,
        platform: BeamDropPlatform,
        publicKey: String,
        fingerprint: String?,
        endpoint: PairingEndpoint?,
        expiresAtEpochMillis: Int64
    ) {
        self.type = type
        self.protocolVersion = protocolVersion
        self.serviceName = serviceName
        self.pairingSessionId = pairingSessionId
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.fingerprint = fingerprint
        self.endpoint = endpoint
        self.expiresAtEpochMillis = expiresAtEpochMillis
    }
}

public struct PayloadMetadata: Codable, Equatable, Sendable {
    public var fileName: String
    public var mimeType: String
    public var sizeBytes: Int64
    public var chunkSize: Int64
    public var totalChunks: Int64
    public var sha256: String?

    public init(
        fileName: String,
        mimeType: String,
        sizeBytes: Int64,
        chunkSize: Int64 = BeamDropProtocol.defaultChunkSizeBytes,
        totalChunks: Int64? = nil,
        sha256: String?
    ) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.chunkSize = chunkSize
        self.totalChunks = totalChunks ?? ChunkCalculator.totalChunks(sizeBytes: sizeBytes, chunkSize: chunkSize)
        self.sha256 = sha256
    }
}

public struct TransferEncryption: Codable, Equatable, Sendable {
    public var scheme: String
    public var ephemeralPublicKey: String

    public init(scheme: String = BeamDropProtocol.sessionEncryptionScheme, ephemeralPublicKey: String) {
        self.scheme = scheme
        self.ephemeralPublicKey = ephemeralPublicKey
    }
}

public struct TransferEnvelope: Codable, Equatable, Sendable {
    public var protocolVersion: String
    public var transferId: String
    public var transferType: TransferType
    public var senderDeviceId: String
    public var senderPublicKey: String
    public var receiverDeviceId: String
    public var createdAt: String
    public var encryption: TransferEncryption?
    public var payloadMetadata: PayloadMetadata

    public init(
        protocolVersion: String = BeamDropProtocol.protocolVersion,
        transferId: String,
        transferType: TransferType,
        senderDeviceId: String,
        senderPublicKey: String,
        receiverDeviceId: String,
        createdAt: String = ISO8601DateFormatter.beamDrop.string(from: Date()),
        encryption: TransferEncryption? = nil,
        payloadMetadata: PayloadMetadata
    ) {
        self.protocolVersion = protocolVersion
        self.transferId = transferId
        self.transferType = transferType
        self.senderDeviceId = senderDeviceId
        self.senderPublicKey = senderPublicKey
        self.receiverDeviceId = receiverDeviceId
        self.createdAt = createdAt
        self.encryption = encryption
        self.payloadMetadata = payloadMetadata
    }
}

public extension ISO8601DateFormatter {
    static let beamDrop: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

public enum BeamDropJSON {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    public static let decoder = JSONDecoder()
}
