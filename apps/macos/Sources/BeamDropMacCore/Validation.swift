import Foundation

public enum PairingValidator {
    public static func validate(_ payload: PairingPayload, nowMillis: Int64 = Date().epochMillis) throws {
        guard payload.type == "beamdrop_pairing" else {
            throw BeamDropError.invalidPairingPayload("type must be beamdrop_pairing")
        }
        guard payload.protocolVersion == BeamDropProtocol.protocolVersion else {
            throw BeamDropError.unsupportedProtocolVersion
        }
        guard payload.serviceName == BeamDropProtocol.serviceName else {
            throw BeamDropError.invalidPairingPayload("serviceName must be \(BeamDropProtocol.serviceName)")
        }
        guard payload.expiresAtEpochMillis > nowMillis else {
            throw BeamDropError.expiredPairingPayload
        }
        guard !payload.deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeamDropError.missingRequiredField("deviceId")
        }
        guard !payload.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeamDropError.missingRequiredField("deviceName")
        }
        guard !payload.publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeamDropError.missingRequiredField("publicKey")
        }
    }
}

public enum TransferEnvelopeValidator {
    public static func validate(_ envelope: TransferEnvelope) throws {
        guard envelope.protocolVersion == BeamDropProtocol.protocolVersion else {
            throw BeamDropError.unsupportedProtocolVersion
        }
        guard !envelope.transferId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeamDropError.missingRequiredField("transferId")
        }
        guard !envelope.senderDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeamDropError.missingRequiredField("senderDeviceId")
        }
        guard !envelope.receiverDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BeamDropError.missingRequiredField("receiverDeviceId")
        }
        let metadata = envelope.payloadMetadata
        guard metadata.sizeBytes >= 0 else {
            throw BeamDropError.invalidTransferSize
        }
        guard metadata.chunkSize > 0 else {
            throw BeamDropError.invalidChunkMetadata
        }
        guard metadata.totalChunks == ChunkCalculator.totalChunks(sizeBytes: metadata.sizeBytes, chunkSize: metadata.chunkSize) else {
            throw BeamDropError.invalidChunkMetadata
        }
        if envelope.transferType == .file && metadata.sha256?.isEmpty != false {
            throw BeamDropError.missingRequiredField("payloadMetadata.sha256")
        }
    }
}

public enum TransferEnvelopeCodec {
    public static func encode(_ envelope: TransferEnvelope) throws -> String {
        try TransferEnvelopeValidator.validate(envelope)
        let data = try BeamDropJSON.encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decode(_ rawJSON: String) throws -> TransferEnvelope {
        let data = Data(rawJSON.utf8)
        let envelope = try BeamDropJSON.decoder.decode(TransferEnvelope.self, from: data)
        try TransferEnvelopeValidator.validate(envelope)
        return envelope
    }
}

public extension Date {
    var epochMillis: Int64 {
        Int64((timeIntervalSince1970 * 1000).rounded())
    }
}
