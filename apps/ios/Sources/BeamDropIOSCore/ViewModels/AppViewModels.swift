import Foundation

@MainActor
public final class HomeViewModel: ObservableObject {
    @Published public private(set) var trustedPeers: [TrustedPeer] = []
    @Published public var errorMessage: String?

    private let repository: TrustedPeerRepository

    public init(repository: TrustedPeerRepository) {
        self.repository = repository
        reload()
    }

    public func reload() {
        trustedPeers = repository.list()
    }
}

@MainActor
public final class PairDeviceViewModel: ObservableObject {
    @Published public private(set) var qrPayload: String = ""
    @Published public var pendingRequest: PairingRequest?
    @Published public var errorMessage: String?

    private let identity: DeviceIdentity
    private let endpoint: EndpointHint?
    private let repository: TrustedPeerRepository

    public init(identity: DeviceIdentity, endpoint: EndpointHint?, repository: TrustedPeerRepository) {
        self.identity = identity
        self.endpoint = endpoint
        self.repository = repository
        refreshQR()
    }

    public func refreshQR(now: Date = Date()) {
        do {
            let payload = PairingQRPayload(
                pairingSessionId: "pair-\(UUID().uuidString.lowercased())",
                deviceId: identity.deviceId,
                deviceName: identity.deviceName,
                platform: identity.platform,
                publicKey: identity.publicKey,
                endpoint: endpoint,
                expiresAtEpochMillis: Int64(now.addingTimeInterval(300).timeIntervalSince1970 * 1000)
            )
            qrPayload = try PairingCodec.encode(payload)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func importScannedPayload(_ raw: String) {
        do {
            let validator = PairingValidator(trustLookup: repository.trustState(deviceId:publicKey:))
            pendingRequest = try validator.validate(rawPayload: raw)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func approvePending() {
        guard let pendingRequest else { return }
        do {
            _ = try repository.approve(pendingRequest)
            self.pendingRequest = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
public final class TransferProgressViewModel: ObservableObject {
    @Published public var progress: TransferProgressState?
    @Published public var history: [TransferHistoryRecord] = []

    private let historyRepository: TransferHistoryRepository

    public init(historyRepository: TransferHistoryRepository) {
        self.historyRepository = historyRepository
        self.history = historyRepository.list()
    }

    public func cancelCurrentTransfer() {
        guard let progress else { return }
        self.progress = TransferProgressState(
            transferId: progress.transferId,
            currentItem: progress.currentItem,
            bytesTransferred: progress.bytesTransferred,
            totalBytes: progress.totalBytes,
            status: .cancelled
        )
    }

    public func reloadHistory() {
        history = historyRepository.list()
    }
}
