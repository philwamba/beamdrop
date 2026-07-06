using System.Security.Cryptography;
using BeamDrop.Windows.Core.Security;

namespace BeamDrop.Windows.Core.Identity;

public sealed record DeviceIdentity(
    string DeviceId,
    string DeviceName,
    BeamDropPlatform Platform,
    string PublicKeyBase64,
    string Fingerprint,
    string ProtocolVersion);

public interface IDeviceIdentityStore
{
    DeviceIdentity? LoadIdentity();
    void SaveIdentity(DeviceIdentity identity);
}

public sealed class InMemoryDeviceIdentityStore : IDeviceIdentityStore
{
    private DeviceIdentity? _identity;
    public DeviceIdentity? LoadIdentity() => _identity;
    public void SaveIdentity(DeviceIdentity identity) => _identity = identity;
}

public sealed class DeviceIdentityService
{
    private const string PrivateKeySecretName = "beamdrop.windows.device.private-key.v1";
    private readonly IDeviceIdentityStore _identityStore;
    private readonly ISecretStore _secretStore;

    public DeviceIdentityService(IDeviceIdentityStore identityStore, ISecretStore secretStore)
    {
        _identityStore = identityStore;
        _secretStore = secretStore;
    }

    public DeviceIdentity GetOrCreate(string deviceName)
    {
        var existing = _identityStore.LoadIdentity();
        if (existing is not null) return existing;

        using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var privateKey = ecdsa.ExportPkcs8PrivateKey();
        var publicKey = ecdsa.ExportSubjectPublicKeyInfo();
        _secretStore.Save(PrivateKeySecretName, privateKey);

        var identity = new DeviceIdentity(
            DeviceId: $"bd-windows-{Guid.NewGuid():N}",
            DeviceName: string.IsNullOrWhiteSpace(deviceName) ? Environment.MachineName : deviceName.Trim(),
            Platform: BeamDropPlatform.Windows,
            PublicKeyBase64: Convert.ToBase64String(publicKey),
            Fingerprint: Fingerprint.FromPublicKey(publicKey),
            ProtocolVersion: BeamDropProtocol.ProtocolVersion);
        _identityStore.SaveIdentity(identity);
        return identity;
    }

    public byte[]? LoadPrivateKeyForSigningBoundary() => _secretStore.Load(PrivateKeySecretName);
}
