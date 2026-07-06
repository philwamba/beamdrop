using System.Text;
using BeamDrop.Windows.Core;
using BeamDrop.Windows.Core.Audit;
using BeamDrop.Windows.Core.Clipboard;
using BeamDrop.Windows.Core.Identity;
using BeamDrop.Windows.Core.Pairing;
using BeamDrop.Windows.Core.Peers;
using BeamDrop.Windows.Core.Security;
using BeamDrop.Windows.Core.Transfers;

var tests = new WindowsTests();
await tests.RunAll();

internal sealed class WindowsTests
{
    public async Task RunAll()
    {
        TestDeviceIdentityGeneration();
        TestChunkedTransfer();
        TestHashVerification();
        TestPairingQrCompatibility();
        TestTransferEnvelopeCodec();
        TestTransferEnvelopeDecodesAndroidEnvelope();
        await TestTransferManagerSendText();
        await TestReceiveFileHashVerification();
        TestTrustedPeerRejection();
        await TestClipboardPolicy();
        TestResumePlanning();
        Console.WriteLine("BeamDrop Windows tests passed.");
    }

    private static void TestDeviceIdentityGeneration()
    {
        var secretStore = new ProtectedSecretStore(new AesLocalSecretProtector(Enumerable.Repeat((byte)7, 32).ToArray()));
        var service = new DeviceIdentityService(new InMemoryDeviceIdentityStore(), secretStore);

        var identity = service.GetOrCreate("Windows Workstation");

        AssertEqual(BeamDropPlatform.Windows, identity.Platform, "identity platform");
        AssertTrue(identity.DeviceId.StartsWith("bd-windows-"), "identity device id prefix");
        AssertTrue(service.LoadPrivateKeyForSigningBoundary() is { Length: > 0 }, "protected private key loads through service boundary");
    }

    private static void TestChunkedTransfer()
    {
        var plan = ChunkCalculator.Plan((BeamDropProtocol.DefaultChunkSizeBytes * 2L) + 3);

        AssertEqual(3L, plan.TotalChunks, "large file total chunks");
        AssertEqual(BeamDropProtocol.DefaultChunkSizeBytes, plan.Chunks[0].SizeBytes, "first chunk size");
        AssertEqual(3, plan.Chunks[2].SizeBytes, "tail chunk size");
    }

    private static void TestHashVerification()
    {
        var payload = Encoding.UTF8.GetBytes("BeamDrop Windows");
        var hash = Fingerprint.Sha256Hex(payload);

        AssertEqual(hash, Fingerprint.Sha256Hex(new MemoryStream(payload)), "sha256 stream matches bytes");
    }

    private static void TestPairingQrCompatibility()
    {
        var service = new PairingService();
        var expiresAt = DateTimeOffset.UtcNow.AddMinutes(5).ToUnixTimeMilliseconds();
        var request = service.ImportFromQrOrText(
            $$"""
            {
              "type": "beamdrop_pairing",
              "protocolVersion": "1.0",
              "serviceName": "_beamdrop._tcp",
              "pairingSessionId": "pair-android",
              "deviceId": "bd-android-01",
              "deviceName": "Pixel BeamDrop",
              "platform": "android",
              "publicKey": "android-public-key",
              "endpoint": {
                "host": "192.0.2.20",
                "port": 49320,
                "route": "local"
              },
              "expiresAtEpochMillis": {{expiresAt}}
            }
            """);

        AssertEqual("bd-android-01", request.RemotePayload.DeviceId, "android qr device id");
        AssertEqual("Pixel BeamDrop", request.RemotePayload.DeviceName, "android qr device name");
        AssertEqual(BeamDropPlatform.Android, request.RemotePayload.Platform, "android qr platform");
        AssertEqual("android-public-key", request.RemotePayload.PublicKey, "android qr public key");
        AssertEqual(49320, request.RemotePayload.Endpoint!.Port, "android qr endpoint port");
    }

    private static void TestTransferEnvelopeCodec()
    {
        var manifest = new TransferManifest(
            TransferId: "tx-codec",
            Kind: TransferKind.File,
            SenderDeviceId: "bd-windows-sender",
            ReceiverDeviceId: "bd-android-receiver",
            FileName: "demo.txt",
            MimeType: "text/plain",
            SizeBytes: 8,
            ChunkSizeBytes: BeamDropProtocol.DefaultChunkSizeBytes,
            TotalChunks: 1,
            Sha256: new string('f', 64),
            CreatedAt: DateTimeOffset.Parse("2026-07-06T14:27:18Z"),
            SenderPublicKey: "windows-public-key");

        var decoded = TransferEnvelopeCodec.Decode(TransferEnvelopeCodec.Encode(manifest));

        AssertEqual("bd-windows-sender", decoded.SenderDeviceId, "wire sender device id");
        AssertEqual("windows-public-key", decoded.SenderPublicKey, "wire sender public key");
        AssertEqual("bd-android-receiver", decoded.ReceiverDeviceId, "wire receiver device id");
        AssertEqual(TransferKind.File, decoded.Kind, "wire transfer type");
        AssertEqual(BeamDropProtocol.DefaultChunkSizeBytes, decoded.ChunkSizeBytes, "wire chunk size");
    }

