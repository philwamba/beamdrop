using BeamDrop.Windows.Core.Audit;
using BeamDrop.Windows.Core.Pairing;

namespace BeamDrop.Windows.Core.Peers;

public sealed record TrustedPeer(
    string DeviceId,
    string DeviceName,
    BeamDropPlatform Platform,
    string PublicKeyBase64,
    string Fingerprint,
    TrustState TrustState,
    bool AutoAcceptTransfers,
    string? EndpointHost,
    int? EndpointPort,
    DateTimeOffset TrustedAt,
    DateTimeOffset? RevokedAt,
    DateTimeOffset? LastSeenAt);

public interface ITrustedPeerStore
{
    IReadOnlyList<TrustedPeer> List();
    TrustedPeer? Get(string deviceId);
    void Upsert(TrustedPeer peer);
}

public sealed class InMemoryTrustedPeerStore : ITrustedPeerStore
{
    private readonly Dictionary<string, TrustedPeer> _peers = new(StringComparer.Ordinal);
    public IReadOnlyList<TrustedPeer> List() => _peers.Values.OrderBy(peer => peer.DeviceName).ToList();
    public TrustedPeer? Get(string deviceId) => _peers.TryGetValue(deviceId, out var peer) ? peer : null;
    public void Upsert(TrustedPeer peer) => _peers[peer.DeviceId] = peer;
}

public sealed class TrustedPeerRepository
{
    private readonly ITrustedPeerStore _store;
    private readonly AuditLog _auditLog;

    public TrustedPeerRepository(ITrustedPeerStore store, AuditLog auditLog)
    {
        _store = store;
        _auditLog = auditLog;
    }

    public IReadOnlyList<TrustedPeer> List() => _store.List();

    public TrustedPeer? Get(string deviceId) => _store.Get(deviceId);

    public TrustedPeer Approve(PairingRequest request, bool autoAcceptTransfers = false)
    {
        var payload = request.RemotePayload;
        var existing = _store.Get(payload.DeviceId);
        if (existing?.TrustState == TrustState.Revoked) throw new InvalidOperationException("Revoked devices must be paired deliberately before trust is restored.");

        var peer = new TrustedPeer(
            payload.DeviceId,
            payload.DeviceName,
            payload.Platform,
            payload.PublicKeyBase64,
            payload.Fingerprint,
            TrustState.Trusted,
            autoAcceptTransfers,
            payload.HostName,
            payload.Port,
            DateTimeOffset.UtcNow,
            null,
            request.ReceivedAt);
        _store.Upsert(peer);
        _auditLog.Add(AuditEventType.PeerPaired, peer.DeviceId, null, $"Trusted {peer.DeviceName}.");
        return peer;
    }

    public void Revoke(string deviceId)
    {
        var peer = _store.Get(deviceId) ?? throw new InvalidOperationException("Trusted peer not found.");
        var revoked = peer with { TrustState = TrustState.Revoked, RevokedAt = DateTimeOffset.UtcNow };
        _store.Upsert(revoked);
        _auditLog.Add(AuditEventType.PeerRevoked, deviceId, null, $"Revoked {peer.DeviceName}.");
    }

    public TransferPeer RequireTrusted(string deviceId)
    {
        var peer = _store.Get(deviceId);
        if (peer is null || peer.TrustState == TrustState.Unknown)
        {
            _auditLog.Add(AuditEventType.UnknownPeerRejected, deviceId, null, "Unknown peer rejected.");
            throw new UnknownPeerRejectedException(deviceId);
        }
        if (peer.TrustState == TrustState.Revoked)
        {
            _auditLog.Add(AuditEventType.RevokedPeerRejected, deviceId, null, "Revoked peer rejected.");
            throw new RevokedPeerRejectedException(deviceId);
        }
        return new TransferPeer(peer.DeviceId, peer.DeviceName, peer.PublicKeyBase64, peer.AutoAcceptTransfers);
    }
}

public sealed record TransferPeer(string DeviceId, string DeviceName, string PublicKeyBase64, bool AutoAcceptTransfers);

public sealed class UnknownPeerRejectedException : Exception
{
    public UnknownPeerRejectedException(string deviceId) : base($"Unknown peer rejected: {deviceId}") { }
}

public sealed class RevokedPeerRejectedException : Exception
{
    public RevokedPeerRejectedException(string deviceId) : base($"Revoked peer rejected: {deviceId}") { }
}
