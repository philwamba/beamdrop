using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Agreement;
using Org.BouncyCastle.Crypto.Digests;
using Org.BouncyCastle.Crypto.Generators;
using Org.BouncyCastle.Crypto.Parameters;
using ChaCha20Poly1305 = Org.BouncyCastle.Crypto.Modes.ChaCha20Poly1305;

namespace BeamDrop.Windows.Core.Security;

/// <summary>
/// BeamDrop session protocol v1: X25519 key agreement + HKDF-SHA256 session key derivation
/// and ChaCha20-Poly1305 chunk sealing (RFC 8439). Matches the shared conformance vectors in
/// protocol/beamdrop-protocol/test-vectors/session-encryption-v1.json.
/// </summary>
public sealed class SessionCrypto
{
    public const string Scheme = "BEAMDROP_SESSION_V1";
    public const int RawKeySizeBytes = 32;
    public const int NonceSizeBytes = 12;
    public const int TagSizeBytes = 16;
    public const int SealOverheadBytes = NonceSizeBytes + TagSizeBytes;

    private const string SessionSaltLabel = "BeamDropSession-v1";
    private const string ChunkAadLabel = "beamdrop-chunk-v1";

    // DER SubjectPublicKeyInfo prefix for X25519: SEQUENCE { SEQUENCE { OID 1.3.101.110 }, BIT STRING }
    private static readonly byte[] X25519SpkiPrefix = { 0x30, 0x2A, 0x30, 0x05, 0x06, 0x03, 0x2B, 0x65, 0x6E, 0x03, 0x21, 0x00 };

    private readonly byte[] _sessionKey;
    private readonly string _senderDeviceId;
    private readonly string _receiverDeviceId;
    private readonly string _transferId;

    /// <summary>Raw 32-byte ephemeral public key advertised in the transfer envelope.</summary>
    public byte[] EphemeralPublicKey { get; }

    private SessionCrypto(byte[] sessionKey, byte[] ephemeralPublicKey, string senderDeviceId, string receiverDeviceId, string transferId)
    {
        _sessionKey = sessionKey;
        EphemeralPublicKey = ephemeralPublicKey;
        _senderDeviceId = senderDeviceId;
        _receiverDeviceId = receiverDeviceId;
        _transferId = transferId;
    }

    /// <summary>Sender side: derive the session from a fresh (or supplied) ephemeral key.</summary>
    public static SessionCrypto Initiate(
        byte[] senderStaticSecret,
        byte[] receiverStaticPublic,
        string senderDeviceId,
        string receiverDeviceId,
        string transferId,
        byte[]? ephemeralSecret = null)
    {
        ephemeralSecret ??= GenerateSecretKey();
        var ephemeralPublic = PublicKeyFromSecret(ephemeralSecret);
        var senderStaticPublic = PublicKeyFromSecret(senderStaticSecret);
        var dh1 = Agree(ephemeralSecret, receiverStaticPublic);
        var dh2 = Agree(senderStaticSecret, receiverStaticPublic);
        var sessionKey = DeriveSessionKey(dh1, dh2, senderDeviceId, receiverDeviceId, transferId, ephemeralPublic, senderStaticPublic, receiverStaticPublic);
        return new SessionCrypto(sessionKey, ephemeralPublic, senderDeviceId, receiverDeviceId, transferId);
    }

    /// <summary>Receiver side: derive the same session from the envelope's ephemeral public key.</summary>
    public static SessionCrypto Accept(
        byte[] receiverStaticSecret,
        byte[] ephemeralPublic,
        byte[] senderStaticPublic,
        string senderDeviceId,
        string receiverDeviceId,
        string transferId)
    {
        var receiverStaticPublic = PublicKeyFromSecret(receiverStaticSecret);
        var dh1 = Agree(receiverStaticSecret, ephemeralPublic);
        var dh2 = Agree(receiverStaticSecret, senderStaticPublic);
        var sessionKey = DeriveSessionKey(dh1, dh2, senderDeviceId, receiverDeviceId, transferId, ephemeralPublic, senderStaticPublic, receiverStaticPublic);
        return new SessionCrypto(sessionKey, ephemeralPublic, senderDeviceId, receiverDeviceId, transferId);
    }

