using BeamDrop.Windows.Core.Security;

namespace BeamDrop.Windows.Core.Transfers;

/// <summary>The optional "encryption" block carried by the transfer envelope (camelCase on the wire).</summary>
public sealed record TransferEncryptionInfo(string Scheme, string EphemeralPublicKey);

public sealed record SenderSession(TransferEncryptionInfo Encryption, SessionCrypto Session);

/// <summary>
/// Derives per-transfer session ciphers from this device's static X25519 secret and a peer's
/// stored base64 DER SPKI X25519 public key.
/// </summary>
public sealed class SessionEncryptionService
{
    private readonly byte[] _localStaticSecret;

    public SessionEncryptionService(byte[] localStaticSecretKey)
    {
        if (localStaticSecretKey is not { Length: SessionCrypto.RawKeySizeBytes })
        {
            throw new ArgumentException("A 32-byte X25519 secret key is required.", nameof(localStaticSecretKey));
        }
        _localStaticSecret = localStaticSecretKey;
    }

    public string LocalPublicKeyBase64 =>
        SessionCrypto.SpkiBase64FromRawPublicKey(SessionCrypto.PublicKeyFromSecret(_localStaticSecret));

    /// <summary>
    /// Sender side. Returns null when the receiver's stored public key is not an X25519 SPKI key,
    /// in which case the transfer falls back to the legacy plaintext path.
    /// </summary>
    public SenderSession? TryCreateSenderSession(TransferManifest manifest, string receiverPublicKeyBase64)
    {
        if (!SessionCrypto.TryRawPublicKeyFromSpkiBase64(receiverPublicKeyBase64, out var receiverStaticPublic))
        {
            return null;
        }
        var session = SessionCrypto.Initiate(
            _localStaticSecret,
            receiverStaticPublic,
            manifest.SenderDeviceId,
            manifest.ReceiverDeviceId,
            manifest.TransferId);
        var encryption = new TransferEncryptionInfo(SessionCrypto.Scheme, Convert.ToHexString(session.EphemeralPublicKey).ToLowerInvariant());
        return new SenderSession(encryption, session);
    }

    /// <summary>Receiver side: derives the session from the envelope's ephemeral key and the trusted sender's stored public key.</summary>
    public SessionCrypto CreateReceiverSession(TransferManifest manifest, string senderPublicKeyBase64)
    {
        var encryption = manifest.Encryption ?? throw new SessionCryptoException("Transfer manifest carries no encryption block.");
        if (!string.Equals(encryption.Scheme, SessionCrypto.Scheme, StringComparison.Ordinal))
        {
            throw new SessionCryptoException($"Unsupported transfer encryption scheme: {encryption.Scheme}");
        }
        var ephemeralPublic = Convert.FromHexString(encryption.EphemeralPublicKey);
        var senderStaticPublic = SessionCrypto.RawPublicKeyFromSpkiBase64(senderPublicKeyBase64);
        return SessionCrypto.Accept(
            _localStaticSecret,
            ephemeralPublic,
            senderStaticPublic,
            manifest.SenderDeviceId,
            manifest.ReceiverDeviceId,
            manifest.TransferId);
    }
}

/// <summary>Read-only stream that seals plaintext chunks on the fly for the send path.</summary>
public sealed class ChunkSealingStream : Stream
{
    private readonly Stream _plaintext;
    private readonly SessionCrypto _session;
    private readonly long _plaintextSizeBytes;
    private readonly int _chunkSizeBytes;
    private readonly long _totalChunks;
    private byte[] _current = Array.Empty<byte>();
    private int _currentOffset;
    private long _nextChunk;

    public ChunkSealingStream(Stream plaintext, SessionCrypto session, long plaintextSizeBytes, int chunkSizeBytes)
    {
        _plaintext = plaintext;
        _session = session;
        _plaintextSizeBytes = plaintextSizeBytes;
        _chunkSizeBytes = chunkSizeBytes;
        _totalChunks = ChunkCalculator.TotalChunks(plaintextSizeBytes, chunkSizeBytes);
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        if (count == 0) return 0;
        if (_currentOffset >= _current.Length)
        {
            if (_nextChunk >= _totalChunks) return 0;
            var plaintextSize = ChunkPlaintextSize(_plaintextSizeBytes, _chunkSizeBytes, _nextChunk);
            var plaintext = ReadExactly(_plaintext, plaintextSize);
            var sealedChunk = _session.SealChunk(_nextChunk, plaintext);
            _current = new byte[sizeof(uint) + sealedChunk.Length];
            System.Buffers.Binary.BinaryPrimitives.WriteUInt32BigEndian(_current, (uint)sealedChunk.Length);
            sealedChunk.CopyTo(_current, sizeof(uint));
            _currentOffset = 0;
            _nextChunk++;
        }
        var read = Math.Min(count, _current.Length - _currentOffset);
        Array.Copy(_current, _currentOffset, buffer, offset, read);
        _currentOffset += read;
        return read;
    }

