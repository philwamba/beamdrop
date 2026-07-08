import Foundation
import os

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

/// A received item surfaced to the UI after trust, decryption, and hash checks pass.
public struct ReceivedTransferItem: Equatable, Identifiable, Sendable {
    public var id: String { transferId }
    public var transferId: String
    public var kind: TransferKind
    public var text: String?
    public var fileURL: URL?
    public var peerDeviceName: String
    public var receivedAt: Date
}

/// Drives the real foreground transfer transport for the SwiftUI send/receive
/// surfaces: dials trusted peers over TCP, seals chunks with the session
/// protocol, accepts inbound connections, and keeps progress/history published.
@MainActor
public final class TransferCoordinator: ObservableObject {
    @Published public private(set) var progress: TransferProgressState?
    @Published public private(set) var history: [TransferHistoryRecord] = []
    @Published public private(set) var receivedItems: [ReceivedTransferItem] = []
    @Published public var errorMessage: String?

    private let identity: DeviceIdentity
    private let sessionSecretKey: Data
    private let service: TransferService
    private let historyRepository: TransferHistoryRepository
    private let dialer: any TransferDialing
    private let receiveDirectory: URL
    private var activeSendTask: Task<TransferHistoryRecord?, Never>?
    private let logger = Logger(subsystem: "com.beamdrop.ios", category: "transfer")

    public init(
        identity: DeviceIdentity,
        sessionSecretKey: Data,
        trustedPeers: TrustedPeerRepository,
        history: TransferHistoryRepository,
        dialer: any TransferDialing,
        receiveDirectory: URL
    ) {
        self.identity = identity
        self.sessionSecretKey = sessionSecretKey
        self.service = TransferService(trustedPeers: trustedPeers, history: history)
        self.historyRepository = history
        self.dialer = dialer
        self.receiveDirectory = receiveDirectory
        self.history = history.list()
    }

    @discardableResult
    public func sendText(_ text: String, kind: TransferKind = .text, to peer: TrustedPeer) async -> TransferHistoryRecord? {
        await send(
            payload: .data(Data(text.utf8)),
            kind: kind,
            fileName: "BeamDrop Text",
            mimeType: "text/plain; charset=utf-8",
            to: peer
        )
    }

    @discardableResult
    public func sendFile(at url: URL, to peer: TrustedPeer) async -> TransferHistoryRecord? {
        await send(
            payload: .file(url),
            kind: .file,
            fileName: url.lastPathComponent,
            mimeType: "application/octet-stream",
            to: peer
        )
    }

    public func cancelCurrentTransfer() {
        activeSendTask?.cancel()
    }

    /// Entry point for inbound connections from `LocalTransferListener`.
    public func handleIncomingConnection(_ connection: any TransferConnecting) async {
        defer { connection.close() }
        let reader = TransferStreamReader(connection: connection)
        var envelope: TransferEnvelope?
        var peer: TrustedPeer?
        do {
            let decoded = try TransferEnvelopeCodec.decode(try await reader.readEnvelopeLine())
            envelope = decoded
            let trusted = try service.requireTrusted(deviceId: decoded.senderDeviceId, publicKey: decoded.senderPublicKey)
            peer = trusted

            let session = try TransferSessionResolver.accept(envelope: decoded, peer: trusted, receiverSecretKey: sessionSecretKey)
            if session == nil {
                logger.notice("Receiving LEGACY plaintext transfer \(decoded.transferId, privacy: .public) from \(trusted.deviceId, privacy: .public); peer has not upgraded to session encryption.")
            }

            updateProgress(transferId: decoded.transferId, item: decoded.payloadMetadata.fileName, bytes: 0, total: decoded.payloadMetadata.sizeBytes, status: .transferring)
            let payload = try await ForegroundTransferEngine.receive(
                envelope: decoded,
                session: session,
                reader: reader,
                onBytesReceived: { [weak self] bytes in
                    Task { @MainActor in
                        self?.updateProgress(transferId: decoded.transferId, item: decoded.payloadMetadata.fileName, bytes: bytes, total: decoded.payloadMetadata.sizeBytes, status: .transferring)
                    }
                }
            )

            updateProgress(transferId: decoded.transferId, item: decoded.payloadMetadata.fileName, bytes: Int64(payload.count), total: decoded.payloadMetadata.sizeBytes, status: .verifying)
            let record = try service.verifyReceivedPayload(envelope: decoded, payload: payload, from: trusted)
            let item = try store(payload: payload, envelope: decoded, peer: trusted)
            receivedItems.insert(item, at: 0)
            try historyRepository.upsert(record)
            history = historyRepository.list()
            updateProgress(transferId: decoded.transferId, item: decoded.payloadMetadata.fileName, bytes: Int64(payload.count), total: decoded.payloadMetadata.sizeBytes, status: .completed)
        } catch {
            errorMessage = error.localizedDescription
            if let envelope, let peer {
                let status: TransferStatus = (error as? TransferSessionError) == .chunkAuthenticationFailed ? .corrupted : .failed
                if let record = try? service.persistFailure(envelope: envelope, peer: peer, status: status, error: error) {
                    history = historyRepository.list()
                    updateProgress(transferId: record.transferId, item: record.fileName, bytes: 0, total: record.sizeBytes, status: status)
                }
            }
        }
    }

