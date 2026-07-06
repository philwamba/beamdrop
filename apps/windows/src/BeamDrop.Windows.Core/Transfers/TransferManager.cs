using BeamDrop.Windows.Core.Audit;
using BeamDrop.Windows.Core.Peers;
using BeamDrop.Windows.Core.Security;

namespace BeamDrop.Windows.Core.Transfers;

public sealed class TransferManager
{
    private readonly TrustedPeerRepository _trustedPeers;
    private readonly ITransferHistoryStore _historyStore;
    private readonly IReceiveTargetFactory _receiveTargetFactory;
    private readonly IReceiveApprovalPrompt _approvalPrompt;
    private readonly AuditLog _auditLog;
    private readonly string _localDeviceId;
    private readonly string _localPublicKey;

    public TransferManager(
        TrustedPeerRepository trustedPeers,
        ITransferHistoryStore historyStore,
        IReceiveTargetFactory receiveTargetFactory,
        IReceiveApprovalPrompt approvalPrompt,
        AuditLog auditLog,
        string localDeviceId = "windows-local-device",
        string localPublicKey = "")
    {
        _trustedPeers = trustedPeers;
        _historyStore = historyStore;
        _receiveTargetFactory = receiveTargetFactory;
        _approvalPrompt = approvalPrompt;
        _auditLog = auditLog;
        _localDeviceId = localDeviceId;
        _localPublicKey = localPublicKey;
    }