    internal static int ChunkPlaintextSize(long sizeBytes, int chunkSizeBytes, long chunkIndex)
    {
        if (sizeBytes == 0) return 0;
        return (int)Math.Min(chunkSizeBytes, sizeBytes - (chunkIndex * chunkSizeBytes));
    }

    private static byte[] ReadExactly(Stream stream, int size)
    {
        var buffer = new byte[size];
        var filled = 0;
        while (filled < size)
        {
            var read = stream.Read(buffer, filled, size - filled);
            if (read == 0) throw new EndOfStreamException("Plaintext payload ended before all chunks were sealed.");
            filled += read;
        }
        return buffer;
    }

    public override bool CanRead => true;
    public override bool CanSeek => false;
    public override bool CanWrite => false;
    public override long Length => throw new NotSupportedException();
    public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
    public override void Flush() { }
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}

/// <summary>Read-only stream that opens sealed chunks on the fly for the receive path.</summary>
public sealed class ChunkOpeningStream : Stream
{
    private readonly Stream _sealedPayload;
    private readonly SessionCrypto _session;
    private readonly long _plaintextSizeBytes;
    private readonly int _chunkSizeBytes;
    private readonly long _totalChunks;
    private byte[] _current = Array.Empty<byte>();
    private int _currentOffset;
    private long _nextChunk;

    public ChunkOpeningStream(Stream sealedPayload, SessionCrypto session, long plaintextSizeBytes, int chunkSizeBytes)
    {
        _sealedPayload = sealedPayload;
        _session = session;
        _plaintextSizeBytes = plaintextSizeBytes;
        _chunkSizeBytes = chunkSizeBytes;
        _totalChunks = ChunkCalculator.TotalChunks(plaintextSizeBytes, chunkSizeBytes);
    }

    public override int Read(byte[] buffer, int offset, int count)
    {
        while (_currentOffset >= _current.Length)
        {
            if (_nextChunk >= _totalChunks) return 0;
            var header = ReadSealedChunk(sizeof(uint), allowEndOfStream: true);
            if (header is null) return 0;
            var sealedSize = System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(header);
            var expectedSize = ChunkSealingStream.ChunkPlaintextSize(_plaintextSizeBytes, _chunkSizeBytes, _nextChunk) + SessionCrypto.SealOverheadBytes;
            if (sealedSize != expectedSize)
            {
                throw new SessionCryptoException($"Sealed chunk {_nextChunk} frame is {sealedSize} bytes but the manifest expects {expectedSize}.");
            }
            var sealedChunk = ReadSealedChunk((int)sealedSize, allowEndOfStream: false)!;
            _current = _session.OpenChunk(_nextChunk, sealedChunk);
            _currentOffset = 0;
            _nextChunk++;
        }
        var read = Math.Min(count, _current.Length - _currentOffset);
        Array.Copy(_current, _currentOffset, buffer, offset, read);
        _currentOffset += read;
        return read;
    }

    private byte[]? ReadSealedChunk(int size, bool allowEndOfStream)
    {
        var buffer = new byte[size];
        var filled = 0;
        while (filled < size)
        {
            var read = _sealedPayload.Read(buffer, filled, size - filled);
            if (read == 0)
            {
                if (filled == 0 && allowEndOfStream) return null;
                throw new EndOfStreamException("Encrypted payload ended in the middle of a sealed chunk.");
            }
            filled += read;
        }
        return buffer;
    }

    public override bool CanRead => true;
    public override bool CanSeek => false;
    public override bool CanWrite => false;
    public override long Length => throw new NotSupportedException();
    public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
    public override void Flush() { }
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
}
