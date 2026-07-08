import AppKit
import BeamDropMacCore
import Foundation
import Network
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var identity: DeviceIdentity
    @Published var trustedPeers: [TrustedPeer] = []
    @Published var history: [TransferRecord] = []
    @Published var nearbyDevices: [DiscoveryRecord] = []
    @Published var diagnostics: [NetworkDiagnosticResult] = []
    @Published var clipboardSettings: ClipboardSettings
    @Published var pairingQRText = ""
    @Published var pairingImportText = ""
    @Published var sendText = ""
    @Published var selectedPeer: TrustedPeer?
    @Published var activeProgress: TransferProgress?
    @Published var pendingReceive: PendingReceiveRequest?
    @Published var pendingPairing: PendingPairingRequest?
    @Published var lastError: String?
    @Published var isReceiving = false
    @Published var launchAtLogin = false

    let peerStore: TrustedPeerStore
    let historyStore: TransferHistoryStore
    let auditLog: AuditLog
    let transferService: TransferService
    let clipboardService = ClipboardService()
    let clipboardSettingsStore = ClipboardSettingsStore()
    let pairingService = PairingService()
    var discoveryService: BonjourDiscoveryService!
    var advertiser: BonjourAdvertiser!

    init() {
        do {
            let identityService = DeviceIdentityService()
            let identity = try identityService.getOrCreateIdentity()
            self.identity = identity
            self.peerStore = TrustedPeerStore()
            self.historyStore = TransferHistoryStore()
            self.auditLog = AuditLog()
            self.transferService = TransferService(
                identity: identity,
                sessionPrivateKey: try identityService.getOrCreateSessionPrivateKey(),
                peerStore: peerStore,
                historyStore: historyStore,
                auditLog: auditLog
            )
            self.clipboardSettings = clipboardSettingsStore.load()
            refresh()
            self.discoveryService = BonjourDiscoveryService { [weak self] records in
                Task { @MainActor in self?.nearbyDevices = records }
            }
            self.advertiser = BonjourAdvertiser(identity: identity)
            generatePairingQR()
            startNetworking()
        } catch {
            fatalError("BeamDrop macOS could not initialize: \(error.localizedDescription)")
        }
    }

    func refresh() {
        trustedPeers = peerStore.all()
        history = historyStore.all()
        diagnostics = NetworkDiagnostics.run()
        selectedPeer = selectedPeer ?? trustedPeers.first(where: { $0.status == .trusted })
    }

    func startNetworking() {
        discoveryService.start()
        do {
            try advertiser.start { [weak self] connection in
                Task { @MainActor in
                    self?.handleIncoming(connection)
                }
            }
            isReceiving = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    func generatePairingQR() {
        let endpoint = PairingEndpoint(
            host: LocalNetworkAddress.firstUsableIPv4Address(),
            port: BeamDropProtocol.defaultTransferPort,
            route: "local"
        )
        do {
            let payload = pairingService.generatePayload(identity: identity, endpoint: endpoint)
            pairingQRText = try pairingService.encodeForQR(payload)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func importPairingCode() {
        do {
            let payload = try pairingService.importPayload(rawText: pairingImportText)
            _ = try peerStore.approve(payload)
            try auditLog.record(type: "pairing_approved", message: "Trusted \(payload.deviceName) (\(payload.deviceId)).")
            pairingImportText = ""
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func revoke(_ peer: TrustedPeer) {
        do {
            try peerStore.revoke(deviceId: peer.deviceId)
            try auditLog.record(type: "peer_revoked", message: "Revoked \(peer.deviceName).")
            refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendCurrentText() {
        guard let peer = selectedPeer else {
            lastError = "Choose a trusted device before sending."
            return
        }
        do {
            try transferService.sendText(sendText, to: peer) { progress in
                Task { @MainActor in self.activeProgress = progress }
            }
            sendText = ""
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func chooseAndSendFile() {
        guard let peer = selectedPeer else {
            lastError = "Choose a trusted device before sending."
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            sendFile(url, to: peer)
        }
    }

    func sendFile(_ url: URL, to peer: TrustedPeer? = nil) {
        guard let peer = peer ?? selectedPeer else {
            lastError = "Choose a trusted device before sending."
            return
        }
        do {
            try transferService.sendFile(url, to: peer) { progress in
                Task { @MainActor in self.activeProgress = progress }
            }
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func sendClipboard() {
        guard let peer = selectedPeer else {
            lastError = "Choose a trusted device before sending clipboard."
            return
        }
        guard let text = clipboardService.readText() else {
            lastError = "Clipboard does not contain text."
            return
        }
        do {
            try transferService.sendClipboardText(text, to: peer, settings: clipboardSettings) { progress in
                Task { @MainActor in self.activeProgress = progress }
            }
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func cancelActiveTransfer() {
        guard let transferId = activeProgress?.transferId else { return }
        transferService.cancel(transferId: transferId)
        activeProgress = activeProgress.map {
            TransferProgress(
                transferId: $0.transferId,
                status: .cancelled,
                bytesTransferred: $0.bytesTransferred,
                totalBytes: $0.totalBytes,
                percent: $0.percent,
                speedBytesPerSecond: $0.speedBytesPerSecond,
                fileName: $0.fileName,
                peerDeviceName: $0.peerDeviceName
            )
        }
        refresh()
    }

    func saveClipboardSettings() {
        clipboardSettingsStore.save(clipboardSettings)
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = "Start at login could not be updated: \(error.localizedDescription)"
        }
    }

    private func handleIncoming(_ connection: NWConnection) {
        transferService.handleIncomingConnection(connection) { [weak self] envelope, peer in
            guard let self else { return false }
            if peer.autoAcceptTransfers { return true }
            let semaphore = DispatchSemaphore(value: 0)
            var approved = false
            Task { @MainActor in
                self.pendingReceive = PendingReceiveRequest(
                    senderName: peer.deviceName,
                    fileName: envelope.payloadMetadata.fileName,
                    sizeBytes: envelope.payloadMetadata.sizeBytes,
                    accept: {
                        approved = true
                        semaphore.signal()
                    },
                    reject: {
                        approved = false
                        semaphore.signal()
                    }
                )
            }
            _ = semaphore.wait(timeout: .now() + 120)
            Task { @MainActor in self.pendingReceive = nil }
            return approved
        } approvePairing: { [weak self] payload in
            guard let self else { return false }
            let semaphore = DispatchSemaphore(value: 0)
            var approved = false
            Task { @MainActor in
                self.pendingPairing = PendingPairingRequest(
                    deviceName: payload.deviceName,
                    platform: payload.platform.rawValue,
                    fingerprint: payload.fingerprint ?? String(payload.publicKey.prefix(16)),
                    accept: {
                        approved = true
                        semaphore.signal()
                    },
                    reject: {
                        approved = false
                        semaphore.signal()
                    }
                )
            }
            _ = semaphore.wait(timeout: .now() + 120)
            Task { @MainActor in self.pendingPairing = nil }
            return approved
        } progress: { progress in
            Task { @MainActor in self.activeProgress = progress }
        } completion: { [weak self] result in
            Task { @MainActor in
                if case .failure(let error) = result {
                    self?.lastError = error.localizedDescription
                }
                self?.refresh()
            }
        }
    }
}

struct PendingReceiveRequest: Identifiable {
    let id = UUID()
    let senderName: String
    let fileName: String
    let sizeBytes: Int64
    let accept: () -> Void
    let reject: () -> Void
}

struct PendingPairingRequest: Identifiable {
    let id = UUID()
    let deviceName: String
    let platform: String
    let fingerprint: String
    let accept: () -> Void
    let reject: () -> Void
}
