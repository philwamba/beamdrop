namespace BeamDrop.Windows.Core.Audit;

public enum AuditEventType
{
    PeerPaired,
    PeerRevoked,
    UnknownPeerRejected,
    RevokedPeerRejected,
    TransferQueued,
    TransferAccepted,
    TransferRejected,
    TransferCompleted,
    TransferFailed,
    ClipboardSendBlocked,
    ClipboardSendPaused
}

public sealed record AuditEvent(
    string EventId,
    AuditEventType Type,
    string? DeviceId,
    string? TransferId,
    DateTimeOffset CreatedAt,
    string Message);

public sealed class AuditLog
{
    private readonly List<AuditEvent> _events = new();

    public IReadOnlyList<AuditEvent> List() => _events.OrderByDescending(entry => entry.CreatedAt).ToList();

    public AuditEvent Add(AuditEventType type, string? deviceId, string? transferId, string message)
    {
        var entry = new AuditEvent($"audit-{Guid.NewGuid():N}", type, deviceId, transferId, DateTimeOffset.UtcNow, message);
        _events.Add(entry);
        return entry;
    }
}
