using BeamDrop.Windows.Security;

namespace BeamDrop.Windows.Transfer;

public enum TransferKind
{
    Text,
    Link,
    File,
    Folder,
    Screenshot,
    Clipboard
}

public enum TransferStatus
{
    Queued,
    WaitingForApproval,
    Transferring,
    Verifying,
    Completed,
    Failed,
    Rejected,
    Cancelled
}

public sealed record TransferPeer(
    string DeviceId,
    string DisplayName,
    DevicePlatform Platform,
    string PublicKey);

public sealed record TransferRecord(
    string TransferId,
    TransferKind Kind,
    TransferStatus Status,
    string PeerDeviceId,
    string PeerDisplayName,
    long TotalBytes,
    long BytesTransferred,
    DateTimeOffset CreatedAt,
    DateTimeOffset? CompletedAt,
    string? ErrorMessage);

public sealed record TransferProgress(
    string TransferId,
    string CurrentItem,
    long TotalBytes,
    long BytesTransferred,
    long BytesPerSecond,
    TransferStatus Status)
{
    public int Percent =>
        TotalBytes <= 0 ? 0 : (int)Math.Clamp(BytesTransferred * 100 / TotalBytes, 0, 100);
}
