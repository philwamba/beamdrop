import BeamDropIOSCore
import CoreImage.CIFilterBuiltins
import SwiftUI

struct PairDeviceView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject private var model: PairDeviceScreenModel
    @State private var showingScanner = false

    init() {
        _model = StateObject(wrappedValue: PairDeviceScreenModel.placeholder())
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    QRCodeImage(payload: model.qrPayload)
                        .frame(width: 240, height: 240)
                        .padding()
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    Text("Show this QR to another BeamDrop device.")
                        .foregroundStyle(.secondary)
                    Button("Refresh QR") {
                        model.refreshQR()
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Section("Scan") {
                Button {
                    showingScanner = true
                } label: {
                    Label("Scan QR code", systemImage: "qrcode.viewfinder")
                }
                TextField("Paste pairing payload", text: $model.manualPayload, axis: .vertical)
                Button("Validate pasted QR") {
                    model.importScannedPayload(model.manualPayload)
                }
            }

            if let request = model.pendingRequest {
                Section("Pairing approval") {
                    DeviceApprovalView(request: request) {
                        model.approvePending()
                    } reject: {
                        model.pendingRequest = nil
                    }
                }
            }

            if let error = model.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Pair Device")
        .sheet(isPresented: $showingScanner) {
            QRScannerView { payload in
                showingScanner = false
                model.importScannedPayload(payload)
            }
        }
        .onAppear {
            model.configure(identity: container.identity, repository: container.trustedPeers)
        }
    }
}

@MainActor
final class PairDeviceScreenModel: ObservableObject {
    @Published var qrPayload = ""
    @Published var manualPayload = ""
    @Published var pendingRequest: PairingRequest?
    @Published var errorMessage: String?

    private var identity: DeviceIdentity
    private var repository: TrustedPeerRepository?

    init(identity: DeviceIdentity, repository: TrustedPeerRepository?) {
        self.identity = identity
        self.repository = repository
    }

    static func placeholder() -> PairDeviceScreenModel {
        PairDeviceScreenModel(identity: DeviceIdentity(deviceId: "pending", deviceName: "iPhone", platform: .ios, publicKey: "pending"), repository: nil)
    }

    func configure(identity: DeviceIdentity, repository: TrustedPeerRepository) {
        self.identity = identity
        self.repository = repository
        if qrPayload.isEmpty { refreshQR() }
    }

    func refreshQR() {
        do {
            let payload = PairingQRPayload(
                pairingSessionId: "pair-\(UUID().uuidString.lowercased())",
                deviceId: identity.deviceId,
                deviceName: identity.deviceName,
                platform: .ios,
                publicKey: identity.publicKey,
                endpoint: EndpointHint(host: nil, port: BeamDropProtocol.defaultPort),
                expiresAtEpochMillis: Int64(Date().addingTimeInterval(300).timeIntervalSince1970 * 1000)
            )
            qrPayload = try PairingCodec.encode(payload)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importScannedPayload(_ raw: String) {
        guard let repository else { return }
        do {
            let validator = PairingValidator(trustLookup: repository.trustState(deviceId:publicKey:))
            pendingRequest = try validator.validate(rawPayload: raw)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func approvePending() {
        guard let pendingRequest, let repository else { return }
        do {
            _ = try repository.approve(pendingRequest)
            self.pendingRequest = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DeviceApprovalView: View {
    let request: PairingRequest
    let approve: () -> Void
    let reject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(request.remoteIdentity.deviceName).font(.headline)
            Text("Platform: \(request.remoteIdentity.platform.rawValue)")
            Text("Fingerprint: \(request.fingerprint)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Approve", action: approve).buttonStyle(.borderedProminent)
                Button("Reject", role: .cancel, action: reject)
            }
        }
    }
}

struct QRCodeImage: View {
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let image = makeImage() {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .scaledToFit()
        }
    }

    private func makeImage() -> UIImage? {
        filter.message = Data(payload.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
