using BeamDrop.Windows.Core.Peers;

namespace BeamDrop.Windows.Core.Transfers;

public sealed record TransferManifest(
    string TransferId,
    TransferKind Kind,
    string SenderDeviceId,
    string ReceiverDeviceId,
    string FileName,
    string MimeType,
    long SizeBytes,
    int ChunkSizeBytes,
    long TotalChunks,
    string? Sha256,
    DateTimeOffset CreatedAt,
    string? SenderPublicKey = null);

public sealed record ChunkMetadata(long Index, long Offset, int SizeBytes);

public sealed record ChunkPlan(long FileSizeBytes, int ChunkSizeBytes, IReadOnlyList<ChunkMetadata> Chunks)
{
    public long TotalChunks => Chunks.Count;
}

public sealed record ResumePlan(string TransferId, long TotalChunks, IReadOnlySet<long> CompletedChunks, IReadOnlyList<long> MissingChunks);

public sealed record TransferProgress(
    string TransferId,
    string PeerDeviceName,
    string FileName,
    TransferDirection Direction,
    TransferStatus Status,
    long BytesTransferred,
    long TotalBytes,
    long SpeedBytesPerSecond)
{
    public int Percent => TotalBytes == 0 ? 100 : (int)Math.Min(100, (BytesTransferred * 100) / TotalBytes);
}

public sealed record TransferHistoryRecord(
    string TransferId,
    TransferDirection Direction,
    string PeerDeviceId,
    string PeerDeviceName,
    TransferKind Kind,
    string FileName,
    long SizeBytes,
    TransferStatus Status,
    string? Sha256,
    string? ErrorMessage,
    DateTimeOffset CreatedAt,
    DateTimeOffset? CompletedAt);

public sealed record IncomingTransferRequest(TransferManifest Manifest, TransferPeer Sender);

public enum ReceiveDecision
{
    Accept,
    Reject
}

public interface IReceiveApprovalPrompt
{
    ReceiveDecision Decide(IncomingTransferRequest request);
}

public sealed class RejectingReceiveApprovalPrompt : IReceiveApprovalPrompt
{
    public ReceiveDecision Decide(IncomingTransferRequest request) => ReceiveDecision.Reject;
}
