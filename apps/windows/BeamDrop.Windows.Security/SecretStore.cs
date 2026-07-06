namespace BeamDrop.Windows.Security;

public interface ISecretStore
{
    ProtectedSecretHandle SaveSecret(string name, byte[] secret);
    byte[]? TryReadSecret(ProtectedSecretHandle handle);
    void DeleteSecret(ProtectedSecretHandle handle);
}

public sealed class InMemorySecretStore : ISecretStore
{
    private readonly Dictionary<string, byte[]> _secrets = new(StringComparer.Ordinal);

    public ProtectedSecretHandle SaveSecret(string name, byte[] secret)
    {
        _secrets[name] = secret.ToArray();
        return new ProtectedSecretHandle(name);
    }

    public byte[]? TryReadSecret(ProtectedSecretHandle handle) =>
        _secrets.TryGetValue(handle.Name, out var value) ? value.ToArray() : null;

    public void DeleteSecret(ProtectedSecretHandle handle) => _secrets.Remove(handle.Name);
}

public sealed class WindowsSecretStore : ISecretStore
{
    public ProtectedSecretHandle SaveSecret(string name, byte[] secret)
    {
        // Windows implementation point: use Windows Credential Locker for packaged apps
        // or DPAPI for unpackaged desktop hosts. The interface keeps private keys out of
        // SQLite and settings stores.
        throw new PlatformNotSupportedException("Wire this to Credential Locker or DPAPI in the Windows runtime host.");
    }

    public byte[]? TryReadSecret(ProtectedSecretHandle handle) =>
        throw new PlatformNotSupportedException("Wire this to Credential Locker or DPAPI in the Windows runtime host.");

    public void DeleteSecret(ProtectedSecretHandle handle) =>
        throw new PlatformNotSupportedException("Wire this to Credential Locker or DPAPI in the Windows runtime host.");
}