    /// <summary>Seals one chunk: nonce(12) || ciphertext || tag(16).</summary>
    public byte[] SealChunk(long chunkIndex, ReadOnlySpan<byte> plaintext)
    {
        var nonce = ChunkNonce(chunkIndex);
        var cipher = CreateChunkCipher(forSealing: true, nonce, chunkIndex);
        var input = plaintext.ToArray();
        var output = new byte[NonceSizeBytes + cipher.GetOutputSize(input.Length)];
        nonce.CopyTo(output, 0);
        var written = cipher.ProcessBytes(input, 0, input.Length, output, NonceSizeBytes);
        cipher.DoFinal(output, NonceSizeBytes + written);
        return output;
    }

    /// <summary>Opens one sealed chunk, authenticating the tag; throws <see cref="SessionCryptoException"/> on failure.</summary>
    public byte[] OpenChunk(long chunkIndex, ReadOnlySpan<byte> sealedChunk)
    {
        if (sealedChunk.Length < SealOverheadBytes)
        {
            throw new SessionCryptoException("Sealed chunk is too short.");
        }
        var nonce = sealedChunk[..NonceSizeBytes].ToArray();
        if (!nonce.AsSpan().SequenceEqual(ChunkNonce(chunkIndex)))
        {
            throw new SessionCryptoException($"Sealed chunk nonce does not match chunk index {chunkIndex}.");
        }
        var cipher = CreateChunkCipher(forSealing: false, nonce, chunkIndex);
        var input = sealedChunk[NonceSizeBytes..].ToArray();
        var output = new byte[cipher.GetOutputSize(input.Length)];
        try
        {
            var written = cipher.ProcessBytes(input, 0, input.Length, output, 0);
            cipher.DoFinal(output, written);
        }
        catch (InvalidCipherTextException ex)
        {
            throw new SessionCryptoException($"Chunk {chunkIndex} failed authentication.", ex);
        }
        return output;
    }

    public static byte[] GenerateSecretKey() => RandomNumberGenerator.GetBytes(RawKeySizeBytes);

    public static byte[] PublicKeyFromSecret(byte[] secret)
    {
        if (secret is not { Length: RawKeySizeBytes })
        {
            throw new SessionCryptoException("An X25519 secret key must be 32 raw bytes.");
        }
        return new X25519PrivateKeyParameters(secret).GeneratePublicKey().GetEncoded();
    }

    /// <summary>Extracts the raw 32-byte X25519 public key from a base64 DER SPKI blob.</summary>
    public static byte[] RawPublicKeyFromSpkiBase64(string publicKeyBase64) =>
        TryRawPublicKeyFromSpkiBase64(publicKeyBase64, out var raw)
            ? raw
            : throw new SessionCryptoException("Public key is not a base64 DER SPKI X25519 key.");

    public static bool TryRawPublicKeyFromSpkiBase64(string? publicKeyBase64, out byte[] rawPublicKey)
    {
        rawPublicKey = Array.Empty<byte>();
        if (string.IsNullOrWhiteSpace(publicKeyBase64)) return false;
        Span<byte> der = stackalloc byte[64];
        if (!Convert.TryFromBase64String(publicKeyBase64.Trim(), der, out var derLength)) return false;
        if (derLength != X25519SpkiPrefix.Length + RawKeySizeBytes) return false;
        if (!der[..X25519SpkiPrefix.Length].SequenceEqual(X25519SpkiPrefix)) return false;
        rawPublicKey = der.Slice(X25519SpkiPrefix.Length, RawKeySizeBytes).ToArray();
        return true;
    }

    public static string SpkiBase64FromRawPublicKey(byte[] rawPublicKey)
    {
        if (rawPublicKey is not { Length: RawKeySizeBytes })
        {
            throw new SessionCryptoException("An X25519 public key must be 32 raw bytes.");
        }
        var der = new byte[X25519SpkiPrefix.Length + RawKeySizeBytes];
        X25519SpkiPrefix.CopyTo(der, 0);
        rawPublicKey.CopyTo(der, X25519SpkiPrefix.Length);
        return Convert.ToBase64String(der);
    }