    private static void TestTransferEnvelopeDecodesAndroidEnvelope()
    {
        var decoded = TransferEnvelopeCodec.Decode(
            """
            {
              "protocolVersion": "1.0",
              "transferId": "tx-android",
              "transferType": "TEXT",
              "senderDeviceId": "bd-android-01",
              "senderPublicKey": "android-public-key",
              "receiverDeviceId": "bd-windows-01",
              "createdAt": "2026-07-06T14:27:18Z",
              "payloadMetadata": {
                "fileName": "Text",
                "mimeType": "text/plain",
                "sizeBytes": 5,
                "chunkSize": 4194304,
                "totalChunks": 1,
                "sha256": "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
              }
            }
            """);

        AssertEqual("tx-android", decoded.TransferId, "android envelope transfer id");
        AssertEqual(TransferKind.Text, decoded.Kind, "android envelope transfer kind");
        AssertEqual("bd-android-01", decoded.SenderDeviceId, "android envelope sender");
        AssertEqual("android-public-key", decoded.SenderPublicKey, "android envelope public key");
        AssertEqual(BeamDropProtocol.DefaultChunkSizeBytes, decoded.ChunkSizeBytes, "android envelope chunk size");
    }

    private static async Task TestTransferManagerSendText()
    {
        var fixture = Fixture(trustState: TrustState.Trusted);
        using var sink = new MemoryStream();
        var record = await fixture.Manager.SendTextAsync(PeerId, "hello", new StreamCopyTransferTransport(sink), CancellationToken.None);

        AssertEqual(TransferStatus.Completed, record.Status, "send text completed");
        AssertEqual("hello", Encoding.UTF8.GetString(sink.ToArray()), "text payload copied");
    }

    private static async Task TestReceiveFileHashVerification()
    {
        var fixture = Fixture(trustState: TrustState.Trusted, approval: ReceiveDecision.Accept);
        var payload = Encoding.UTF8.GetBytes("file payload");
        var manifest = Manifest(size: payload.Length, sha: Fingerprint.Sha256Hex(payload));

        var record = await fixture.Manager.ReceiveFileAsync(
            new IncomingTransferRequest(manifest, new TransferPeer(PeerId, "Laptop", PublicKey, AutoAcceptTransfers: true)),
            new MemoryStream(payload),
            CancellationToken.None);

        AssertEqual(TransferStatus.Completed, record.Status, "receive file completed");
    }

    private static void TestTrustedPeerRejection()
    {
        var unknown = Fixture(trustState: null);
        AssertThrows<UnknownPeerRejectedException>(() => unknown.Repository.RequireTrusted(PeerId), "unknown peer rejected");

        var revoked = Fixture(trustState: TrustState.Revoked);
        AssertThrows<RevokedPeerRejectedException>(() => revoked.Repository.RequireTrusted(PeerId), "revoked peer rejected");

        var wrongKey = Fixture(trustState: TrustState.Trusted);
        AssertThrows<UnknownPeerRejectedException>(() => wrongKey.Repository.RequireTrusted(PeerId, "wrong-public-key"), "mismatched trusted peer key rejected");
    }

    private static async Task TestClipboardPolicy()
    {
        var fixture = Fixture(trustState: TrustState.Trusted);
        var reader = new StaticClipboardReader("password=abc123456789");
        var clipboard = new ClipboardSharingService(reader, fixture.Manager, fixture.AuditLog);
        clipboard.SetSharingEnabled(true);

        var blocked = await clipboard.SendClipboardFromTrayAsync(PeerId, new StreamCopyTransferTransport(new MemoryStream()), CancellationToken.None);
        AssertFalse(blocked.Sent, "sensitive clipboard blocked");

        clipboard.PauseSharing(true);
        var paused = await clipboard.SendClipboardFromTrayAsync(PeerId, new StreamCopyTransferTransport(new MemoryStream()), CancellationToken.None);
        AssertEqual("Clipboard sharing is paused.", paused.Message, "clipboard pause status");
    }