    private func send(
        payload: TransferPayloadSource,
        kind: TransferKind,
        fileName: String,
        mimeType: String,
        to peer: TrustedPeer
    ) async -> TransferHistoryRecord? {
        let task = Task { [weak self] in
            await self?.performSend(payload: payload, kind: kind, fileName: fileName, mimeType: mimeType, to: peer)
        }
        activeSendTask = task
        defer { activeSendTask = nil }
        return await task.value ?? nil
    }

    private func performSend(
        payload: TransferPayloadSource,
        kind: TransferKind,
        fileName: String,
        mimeType: String,
        to peer: TrustedPeer
    ) async -> TransferHistoryRecord? {
        errorMessage = nil
        let transferId = "tx-\(UUID().uuidString.lowercased())"
        var record = TransferHistoryRecord(
            transferId: transferId,
            direction: .sent,
            peerDeviceId: peer.deviceId,
            peerDeviceName: peer.deviceName,
            kind: kind,
            fileName: fileName,
            sizeBytes: 0,
            status: .queued,
            sha256: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: nil
        )
        do {
            _ = try service.requireTrusted(deviceId: peer.deviceId, publicKey: peer.publicKey)
            guard let endpoint = peer.endpoint, endpoint.isUsable else { throw TransferServiceError.missingEndpoint }

            let sizeBytes = try payload.sizeBytes()
            let sha256 = try payload.sha256Hex()
            record.sizeBytes = sizeBytes
            record.sha256 = sha256

            let (encryption, session) = try TransferSessionResolver.initiate(
                identity: identity,
                senderSecretKey: sessionSecretKey,
                peer: peer,
                transferId: transferId
            )
            if session == nil {
                logger.notice("Sending LEGACY plaintext transfer \(transferId, privacy: .public) to \(peer.deviceId, privacy: .public); stored peer key is not an X25519 pairing key.")
            }

            let envelope = TransferEnvelope(
                transferId: transferId,
                transferType: kind,
                senderDeviceId: identity.deviceId,
                senderPublicKey: identity.publicKey,
                receiverDeviceId: peer.deviceId,
                encryption: encryption,
                payloadMetadata: TransferPayloadMetadata(
                    fileName: fileName,
                    mimeType: mimeType,
                    sizeBytes: sizeBytes,
                    sha256: sha256
                )
            )

            record.status = .transferring
            try historyRepository.upsert(record)
            history = historyRepository.list()
            updateProgress(transferId: transferId, item: fileName, bytes: 0, total: sizeBytes, status: .transferring)

            let connection = try await dialer.connect(to: endpoint)
            defer { connection.close() }
            try await ForegroundTransferEngine.send(
                payload: payload,
                envelope: envelope,
                session: session,
                over: connection,
                onBytesSent: { [weak self] bytes in
                    Task { @MainActor in
                        self?.updateProgress(transferId: transferId, item: fileName, bytes: bytes, total: sizeBytes, status: .transferring)
                    }
                }
            )

            record.status = .completed
            record.completedAt = Date()
            try historyRepository.upsert(record)
            history = historyRepository.list()
            updateProgress(transferId: transferId, item: fileName, bytes: sizeBytes, total: sizeBytes, status: .completed)
            return record
        } catch {
            record.status = error is CancellationError ? .cancelled : .failed
            record.errorMessage = error.localizedDescription
            record.completedAt = Date()
            errorMessage = error.localizedDescription
            try? historyRepository.upsert(record)
            history = historyRepository.list()
            updateProgress(transferId: transferId, item: fileName, bytes: 0, total: record.sizeBytes, status: record.status)
            return record
        }
    }

    private func store(payload: Data, envelope: TransferEnvelope, peer: TrustedPeer) throws -> ReceivedTransferItem {
        switch envelope.transferType {
        case .text, .url, .clipboardText:
            return ReceivedTransferItem(
                transferId: envelope.transferId,
                kind: envelope.transferType,
                text: String(decoding: payload, as: UTF8.self),
                fileURL: nil,
                peerDeviceName: peer.deviceName,
                receivedAt: Date()
            )
        case .file:
            try FileManager.default.createDirectory(at: receiveDirectory, withIntermediateDirectories: true)
            let destination = uniqueDestination(for: envelope.payloadMetadata.fileName)
            try payload.write(to: destination, options: [.atomic])
            return ReceivedTransferItem(
                transferId: envelope.transferId,
                kind: .file,
                text: nil,
                fileURL: destination,
                peerDeviceName: peer.deviceName,
                receivedAt: Date()
            )
        }
    }

    /// File names were already validated against path traversal by the envelope
    /// codec; this only avoids clobbering an earlier receive with the same name.
    private func uniqueDestination(for fileName: String) -> URL {
        let base = receiveDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: base.path) else { return base }
        let stem = base.deletingPathExtension().lastPathComponent
        let ext = base.pathExtension
        for attempt in 1...10_000 {
            let candidateName = ext.isEmpty ? "\(stem) (\(attempt))" : "\(stem) (\(attempt)).\(ext)"
            let candidate = receiveDirectory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return receiveDirectory.appendingPathComponent("\(UUID().uuidString)-\(fileName)")
    }

    private func updateProgress(transferId: String, item: String, bytes: Int64, total: Int64, status: TransferStatus) {
        progress = TransferProgressState(
            transferId: transferId,
            currentItem: item,
            bytesTransferred: bytes,
            totalBytes: total,
            status: status
        )
    }
}
