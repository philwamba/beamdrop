using System.Security.Cryptography;

namespace BeamDrop.Windows.Security;

public sealed class DeviceIdentityService
{
    public const int ProtocolVersion = 1;
    private readonly ISecretStore _secretStore;

    public DeviceIdentityService(ISecretStore secretStore)
    {
        _secretStore = secretStore;
    }

    public DeviceIdentity CreateNew(string displayName)
    {
        using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var privateKey = key.ExportPkcs8PrivateKey();
        var publicKey = Convert.ToBase64String(key.ExportSubjectPublicKeyInfo());
        var handle = _secretStore.SaveSecret("beamdrop-windows-device-identity-v1", privateKey);
        CryptographicOperations.ZeroMemory(privateKey);

        return new DeviceIdentity(
            DeviceId: Guid.NewGuid().ToString("D"),
            DisplayName: displayName.Trim(),
            Platform: DevicePlatform.Windows,
            PublicKey: publicKey,
            ProtocolVersion: ProtocolVersion,
            PrivateKeyHandle: handle);
    }
}
