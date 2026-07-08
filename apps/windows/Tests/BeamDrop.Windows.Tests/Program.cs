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
        TestTamperedTransferEnvelopeRejected();
        await TestTransferManagerSendText();
        await TestReceiveFileHashVerification();
        await TestReceiveMissingHashCannotComplete();
        TestTrustedPeerRejection();
        TestPathTraversalFileNameRejected();
        TestReceivedFileNameTraversalVariantsRejected();
        await TestClipboardPolicy();
        TestResumePlanning();
        TestSessionKeyConformanceVector();
        TestChunkSealConformanceVectors();
        TestSessionCryptoRejectsTamperedChunk();
        TestSessionCryptoRejectsAllZeroSharedSecret();
        TestChunkStreamsRoundTripMultiChunk();
        TestSpkiKeyHelpers();
        TestTransferEnvelopeEncryptionRoundTrip();
        TestTransferEnvelopeRejectsInvalidEncryptionBlock();
        await TestEncryptedTransferEndToEnd();
        await TestEncryptedTransferAuthFailureFailsTransfer();
        await TestEncryptedTransferWithoutSessionServiceFails();
        await TestLegacyPlaintextTransferStillWorksAndIsLogged();
        TestDpapiProtectorRoundTrip();
        TestProductionProtectorSelection();
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

    private static void TestTamperedTransferEnvelopeRejected()
    {
        AssertThrows<InvalidOperationException>(() => TransferEnvelopeCodec.Decode(
            """
            {
              "protocolVersion": "1.0",
              "transferId": "tx-tampered",
              "transferType": "FILE",
              "senderDeviceId": "bd-android-01",
              "senderPublicKey": "android-public-key",
              "receiverDeviceId": "bd-windows-01",
              "createdAt": "2026-07-06T14:27:18Z",
              "payloadMetadata": {
                "fileName": "notes.txt",
                "mimeType": "text/plain",
                "sizeBytes": 5,
                "chunkSize": 4194304,
                "totalChunks": 99,
                "sha256": "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
              }
            }
            """), "tampered chunk metadata rejected");

        AssertThrows<InvalidOperationException>(() => TransferEnvelopeCodec.Decode(
            """
            {
              "protocolVersion": "1.0",
              "transferId": "tx-missing-hash",
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
                "totalChunks": 1
              }
            }
            """), "missing final hash rejected");
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

    private static async Task TestReceiveMissingHashCannotComplete()
    {
        var fixture = Fixture(trustState: TrustState.Trusted, approval: ReceiveDecision.Accept);
        var payload = Encoding.UTF8.GetBytes("file payload");
        var manifest = new TransferManifest(
            TransferId: "tx-no-hash",
            Kind: TransferKind.File,
            SenderDeviceId: PeerId,
            ReceiverDeviceId: "this-windows-device",
            FileName: "notes.txt",
            MimeType: "text/plain",
            SizeBytes: payload.Length,
            ChunkSizeBytes: BeamDropProtocol.DefaultChunkSizeBytes,
            TotalChunks: ChunkCalculator.TotalChunks(payload.Length),
            Sha256: null,
            CreatedAt: DateTimeOffset.UtcNow,
            SenderPublicKey: PublicKey);

        var record = await fixture.Manager.ReceiveFileAsync(
            new IncomingTransferRequest(manifest, new TransferPeer(PeerId, "Laptop", PublicKey, AutoAcceptTransfers: true)),
            new MemoryStream(payload),
            CancellationToken.None);

        AssertEqual(TransferStatus.Corrupted, record.Status, "missing hash cannot complete");
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

    private static void TestPathTraversalFileNameRejected()
    {
        var root = Path.Combine(Path.GetTempPath(), "beamdrop-tests", Guid.NewGuid().ToString("N"));
        var factory = new DownloadsReceiveTargetFactory(root, Path.Combine(root, "staging"));
        var manifest = Manifest(size: 1, sha: new string('f', 64)) with { FileName = "..\\secret.txt" };

        AssertThrows<InvalidOperationException>(() => factory.Create(manifest), "path traversal file name rejected");
    }

    private static void TestReceivedFileNameTraversalVariantsRejected()
    {
        var root = Path.Combine(Path.GetTempPath(), "beamdrop-tests", Guid.NewGuid().ToString("N"));
        var factory = new DownloadsReceiveTargetFactory(root, Path.Combine(root, "staging"));
        var maliciousNames = new[]
        {
            "../secret.txt",
            "..\\secret.txt",
            "C:\\Windows\\System32\\evil.txt",
            "/etc/passwd",
            "nested\\evil.txt",
            "nested/evil.txt",
            "drive:stream.txt",
            "file\u0001name.txt",
            "file\nname.txt",
            ".."
        };

        foreach (var name in maliciousNames)
        {
            var manifest = Manifest(size: 1, sha: new string('f', 64)) with { FileName = name };
            AssertThrows<InvalidOperationException>(() => factory.Create(manifest), $"malicious file name rejected: {name.ReplaceLineEndings("\\n")}");
        }
    }

    // Conformance vectors from protocol/beamdrop-protocol/test-vectors/session-encryption-v1.json.
    private const string VectorSenderDeviceId = "device-sender-01";
    private const string VectorReceiverDeviceId = "device-receiver-02";
    private const string VectorTransferId = "tx-0001";
    private const string VectorSenderStaticSecretHex = "1111111111111111111111111111111111111111111111111111111111111111";
    private const string VectorSenderStaticPublicHex = "7b4e909bbe7ffe44c465a220037d608ee35897d31ef972f07f74892cb0f73f13";
    private const string VectorReceiverStaticSecretHex = "2222222222222222222222222222222222222222222222222222222222222222";
    private const string VectorReceiverStaticPublicHex = "0faa684ed28867b97f4a6a2dee5df8ce974e76b7018e3f22a1c4cf2678570f20";
    private const string VectorEphemeralSecretHex = "4444444444444444444444444444444444444444444444444444444444444444";
    private const string VectorEphemeralPublicHex = "ff2ee45601ec1b67310c7790404585ae697331eee1c1f8cf2419731c1fff3e6b";
    private const string VectorSessionKeyHex = "fb67bd5e5472aec109bb4ef123ecf106782f76dd6ccef2c7b72db1b0bf8c8ecc";
    private static readonly (long Index, string PlaintextUtf8, string SealedHex)[] VectorChunks =
    {
        (0, "BeamDrop chunk zero", "010000000000000000000000bbd2cd42ded08e24e8054fe22fd1aa439131de0b8f93e520c9b6fa149fc76716eebfe7"),
        (1, "BeamDrop chunk one", "010000000000000000000001572cefa90bc480e6e52513f8f029e6d6c42f7ca3377656d04ea0e349d9f175534a3c"),
        (2, "", "010000000000000000000002bb027ed44e2d74dad6563267b8acb77f")
    };

    private static SessionCrypto VectorSenderSession() => SessionCrypto.Initiate(
        Convert.FromHexString(VectorSenderStaticSecretHex),
        Convert.FromHexString(VectorReceiverStaticPublicHex),
        VectorSenderDeviceId,
        VectorReceiverDeviceId,
        VectorTransferId,
        ephemeralSecret: Convert.FromHexString(VectorEphemeralSecretHex));

    private static SessionCrypto VectorReceiverSession() => SessionCrypto.Accept(
        Convert.FromHexString(VectorReceiverStaticSecretHex),
        Convert.FromHexString(VectorEphemeralPublicHex),
        Convert.FromHexString(VectorSenderStaticPublicHex),
        VectorSenderDeviceId,
        VectorReceiverDeviceId,
        VectorTransferId);

    private static void TestSessionKeyConformanceVector()
    {
        AssertEqual(
            VectorSenderStaticPublicHex,
            Convert.ToHexString(SessionCrypto.PublicKeyFromSecret(Convert.FromHexString(VectorSenderStaticSecretHex))).ToLowerInvariant(),
            "sender static public key derivation");
        AssertEqual(
            VectorReceiverStaticPublicHex,
            Convert.ToHexString(SessionCrypto.PublicKeyFromSecret(Convert.FromHexString(VectorReceiverStaticSecretHex))).ToLowerInvariant(),
            "receiver static public key derivation");

        var sender = VectorSenderSession();
        AssertEqual(VectorEphemeralPublicHex, Convert.ToHexString(sender.EphemeralPublicKey).ToLowerInvariant(), "ephemeral public key derivation");
        AssertEqual(VectorSessionKeyHex, Convert.ToHexString(sender.SessionKey).ToLowerInvariant(), "sender session key conformance");

        var receiver = VectorReceiverSession();
        AssertEqual(VectorSessionKeyHex, Convert.ToHexString(receiver.SessionKey).ToLowerInvariant(), "receiver session key conformance");
    }

    private static void TestChunkSealConformanceVectors()
    {
        var sender = VectorSenderSession();
        var receiver = VectorReceiverSession();
        foreach (var (index, plaintextUtf8, sealedHex) in VectorChunks)
        {
            var sealedChunk = sender.SealChunk(index, Encoding.UTF8.GetBytes(plaintextUtf8));
            AssertEqual(sealedHex, Convert.ToHexString(sealedChunk).ToLowerInvariant(), $"sealed chunk {index} conformance");

            var opened = receiver.OpenChunk(index, Convert.FromHexString(sealedHex));
            AssertEqual(plaintextUtf8, Encoding.UTF8.GetString(opened), $"opened chunk {index} conformance");
        }
    }

    private static void TestSessionCryptoRejectsTamperedChunk()
    {
        var receiver = VectorReceiverSession();
        var tampered = Convert.FromHexString(VectorChunks[0].SealedHex);
        tampered[^1] ^= 0x01;
        AssertThrows<SessionCryptoException>(() => receiver.OpenChunk(0, tampered), "tampered chunk rejected");

        var reordered = Convert.FromHexString(VectorChunks[0].SealedHex);
        AssertThrows<SessionCryptoException>(() => receiver.OpenChunk(1, reordered), "reordered chunk rejected");

        AssertThrows<SessionCryptoException>(() => receiver.OpenChunk(0, new byte[SessionCrypto.SealOverheadBytes - 1]), "truncated chunk rejected");
    }

    private static void TestSessionCryptoRejectsAllZeroSharedSecret()
    {
        AssertThrows<SessionCryptoException>(
            () => SessionCrypto.Initiate(
                Convert.FromHexString(VectorSenderStaticSecretHex),
                new byte[32],
                VectorSenderDeviceId,
                VectorReceiverDeviceId,
                VectorTransferId),
            "all-zero shared secret rejected");
    }

    private static void TestChunkStreamsRoundTripMultiChunk()
    {
        var payload = Enumerable.Range(0, 1000).Select(value => (byte)value).ToArray();
        const int chunkSize = 256; // 4 chunks: 3 full chunks and a 232-byte tail.

        var sealing = new ChunkSealingStream(new MemoryStream(payload), VectorSenderSession(), payload.Length, chunkSize);
        using var sealedStream = new MemoryStream();
        sealing.CopyTo(sealedStream);
        AssertEqual(payload.Length + (4 * 32L), sealedStream.Length, "multi-chunk sealed size includes per-chunk frame header and overhead");

        var opening = new ChunkOpeningStream(new MemoryStream(sealedStream.ToArray()), VectorReceiverSession(), payload.Length, chunkSize);
        using var plainStream = new MemoryStream();
        opening.CopyTo(plainStream);
        AssertTrue(plainStream.ToArray().AsSpan().SequenceEqual(payload), "multi-chunk seal and open round trip");

        var emptySealing = new ChunkSealingStream(new MemoryStream(), VectorSenderSession(), 0, chunkSize);
        using var emptySealed = new MemoryStream();
        emptySealing.CopyTo(emptySealed);
        AssertEqual(32L, emptySealed.Length, "empty payload seals to a single empty framed chunk");

        var emptyOpening = new ChunkOpeningStream(new MemoryStream(emptySealed.ToArray()), VectorReceiverSession(), 0, chunkSize);
        using var emptyPlain = new MemoryStream();
        emptyOpening.CopyTo(emptyPlain);
        AssertEqual(0L, emptyPlain.Length, "empty payload opens to zero bytes");
    }

    private static void TestSpkiKeyHelpers()
    {
        var raw = Convert.FromHexString(VectorSenderStaticPublicHex);
        var spki = SessionCrypto.SpkiBase64FromRawPublicKey(raw);
        AssertTrue(spki.StartsWith("MCowBQYDK2VuAyEA", StringComparison.Ordinal), "spki base64 has X25519 DER prefix");
        AssertTrue(SessionCrypto.RawPublicKeyFromSpkiBase64(spki).AsSpan().SequenceEqual(raw), "spki round trip preserves raw key");
        AssertFalse(SessionCrypto.TryRawPublicKeyFromSpkiBase64("not-base64!", out _), "invalid base64 spki rejected");
        AssertFalse(SessionCrypto.TryRawPublicKeyFromSpkiBase64(Convert.ToBase64String(new byte[44]), out _), "wrong DER prefix rejected");
    }

    private static void TestTransferEnvelopeEncryptionRoundTrip()
    {
        var manifest = Manifest(size: 8, sha: new string('f', 64)) with
        {
            Encryption = new TransferEncryptionInfo(SessionCrypto.Scheme, VectorEphemeralPublicHex)
        };

        var json = TransferEnvelopeCodec.Encode(manifest);
        AssertTrue(json.Contains("\"encryption\"", StringComparison.Ordinal), "envelope json carries encryption block");
        AssertTrue(json.Contains("\"ephemeralPublicKey\"", StringComparison.Ordinal), "envelope json carries camelCase ephemeral key");

        var decoded = TransferEnvelopeCodec.Decode(json);
        AssertEqual(SessionCrypto.Scheme, decoded.Encryption?.Scheme, "decoded encryption scheme");
        AssertEqual(VectorEphemeralPublicHex, decoded.Encryption?.EphemeralPublicKey, "decoded ephemeral public key");

        var legacy = TransferEnvelopeCodec.Decode(TransferEnvelopeCodec.Encode(Manifest(size: 8, sha: new string('f', 64))));
        AssertTrue(legacy.Encryption is null, "legacy envelope has no encryption block");
    }

    private static void TestTransferEnvelopeRejectsInvalidEncryptionBlock()
    {
        var validJson = TransferEnvelopeCodec.Encode(Manifest(size: 8, sha: new string('f', 64)) with
        {
            Encryption = new TransferEncryptionInfo(SessionCrypto.Scheme, VectorEphemeralPublicHex)
        });

        AssertThrows<InvalidOperationException>(
            () => TransferEnvelopeCodec.Decode(validJson.Replace("BEAMDROP_SESSION_V1", "BEAMDROP_SESSION_V9")),
            "unknown encryption scheme rejected");
        AssertThrows<InvalidOperationException>(
            () => TransferEnvelopeCodec.Decode(validJson.Replace(VectorEphemeralPublicHex, "zz")),
            "invalid ephemeral public key rejected");
    }

    private static async Task TestEncryptedTransferEndToEnd()
    {
        var senderService = new SessionEncryptionService(SessionCrypto.GenerateSecretKey());
        var receiverService = new SessionEncryptionService(SessionCrypto.GenerateSecretKey());

        var senderFixture = Fixture(trustState: TrustState.Trusted, peerPublicKey: receiverService.LocalPublicKeyBase64, sessionEncryption: senderService);
        var senderManager = new TransferManager(
            senderFixture.Repository,
            new InMemoryTransferHistoryStore(),
            new MemoryReceiveTargetFactory(),
            new FixedApprovalPrompt(ReceiveDecision.Accept),
            senderFixture.AuditLog,
            localDeviceId: "bd-windows-sender",
            localPublicKey: senderService.LocalPublicKeyBase64,
            sessionEncryption: senderService);

        var payload = Encoding.UTF8.GetBytes("encrypted hello");
        var transport = new RecordingTransferTransport();
        var sent = await senderManager.SendTextAsync(PeerId, "encrypted hello", transport, CancellationToken.None);

        AssertEqual(TransferStatus.Completed, sent.Status, "encrypted send completed");
        AssertTrue(transport.Manifest?.Encryption is not null, "encrypted envelope includes encryption block");
        AssertEqual(payload.Length + 32L, transport.Sink.Length, "sealed payload carries frame header, nonce, and tag overhead");
        AssertFalse(transport.Sink.ToArray().AsSpan(16, payload.Length).SequenceEqual(payload), "sealed payload is not plaintext");

        var receiverFixture = ReceiverFixture("bd-windows-sender", senderService.LocalPublicKeyBase64, receiverService);
        var received = await receiverFixture.Manager.ReceiveFileAsync(
            new IncomingTransferRequest(transport.Manifest!, new TransferPeer("bd-windows-sender", "Sender", senderService.LocalPublicKeyBase64, AutoAcceptTransfers: true)),
            new MemoryStream(transport.Sink.ToArray()),
            CancellationToken.None);

        AssertEqual(TransferStatus.Completed, received.Status, "encrypted receive completed with verified hash");
    }

    private static async Task TestEncryptedTransferAuthFailureFailsTransfer()
    {
        var senderService = new SessionEncryptionService(SessionCrypto.GenerateSecretKey());
        var receiverService = new SessionEncryptionService(SessionCrypto.GenerateSecretKey());

        var senderFixture = Fixture(trustState: TrustState.Trusted, peerPublicKey: receiverService.LocalPublicKeyBase64, sessionEncryption: senderService);
        var senderManager = new TransferManager(
            senderFixture.Repository,
            new InMemoryTransferHistoryStore(),
            new MemoryReceiveTargetFactory(),
            new FixedApprovalPrompt(ReceiveDecision.Accept),
            senderFixture.AuditLog,
            localDeviceId: "bd-windows-sender",
            localPublicKey: senderService.LocalPublicKeyBase64,
            sessionEncryption: senderService);

        var transport = new RecordingTransferTransport();
        await senderManager.SendTextAsync(PeerId, "encrypted hello", transport, CancellationToken.None);

        var tampered = transport.Sink.ToArray();
        tampered[^1] ^= 0x01;

        var receiverFixture = ReceiverFixture("bd-windows-sender", senderService.LocalPublicKeyBase64, receiverService);
        var received = await receiverFixture.Manager.ReceiveFileAsync(
            new IncomingTransferRequest(transport.Manifest!, new TransferPeer("bd-windows-sender", "Sender", senderService.LocalPublicKeyBase64, AutoAcceptTransfers: true)),
            new MemoryStream(tampered),
            CancellationToken.None);

        AssertEqual(TransferStatus.Failed, received.Status, "tampered encrypted transfer fails");
    }

    private static async Task TestEncryptedTransferWithoutSessionServiceFails()
    {
        var fixture = Fixture(trustState: TrustState.Trusted);
        var manifest = Manifest(size: 5, sha: new string('f', 64)) with
        {
            Encryption = new TransferEncryptionInfo(SessionCrypto.Scheme, VectorEphemeralPublicHex)
        };

        var record = await fixture.Manager.ReceiveFileAsync(
            new IncomingTransferRequest(manifest, new TransferPeer(PeerId, "Laptop", PublicKey, AutoAcceptTransfers: true)),
            new MemoryStream(new byte[5 + 32]),
            CancellationToken.None);

        AssertEqual(TransferStatus.Failed, record.Status, "encrypted transfer without configured session encryption fails");
    }

    private static async Task TestLegacyPlaintextTransferStillWorksAndIsLogged()
    {
        var fixture = Fixture(trustState: TrustState.Trusted);
        var payload = Encoding.UTF8.GetBytes("legacy payload");
        var manifest = Manifest(size: payload.Length, sha: Fingerprint.Sha256Hex(payload));

        var record = await fixture.Manager.ReceiveFileAsync(
            new IncomingTransferRequest(manifest, new TransferPeer(PeerId, "Laptop", PublicKey, AutoAcceptTransfers: true)),
            new MemoryStream(payload),
            CancellationToken.None);

        AssertEqual(TransferStatus.Completed, record.Status, "legacy plaintext receive still completes");
        AssertTrue(fixture.AuditLog.List().Any(entry => entry.Type == AuditEventType.LegacyPlaintextTransfer), "legacy plaintext transfer is logged");

        var sendFixture = Fixture(trustState: TrustState.Trusted, sessionEncryption: new SessionEncryptionService(SessionCrypto.GenerateSecretKey()));
        var transport = new RecordingTransferTransport();
        var sent = await sendFixture.Manager.SendTextAsync(PeerId, "hello", transport, CancellationToken.None);

        AssertEqual(TransferStatus.Completed, sent.Status, "send to non-X25519 peer falls back to plaintext");
        AssertTrue(transport.Manifest?.Encryption is null, "fallback envelope has no encryption block");
        AssertEqual("hello", Encoding.UTF8.GetString(transport.Sink.ToArray()), "fallback payload is plaintext");
        AssertTrue(sendFixture.AuditLog.List().Any(entry => entry.Type == AuditEventType.LegacyPlaintextTransfer), "plaintext fallback send is logged");
    }

    private static void TestDpapiProtectorRoundTrip()
    {
        if (!OperatingSystem.IsWindows())
        {
            Console.WriteLine("SKIP: DPAPI secret protector round trip (Windows only).");
            return;
        }

        var protector = new DpapiSecretProtector();
        var secret = Encoding.UTF8.GetBytes("windows-production-secret");
        var protectedBytes = protector.Protect(secret);

        AssertFalse(protectedBytes.AsSpan().SequenceEqual(secret), "dpapi protected bytes differ from plaintext");
        AssertTrue(protector.Unprotect(protectedBytes).AsSpan().SequenceEqual(secret), "dpapi protector round trip");
    }

    private static void TestProductionProtectorSelection()
    {
        var fallbackKey = Enumerable.Repeat((byte)9, 32).ToArray();
        var protector = SecretProtectorFactory.CreateProductionProtector(fallbackKey);
        if (OperatingSystem.IsWindows())
        {
            AssertTrue(protector is DpapiSecretProtector, "windows production protector is DPAPI backed");
        }
        else
        {
            AssertTrue(protector is AesLocalSecretProtector, "non-windows production protector falls back to AES");
        }

        var store = new ProtectedSecretStore(protector);
        var secret = Encoding.UTF8.GetBytes("production secret material");
        store.Save("beamdrop.test.secret", secret);
        AssertTrue(store.Load("beamdrop.test.secret")!.AsSpan().SequenceEqual(secret), "production protector round trip through secret store");
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

    private static TestFixture Fixture(
        TrustState? trustState,
        ReceiveDecision approval = ReceiveDecision.Accept,
        string? peerPublicKey = null,
        SessionEncryptionService? sessionEncryption = null)
    {
        var audit = new AuditLog();
        var store = new InMemoryTrustedPeerStore();
        if (trustState is not null)
        {
            store.Upsert(new TrustedPeer(
                DeviceId: PeerId,
                DeviceName: "Laptop",
                Platform: BeamDropPlatform.Windows,
                PublicKeyBase64: peerPublicKey ?? PublicKey,
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
        var manager = new TransferManager(repository, new InMemoryTransferHistoryStore(), new MemoryReceiveTargetFactory(), new FixedApprovalPrompt(approval), audit, sessionEncryption: sessionEncryption);
        return new TestFixture(repository, manager, audit);
    }

    private static TestFixture ReceiverFixture(string senderDeviceId, string senderPublicKeyBase64, SessionEncryptionService sessionEncryption)
    {
        var audit = new AuditLog();
        var store = new InMemoryTrustedPeerStore();
        store.Upsert(new TrustedPeer(
            DeviceId: senderDeviceId,
            DeviceName: "Sender",
            Platform: BeamDropPlatform.Windows,
            PublicKeyBase64: senderPublicKeyBase64,
            Fingerprint: "AA BB CC DD EE FF",
            TrustState: TrustState.Trusted,
            AutoAcceptTransfers: true,
            EndpointHost: "127.0.0.1",
            EndpointPort: 49320,
            TrustedAt: DateTimeOffset.UtcNow,
            RevokedAt: null,
            LastSeenAt: DateTimeOffset.UtcNow));
        var repository = new TrustedPeerRepository(store, audit);
        var manager = new TransferManager(repository, new InMemoryTransferHistoryStore(), new MemoryReceiveTargetFactory(), new FixedApprovalPrompt(ReceiveDecision.Accept), audit, sessionEncryption: sessionEncryption);
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

internal sealed class RecordingTransferTransport : ITransferTransport
{
    public TransferManifest? Manifest { get; private set; }
    public MemoryStream Sink { get; } = new();

    public async Task SendAsync(TransferManifest manifest, Stream payload, IProgress<TransferProgress> progress, CancellationToken cancellationToken)
    {
        Manifest = manifest;
        await payload.CopyToAsync(Sink, cancellationToken);
    }
}

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
