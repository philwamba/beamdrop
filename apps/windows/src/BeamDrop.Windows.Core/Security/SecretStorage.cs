using System.Security.Cryptography;
using System.Text;

namespace BeamDrop.Windows.Core.Security;

public interface ISecretProtector
{
    byte[] Protect(byte[] plaintext);
    byte[] Unprotect(byte[] protectedBytes);
}

public interface ISecretStore
{
    void Save(string key, byte[] plaintext);
    byte[]? Load(string key);
    void Delete(string key);
}

public sealed class ProtectedSecretStore : ISecretStore
{
    private readonly ISecretProtector _protector;
    private readonly Dictionary<string, byte[]> _protectedSecrets = new(StringComparer.Ordinal);

    public ProtectedSecretStore(ISecretProtector protector)
    {
        _protector = protector;
    }

    public void Save(string key, byte[] plaintext)
    {
        if (string.IsNullOrWhiteSpace(key)) throw new ArgumentException("Secret key is required.", nameof(key));
        _protectedSecrets[key] = _protector.Protect(plaintext);
    }

    public byte[]? Load(string key) =>
        _protectedSecrets.TryGetValue(key, out var value) ? _protector.Unprotect(value) : null;

    public void Delete(string key) => _protectedSecrets.Remove(key);
}

public sealed class AesLocalSecretProtector : ISecretProtector
{
    private readonly byte[] _key;

    public AesLocalSecretProtector(byte[] key)
    {
        if (key.Length != 32) throw new ArgumentException("A 256-bit key is required.", nameof(key));
        _key = key;
    }

    public byte[] Protect(byte[] plaintext)
    {
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.GenerateIV();
        using var encryptor = aes.CreateEncryptor();
        var ciphertext = encryptor.TransformFinalBlock(plaintext, 0, plaintext.Length);
        return aes.IV.Concat(ciphertext).ToArray();
    }

    public byte[] Unprotect(byte[] protectedBytes)
    {
        if (protectedBytes.Length < 17) throw new CryptographicException("Protected payload is invalid.");
        var iv = protectedBytes.Take(16).ToArray();
        var ciphertext = protectedBytes.Skip(16).ToArray();
        using var aes = Aes.Create();
        aes.Key = _key;
        aes.IV = iv;
        using var decryptor = aes.CreateDecryptor();
        return decryptor.TransformFinalBlock(ciphertext, 0, ciphertext.Length);
    }
}

public sealed class WindowsSecureStoragePlan
{
    public string PreferredProvider => "Windows Credential Locker";
    public string FallbackProvider => "DPAPI CurrentUser";
    public string PrivateKeyStorageRule =>
        "BeamDrop stores private key material only through an ISecretStore implementation backed by Credential Locker or DPAPI on Windows; app code receives handles or decrypted bytes only inside the key service boundary.";
}

public static class Fingerprint
{
    public static string FromPublicKey(byte[] publicKey)
    {
        var hash = SHA256.HashData(publicKey);
        return string.Join(" ", hash.Take(6).Select(value => value.ToString("X2")));
    }

    public static string Sha256Hex(Stream input)
    {
        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(input);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    public static string Sha256Hex(byte[] payload) => Convert.ToHexString(SHA256.HashData(payload)).ToLowerInvariant();
}
