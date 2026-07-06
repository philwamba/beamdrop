using BeamDrop.Windows.Security;

namespace BeamDrop.Windows.Network;

public static class BeamDropDiscovery
{
    public const string ServiceType = "_beamdrop._tcp";
}

public sealed record EndpointHint(string Host, int Port, string Route = "local");

public sealed record NearbyDevice(
    string DeviceId,
    string DisplayName,
    DevicePlatform Platform,
    string PublicKey,
    EndpointHint Endpoint,
    TrustState TrustState);

public interface ILocalDiscoveryService
{
    Task<IReadOnlyList<NearbyDevice>> ScanAsync(CancellationToken cancellationToken);
}

public sealed class WindowsMdnsDiscoveryService : ILocalDiscoveryService
{
    public Task<IReadOnlyList<NearbyDevice>> ScanAsync(CancellationToken cancellationToken)
    {
        // Production implementation point: DNS-SD/mDNS browse for _beamdrop._tcp,
        // then validate identity through the pairing or trusted-session handshake.
        return Task.FromResult<IReadOnlyList<NearbyDevice>>(Array.Empty<NearbyDevice>());
    }
}