    private static byte[] Agree(byte[] secret, byte[] publicKey)
    {
        if (secret is not { Length: RawKeySizeBytes }) throw new SessionCryptoException("An X25519 secret key must be 32 raw bytes.");
        if (publicKey is not { Length: RawKeySizeBytes }) throw new SessionCryptoException("An X25519 public key must be 32 raw bytes.");
        var agreement = new X25519Agreement();
        agreement.Init(new X25519PrivateKeyParameters(secret));
        var shared = new byte[agreement.AgreementSize];
        try
        {
            agreement.CalculateAgreement(new X25519PublicKeyParameters(publicKey), shared, 0);
        }
        catch (InvalidOperationException ex)
        {
            throw new SessionCryptoException("X25519 key agreement failed.", ex);
        }
        if (shared.All(value => value == 0))
        {
            throw new SessionCryptoException("X25519 key agreement produced an all-zero shared secret.");
        }
        return shared;
    }

    private static byte[] DeriveSessionKey(
        byte[] dh1,
        byte[] dh2,
        string senderDeviceId,
        string receiverDeviceId,
        string transferId,
        byte[] ephemeralPublic,
        byte[] senderStaticPublic,
        byte[] receiverStaticPublic)
    {
        var salt = SHA256.HashData(Concat(Encoding.UTF8.GetBytes(SessionSaltLabel), Encoding.UTF8.GetBytes(transferId)));
        var ikm = Concat(dh1, dh2);
        var info = Concat(
            Encoding.UTF8.GetBytes(senderDeviceId),
            new byte[] { 0x00 },
            Encoding.UTF8.GetBytes(receiverDeviceId),
            new byte[] { 0x00 },
            ephemeralPublic,
            senderStaticPublic,
            receiverStaticPublic);

        var hkdf = new HkdfBytesGenerator(new Sha256Digest());
        hkdf.Init(new HkdfParameters(ikm, salt, info));
        var sessionKey = new byte[RawKeySizeBytes];
        hkdf.GenerateBytes(sessionKey, 0, sessionKey.Length);
        return sessionKey;
    }

    private ChaCha20Poly1305 CreateChunkCipher(bool forSealing, byte[] nonce, long chunkIndex)
    {
        var aad = ChunkAad(chunkIndex);
        var cipher = new ChaCha20Poly1305();
        cipher.Init(forSealing, new AeadParameters(new KeyParameter(_sessionKey), TagSizeBytes * 8, nonce));
        cipher.ProcessAadBytes(aad, 0, aad.Length);
        return cipher;
    }

    private static byte[] ChunkNonce(long chunkIndex)
    {
        var nonce = new byte[NonceSizeBytes];
        nonce[0] = 0x01;
        BinaryPrimitives.WriteInt64BigEndian(nonce.AsSpan(4), chunkIndex);
        return nonce;
    }

    private byte[] ChunkAad(long chunkIndex)
    {
        var index = new byte[8];
        BinaryPrimitives.WriteInt64BigEndian(index, chunkIndex);
        return Concat(
            Encoding.UTF8.GetBytes(ChunkAadLabel),
            new byte[] { 0x00 },
            Encoding.UTF8.GetBytes(_senderDeviceId),
            new byte[] { 0x00 },
            Encoding.UTF8.GetBytes(_receiverDeviceId),
            new byte[] { 0x00 },
            Encoding.UTF8.GetBytes(_transferId),
            new byte[] { 0x00 },
            index);
    }

    private static byte[] Concat(params byte[][] parts)
    {
        var buffer = new byte[parts.Sum(part => part.Length)];
        var offset = 0;
        foreach (var part in parts)
        {
            part.CopyTo(buffer, offset);
            offset += part.Length;
        }
        return buffer;
    }
}

public sealed class SessionCryptoException : Exception
{
    public SessionCryptoException(string message) : base(message) { }
    public SessionCryptoException(string message, Exception innerException) : base(message, innerException) { }
}
