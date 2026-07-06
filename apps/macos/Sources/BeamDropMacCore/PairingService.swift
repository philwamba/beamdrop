import CoreImage
import Foundation

public final class PairingService {
    public init() {}

    public func generatePayload(identity: DeviceIdentity, endpoint: PairingEndpoint?, lifetime: TimeInterval = 300) -> PairingPayload {
        PairingPayload(
            pairingSessionId: "pair-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            deviceId: identity.deviceId,
            deviceName: identity.deviceName,
            platform: .macos,
            publicKey: identity.publicKey,
            fingerprint: identity.fingerprint,
            endpoint: endpoint,
            expiresAtEpochMillis: Date().addingTimeInterval(lifetime).epochMillis
        )
    }

    public func encodeForQR(_ payload: PairingPayload) throws -> String {
        try PairingValidator.validate(payload)
        return String(decoding: try BeamDropJSON.encoder.encode(payload), as: UTF8.self)
    }

    public func importPayload(rawText: String) throws -> PairingPayload {
        let data = Data(rawText.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        let payload = try BeamDropJSON.decoder.decode(PairingPayload.self, from: data)
        try PairingValidator.validate(payload)
        return payload
    }
}

public enum QRCodeGenerator {
    public static func makeCIImage(from text: String) -> CIImage? {
        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(Data(text.utf8), forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel")
        return filter?.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
    }
}
