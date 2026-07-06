namespace BeamDrop.Windows.Core;

public static class BeamDropProtocol
{
    public const string ProtocolVersion = "1.0";
    public const string ServiceName = "_beamdrop._tcp";
    public const int DefaultPort = 49320;
    public const int DefaultChunkSizeBytes = 4 * 1024 * 1024;
}

public enum BeamDropPlatform
{
    Android,
    Ios,
    Macos,
    Windows
}

public enum TransferKind
{
    Text,
    Url,
    File,
    ClipboardText
}

public enum TrustState
{
    Unknown,
    Trusted,
    Revoked
}

public enum TransferStatus
{
    Queued,
    WaitingForApproval,
    Transferring,
    Verifying,
    Completed,
    Failed,
    Cancelled,
    Rejected,
    Corrupted,
    Incomplete
}

public enum TransferDirection
{
    Sent,
    Received
}
