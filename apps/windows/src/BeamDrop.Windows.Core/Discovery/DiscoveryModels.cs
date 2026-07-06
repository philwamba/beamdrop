using BeamDrop.Windows.Core.Identity;

namespace BeamDrop.Windows.Core.Discovery;

public sealed record DeviceAdvertisement(
    string ProtocolVersion,
    string ServiceName,
    string DeviceId,
    string DeviceName,
    BeamDropPlatform Platform,
    string PublicKeyBase64,
    IReadOnlySet<TransferKind> Features,
    int Port);

public sealed record DiscoveryRecord(
    DeviceAdvertisement Advertisement,
    string HostName,
    int Port,
    DateTimeOffset LastSeen);

public sealed record ManualConnectionEndpoint(string HostName, int Port);

public interface ILocalDiscoveryService
{
    Task PublishAsync(DeviceAdvertisement advertisement, CancellationToken cancellationToken);
    Task<IReadOnlyList<DiscoveryRecord>> DiscoverAsync(TimeSpan timeout, CancellationToken cancellationToken);
}

public sealed class InMemoryDiscoveryService : ILocalDiscoveryService
{
    private readonly List<DiscoveryRecord> _records = new();

    public Task PublishAsync(DeviceAdvertisement advertisement, CancellationToken cancellationToken)
    {
        ValidateAdvertisement(advertisement);
        _records.RemoveAll(record => record.Advertisement.DeviceId == advertisement.DeviceId);
        _records.Add(new DiscoveryRecord(advertisement, Environment.MachineName, advertisement.Port, DateTimeOffset.UtcNow));
        return Task.CompletedTask;
    }

    public Task<IReadOnlyList<DiscoveryRecord>> DiscoverAsync(TimeSpan timeout, CancellationToken cancellationToken) =>
        Task.FromResult<IReadOnlyList<DiscoveryRecord>>(_records.ToList());

    public static void ValidateAdvertisement(DeviceAdvertisement advertisement)
    {
        if (advertisement.ProtocolVersion != BeamDropProtocol.ProtocolVersion) throw new InvalidOperationException("Unsupported BeamDrop protocol version.");
        if (advertisement.ServiceName != BeamDropProtocol.ServiceName) throw new InvalidOperationException("Discovery service name must be _beamdrop._tcp.");
        if (string.IsNullOrWhiteSpace(advertisement.DeviceId)) throw new InvalidOperationException("Device id is required.");
        if (string.IsNullOrWhiteSpace(advertisement.PublicKeyBase64)) throw new InvalidOperationException("Public key is required.");
        if (advertisement.Port is <= 0 or > 65535) throw new InvalidOperationException("Port is invalid.");
    }
}

public static class DiscoveryFactory
{
    public static DeviceAdvertisement FromIdentity(DeviceIdentity identity, int port = BeamDropProtocol.DefaultPort) =>
        new(
            ProtocolVersion: BeamDropProtocol.ProtocolVersion,
            ServiceName: BeamDropProtocol.ServiceName,
            DeviceId: identity.DeviceId,
            DeviceName: identity.DeviceName,
            Platform: identity.Platform,
            PublicKeyBase64: identity.PublicKeyBase64,
            Features: new HashSet<TransferKind>
            {
                TransferKind.Text,
                TransferKind.Url,
                TransferKind.File,
                TransferKind.ClipboardText
            },
            Port: port);
}