    public async Task<TransferHistoryRecord> SendTextAsync(string receiverDeviceId, string text, ITransferTransport transport, CancellationToken cancellationToken)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(text);
        return await SendPayloadAsync(receiverDeviceId, TransferKind.Text, "Text", "text/plain", new MemoryStream(bytes), bytes.Length, transport, cancellationToken);
    }

    public async Task<TransferHistoryRecord> SendFileAsync(string receiverDeviceId, string filePath, ITransferTransport transport, IProgress<TransferProgress>? progress, CancellationToken cancellationToken)
    {
        var file = new FileInfo(filePath);
        await using var stream = File.OpenRead(filePath);
        return await SendPayloadAsync(receiverDeviceId, TransferKind.File, file.Name, "application/octet-stream", stream, file.Length, transport, cancellationToken, progress);
    }

    public async Task<TransferHistoryRecord> ReceiveTextAsync(IncomingTransferRequest request, string text, CancellationToken cancellationToken)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(text);
        return await ReceivePayloadAsync(request, new MemoryStream(bytes), cancellationToken);
    }

    public async Task<TransferHistoryRecord> ReceiveFileAsync(IncomingTransferRequest request, Stream payload, CancellationToken cancellationToken) =>
        await ReceivePayloadAsync(request, payload, cancellationToken);

    private async Task<TransferHistoryRecord> SendPayloadAsync(
        string receiverDeviceId,
        TransferKind kind,
        string fileName,
        string mimeType,
        Stream payload,
        long sizeBytes,
        ITransferTransport transport,
        CancellationToken cancellationToken,
        IProgress<TransferProgress>? progress = null)
    {
        var peer = _trustedPeers.RequireTrusted(receiverDeviceId);
        var sha = Fingerprint.Sha256Hex(payload);
        payload.Position = 0;
        var manifest = new TransferManifest(
            TransferId: $"tx-{Guid.NewGuid():N}",
            Kind: kind,
            SenderDeviceId: _localDeviceId,
            ReceiverDeviceId: peer.DeviceId,
            FileName: fileName,
            MimeType: mimeType,
            SizeBytes: sizeBytes,
            ChunkSizeBytes: BeamDropProtocol.DefaultChunkSizeBytes,
            TotalChunks: ChunkCalculator.TotalChunks(sizeBytes),
            Sha256: sha,
            CreatedAt: DateTimeOffset.UtcNow,
            SenderPublicKey: _localPublicKey);

        _auditLog.Add(AuditEventType.TransferQueued, peer.DeviceId, manifest.TransferId, $"Queued {fileName}.");
        try
        {
            await transport.SendAsync(manifest, payload, progress ?? new Progress<TransferProgress>(), cancellationToken);
            return Persist(manifest, peer, TransferDirection.Sent, TransferStatus.Completed, null);
        }
        catch (OperationCanceledException)
        {
            return Persist(manifest, peer, TransferDirection.Sent, TransferStatus.Cancelled, "Transfer cancelled.");
        }
        catch (Exception ex)
        {
            return Persist(manifest, peer, TransferDirection.Sent, TransferStatus.Failed, ex.Message);
        }
    }

    private async Task<TransferHistoryRecord> ReceivePayloadAsync(IncomingTransferRequest request, Stream payload, CancellationToken cancellationToken)
    {
        var sender = _trustedPeers.RequireTrusted(request.Sender.DeviceId, request.Manifest.SenderPublicKey);
        if (!sender.AutoAcceptTransfers && _approvalPrompt.Decide(request) == ReceiveDecision.Reject)
        {
            _auditLog.Add(AuditEventType.TransferRejected, sender.DeviceId, request.Manifest.TransferId, "Incoming transfer rejected.");
            return Persist(request.Manifest, sender, TransferDirection.Received, TransferStatus.Rejected, "Receiver rejected transfer.");
        }

        var target = _receiveTargetFactory.Create(request.Manifest);
        try
        {
            await using (var output = target.OpenWrite())
            {
                var received = await CopyChunkedAsync(payload, output, request.Manifest.ChunkSizeBytes, cancellationToken);
                if (received != request.Manifest.SizeBytes)
                {
                    throw new IncompleteTransferException(request.Manifest.TransferId, request.Manifest.SizeBytes, received);
                }
            }

            if (request.Manifest.Sha256 is null)
            {
                throw new InvalidOperationException("Missing final SHA-256.");
            }

            await using (var verifyStream = target.OpenReadForVerification())
            {
                var actual = Fingerprint.Sha256Hex(verifyStream);
                if (!actual.Equals(request.Manifest.Sha256, StringComparison.OrdinalIgnoreCase))
                {
                    throw new HashMismatchException(request.Manifest.TransferId);
                }
            }

            target.CommitVerified();
            return Persist(request.Manifest, sender, TransferDirection.Received, TransferStatus.Completed, null);
        }
        catch (OperationCanceledException)
        {
            target.Discard();
            return Persist(request.Manifest, sender, TransferDirection.Received, TransferStatus.Cancelled, "Transfer cancelled.");
        }
        catch (HashMismatchException ex)
        {
            target.Discard();
            return Persist(request.Manifest, sender, TransferDirection.Received, TransferStatus.Corrupted, ex.Message);
        }
        catch (IncompleteTransferException ex)
        {
            target.Discard();
            return Persist(request.Manifest, sender, TransferDirection.Received, TransferStatus.Incomplete, ex.Message);
        }
        catch (Exception ex)
        {
            target.Discard();
            return Persist(request.Manifest, sender, TransferDirection.Received, TransferStatus.Failed, ex.Message);
        }
    }

    private static async Task<long> CopyChunkedAsync(Stream input, Stream output, int chunkSizeBytes, CancellationToken cancellationToken)
    {
        var buffer = new byte[chunkSizeBytes];
        var total = 0L;
        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var read = await input.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
            if (read == 0) break;
            await output.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
            total += read;
        }
        return total;
    }

    private TransferHistoryRecord Persist(TransferManifest manifest, TransferPeer peer, TransferDirection direction, TransferStatus status, string? error)
    {
        var record = new TransferHistoryRecord(manifest.TransferId, direction, peer.DeviceId, peer.DeviceName, manifest.Kind, manifest.FileName, manifest.SizeBytes, status, manifest.Sha256, error, manifest.CreatedAt, DateTimeOffset.UtcNow);
        _historyStore.Upsert(record);
        _auditLog.Add(status == TransferStatus.Completed ? AuditEventType.TransferCompleted : AuditEventType.TransferFailed, peer.DeviceId, manifest.TransferId, error ?? status.ToString());
        return record;
    }
}

public sealed class HashMismatchException : Exception
{
    public HashMismatchException(string transferId) : base($"SHA-256 verification failed for {transferId}.") { }
}

public sealed class IncompleteTransferException : Exception
{
    public IncompleteTransferException(string transferId, long expectedBytes, long actualBytes)
        : base($"Incomplete transfer {transferId}: expected {expectedBytes} bytes but received {actualBytes}.") { }
}
