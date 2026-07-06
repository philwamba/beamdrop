using BeamDrop.Windows.Security;
using BeamDrop.Windows.Transfer;

namespace BeamDrop.Windows.Persistence;

public interface ITrustedPeerRepository
{
    IReadOnlyList<TrustedPeer> List();
    TrustedPeer? Get(string deviceId);
    void Upsert(TrustedPeer peer);
    bool Revoke(string deviceId, DateTimeOffset now);
}

public interface ITransferRepository
{
    IReadOnlyList<TransferRecord> List();
    void Upsert(TransferRecord transfer);
}

public interface ISettingsRepository
{
    string? Get(string key);
    void Set(string key, string value, DateTimeOffset now);
    IReadOnlyDictionary<string, string> List();
}

public interface IAuditEventRepository
{
    IReadOnlyList<AuditEvent> List();
    void Add(AuditEvent auditEvent);
}

public sealed record AuditEvent(
    string EventId,
    string Category,
    string Message,
    DateTimeOffset CreatedAt,
    string? PeerDeviceId);

public sealed class InMemoryTrustedPeerRepository : ITrustedPeerRepository
{
    private readonly Dictionary<string, TrustedPeer> _peers = new(StringComparer.Ordinal);

    public IReadOnlyList<TrustedPeer> List() => _peers.Values.OrderBy(peer => peer.DisplayName).ToArray();

    public TrustedPeer? Get(string deviceId) =>
        _peers.TryGetValue(deviceId, out var peer) ? peer : null;

    public void Upsert(TrustedPeer peer) => _peers[peer.DeviceId] = peer;

    public bool Revoke(string deviceId, DateTimeOffset now)
    {
        if (!_peers.TryGetValue(deviceId, out var peer))
        {
            return false;
        }

        _peers[deviceId] = peer.Revoke(now);
        return true;
    }
}

public sealed class InMemoryTransferRepository : ITransferRepository
{
    private readonly Dictionary<string, TransferRecord> _transfers = new(StringComparer.Ordinal);

    public IReadOnlyList<TransferRecord> List() =>
        _transfers.Values.OrderByDescending(transfer => transfer.CreatedAt).ToArray();

    public void Upsert(TransferRecord transfer) => _transfers[transfer.TransferId] = transfer;
}

public sealed class InMemorySettingsRepository : ISettingsRepository
{
    private readonly Dictionary<string, string> _settings = new(StringComparer.Ordinal);

    public string? Get(string key) => _settings.TryGetValue(key, out var value) ? value : null;

    public void Set(string key, string value, DateTimeOffset now) => _settings[key] = value;

    public IReadOnlyDictionary<string, string> List() => new Dictionary<string, string>(_settings);
}

public sealed class InMemoryAuditEventRepository : IAuditEventRepository
{
    private readonly List<AuditEvent> _events = new();

    public IReadOnlyList<AuditEvent> List() => _events.OrderByDescending(item => item.CreatedAt).ToArray();

    public void Add(AuditEvent auditEvent) => _events.Add(auditEvent);
}
