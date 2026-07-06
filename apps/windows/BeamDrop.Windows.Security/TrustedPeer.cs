using System.Security.Cryptography;
using System.Text;

namespace BeamDrop.Windows.Security;

public sealed record TrustedPeer(
    string DeviceId,
    string DisplayName,
    DevicePlatform Platform,
    string PublicKey,
    string Fingerprint,
    TrustState TrustState,
    DateTimeOffset? TrustedAt,
    DateTimeOffset? RevokedAt,
    DateTimeOffset? LastSeenAt)
{
    public bool CanTransfer(string publicKey) =>
        TrustState == TrustState.Trusted && string.Equals(PublicKey, publicKey, StringComparison.Ordinal);

    public TrustedPeer Revoke(DateTimeOffset now) =>
        this with { TrustState = TrustState.Revoked, RevokedAt = now };

    public static TrustedPeer CreateTrusted(
        string deviceId,
        string displayName,
        DevicePlatform platform,
        string publicKey,
        DateTimeOffset now) =>
        new(
            deviceId,
            displayName,
            platform,
            publicKey,
            PeerFingerprint.FromPublicKey(publicKey),
            TrustState.Trusted,
            now,
            null,
            now);
}

public static class PeerFingerprint
{
    public static string FromPublicKey(string publicKey)
    {
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(publicKey));
        return string.Join(":", hash.Take(8).Select(value => value.ToString("X2")));
    }
}
