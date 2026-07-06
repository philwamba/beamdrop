namespace BeamDrop.Windows.Security;

public sealed record DeviceIdentity(
    string DeviceId,
    string DisplayName,
    DevicePlatform Platform,
    string PublicKey,
    int ProtocolVersion,
    ProtectedSecretHandle PrivateKeyHandle);

public sealed record ProtectedSecretHandle(string Name)
{
    public override string ToString() => Name;
}
