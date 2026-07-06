import Foundation

public struct DeviceIdentity: Codable, Equatable, Sendable {
    public var deviceId: String
    public var deviceName: String
    public var platform: BeamDropPlatform
    public var publicKey: String
    public var protocolVersion: String

    public init(deviceId: String, deviceName: String, platform: BeamDropPlatform, publicKey: String, protocolVersion: String = BeamDropProtocol.version) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.protocolVersion = protocolVersion
    }
}

public struct PairingQRPayload: Codable, Equatable, Sendable {
    public var type: String
    public var protocolVersion: String
    public var serviceName: String
    public var pairingSessionId: String
    public var deviceId: String
    public var deviceName: String
    public var platform: BeamDropPlatform
    public var publicKey: String
    public var endpoint: EndpointHint?
    public var expiresAtEpochMillis: Int64

    public init(
        type: String = "beamdrop_pairing",
        protocolVersion: String = BeamDropProtocol.version,
        serviceName: String = BeamDropProtocol.serviceName,
        pairingSessionId: String,
        deviceId: String,
        deviceName: String,
        platform: BeamDropPlatform,
        publicKey: String,
        endpoint: EndpointHint?,
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
        self.endpoint = endpoint
        self.expiresAtEpochMillis = expiresAtEpochMillis
    }
}

public struct PairingRequest: Equatable, Sendable {
    public var requestId: String
    public var remoteIdentity: DeviceIdentity
    public var endpoint: EndpointHint?
    public var fingerprint: String
    public var receivedAt: Date

    public init(requestId: String = UUID().uuidString, remoteIdentity: DeviceIdentity, endpoint: EndpointHint?, fingerprint: String, receivedAt: Date = Date()) {
        self.requestId = requestId
        self.remoteIdentity = remoteIdentity
        self.endpoint = endpoint
        self.fingerprint = fingerprint
        self.receivedAt = receivedAt
    }
}

public enum PairingError: Error, Equatable, LocalizedError {
    case invalidQR
    case expiredQR
    case unsupportedProtocol
    case serviceNameMismatch
    case alreadyTrusted
    case previouslyRevoked

    public var errorDescription: String? {
        switch self {
        case .invalidQR: "QR invalid. Scan a current BeamDrop pairing code."
        case .expiredQR: "QR expired. Ask the other device to refresh its pairing code."
        case .unsupportedProtocol: "Protocol mismatch. One BeamDrop app needs to be updated."
        case .serviceNameMismatch: "QR is not for the BeamDrop local service."
        case .alreadyTrusted: "Device already trusted."
        case .previouslyRevoked: "This device was revoked. Re-pair deliberately before trusting it again."
        }
    }
}

public enum PairingCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    public static func encode(_ payload: PairingQRPayload) throws -> String {
        String(decoding: try encoder.encode(payload), as: UTF8.self)
    }

    public static func decode(_ raw: String) throws -> PairingQRPayload {
        let payload = try decoder.decode(PairingQRPayload.self, from: Data(raw.utf8))
        guard payload.type == "beamdrop_pairing" else { throw PairingError.invalidQR }
        return payload
    }
}

public struct PairingValidator {
    public var now: () -> Date
    public var trustLookup: (String, String) -> TrustState

    public init(now: @escaping () -> Date = Date.init, trustLookup: @escaping (String, String) -> TrustState) {
        self.now = now
        self.trustLookup = trustLookup
    }

    public func validate(rawPayload: String) throws -> PairingRequest {
        let payload = try PairingCodec.decode(rawPayload)
        guard payload.protocolVersion == BeamDropProtocol.version else { throw PairingError.unsupportedProtocol }
        guard payload.serviceName == BeamDropProtocol.serviceName else { throw PairingError.serviceNameMismatch }
        guard payload.expiresAtEpochMillis > Int64(now().timeIntervalSince1970 * 1000) else { throw PairingError.expiredQR }
        guard !payload.deviceId.isEmpty, !payload.deviceName.isEmpty, !payload.publicKey.isEmpty, payload.platform != .unknown else {
            throw PairingError.invalidQR
        }

        switch trustLookup(payload.deviceId, payload.publicKey) {
        case .trusted: throw PairingError.alreadyTrusted
        case .revoked: throw PairingError.previouslyRevoked
        case .unknown, .pairing:
            return PairingRequest(
                remoteIdentity: DeviceIdentity(
                    deviceId: payload.deviceId,
                    deviceName: payload.deviceName,
                    platform: payload.platform,
                    publicKey: payload.publicKey,
                    protocolVersion: payload.protocolVersion
                ),
                endpoint: payload.endpoint,
                fingerprint: Fingerprint.publicKeyFingerprint(payload.publicKey),
                receivedAt: now()
            )
        }
    }
}