    private static void TestResumePlanning()
    {
        var plan = ResumePlanner.Plan("tx-1", 5, new long[] { 0, 2, 4 });
        AssertEqual(2, plan.MissingChunks.Count, "resume missing chunk count");
        AssertTrue(plan.MissingChunks.SequenceEqual(new long[] { 1, 3 }), "resume missing chunks");
    }

    private static TestFixture Fixture(TrustState? trustState, ReceiveDecision approval = ReceiveDecision.Accept)
    {
        var audit = new AuditLog();
        var store = new InMemoryTrustedPeerStore();
        if (trustState is not null)
        {
            store.Upsert(new TrustedPeer(
                DeviceId: PeerId,
                DeviceName: "Laptop",
                Platform: BeamDropPlatform.Windows,
                PublicKeyBase64: PublicKey,
                Fingerprint: "AA BB CC DD EE FF",
                TrustState: trustState.Value,
                AutoAcceptTransfers: approval == ReceiveDecision.Accept,
                EndpointHost: "127.0.0.1",
                EndpointPort: 49320,
                TrustedAt: DateTimeOffset.UtcNow,
                RevokedAt: trustState == TrustState.Revoked ? DateTimeOffset.UtcNow : null,
                LastSeenAt: DateTimeOffset.UtcNow));
        }
        var repository = new TrustedPeerRepository(store, audit);
        var manager = new TransferManager(repository, new InMemoryTransferHistoryStore(), new MemoryReceiveTargetFactory(), new FixedApprovalPrompt(approval), audit);
        return new TestFixture(repository, manager, audit);
    }

    private static TransferManifest Manifest(int size, string sha) =>
        new("tx-test", TransferKind.File, PeerId, "this-windows-device", "notes.txt", "text/plain", size, BeamDropProtocol.DefaultChunkSizeBytes, ChunkCalculator.TotalChunks(size), sha, DateTimeOffset.UtcNow);

    private static void AssertTrue(bool value, string name)
    {
        if (!value) throw new Exception($"Assertion failed: {name}");
    }

    private static void AssertFalse(bool value, string name) => AssertTrue(!value, name);

    private static void AssertEqual<T>(T expected, T actual, string name)
    {
        if (!EqualityComparer<T>.Default.Equals(expected, actual))
        {
            throw new Exception($"Assertion failed: {name}. Expected {expected}, got {actual}.");
        }
    }

    private static void AssertThrows<TException>(Action action, string name) where TException : Exception
    {
        try
        {
            action();
        }
        catch (TException)
        {
            return;
        }
        throw new Exception($"Assertion failed: {name}. Expected {typeof(TException).Name}.");
    }

    private const string PeerId = "bd-windows-peer";
    private const string PublicKey = "public-key";
}

internal sealed record TestFixture(TrustedPeerRepository Repository, TransferManager Manager, AuditLog AuditLog);

internal sealed class FixedApprovalPrompt : IReceiveApprovalPrompt
{
    private readonly ReceiveDecision _decision;
    public FixedApprovalPrompt(ReceiveDecision decision) => _decision = decision;
    public ReceiveDecision Decide(IncomingTransferRequest request) => _decision;
}

internal sealed class StaticClipboardReader : IClipboardReader
{
    private readonly string _text;
    public StaticClipboardReader(string text) => _text = text;
    public string? ReadText() => _text;
}

internal sealed class MemoryReceiveTargetFactory : IReceiveTargetFactory
{
    public IReceiveTarget Create(TransferManifest manifest) => new MemoryReceiveTarget();
}

internal sealed class MemoryReceiveTarget : IReceiveTarget
{
    private readonly MemoryStream _stream = new();
    public Stream OpenWrite()
    {
        _stream.SetLength(0);
        return new NonClosingStream(_stream);
    }

    public Stream OpenReadForVerification()
    {
        _stream.Position = 0;
        return new NonClosingStream(_stream);
    }

    public string CommitVerified() => "memory";
    public void Discard() => _stream.SetLength(0);
}

internal sealed class NonClosingStream : Stream
{
    private readonly Stream _inner;
    public NonClosingStream(Stream inner) => _inner = inner;
    public override bool CanRead => _inner.CanRead;
    public override bool CanSeek => _inner.CanSeek;
    public override bool CanWrite => _inner.CanWrite;
    public override long Length => _inner.Length;
    public override long Position { get => _inner.Position; set => _inner.Position = value; }
    public override void Flush() => _inner.Flush();
    public override int Read(byte[] buffer, int offset, int count) => _inner.Read(buffer, offset, count);
    public override long Seek(long offset, SeekOrigin origin) => _inner.Seek(offset, origin);
    public override void SetLength(long value) => _inner.SetLength(value);
    public override void Write(byte[] buffer, int offset, int count) => _inner.Write(buffer, offset, count);
}
