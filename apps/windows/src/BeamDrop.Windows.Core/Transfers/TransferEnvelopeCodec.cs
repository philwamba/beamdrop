using System.Text.Json;
using System.Text.Json.Nodes;
using BeamDrop.Windows.Core.Security;

namespace BeamDrop.Windows.Core.Transfers;

public static class TransferEnvelopeCodec
{
    public static string Encode(TransferManifest manifest)
    {
        var envelope = new JsonObject
        {
            ["protocolVersion"] = BeamDropProtocol.ProtocolVersion,
            ["transferId"] = manifest.TransferId,
            ["transferType"] = ToWireTransferType(manifest.Kind),
            ["senderDeviceId"] = manifest.SenderDeviceId,
            ["senderPublicKey"] = manifest.SenderPublicKey ?? "",
            ["receiverDeviceId"] = manifest.ReceiverDeviceId,
            ["createdAt"] = manifest.CreatedAt.ToUniversalTime().ToString("O"),
            ["payloadMetadata"] = new JsonObject
            {
                ["fileName"] = manifest.FileName,
                ["mimeType"] = manifest.MimeType,
                ["sizeBytes"] = manifest.SizeBytes,
                ["chunkSize"] = manifest.ChunkSizeBytes,
                ["totalChunks"] = manifest.TotalChunks,
                ["sha256"] = manifest.Sha256
            }
        };
        if (manifest.Encryption is { } encryption)
        {
            envelope["encryption"] = new JsonObject
            {
                ["scheme"] = encryption.Scheme,
                ["ephemeralPublicKey"] = encryption.EphemeralPublicKey
            };
        }
        return envelope.ToJsonString();
    }

    public static TransferManifest Decode(string json)
    {
        using var document = JsonDocument.Parse(json);
        var root = document.RootElement;
        if (root.GetProperty("protocolVersion").GetString() != BeamDropProtocol.ProtocolVersion)
        {
            throw new InvalidOperationException("Unsupported BeamDrop protocol version.");
        }
        var payload = root.GetProperty("payloadMetadata");
        var sizeBytes = payload.GetProperty("sizeBytes").GetInt64();
        var chunkSize = payload.TryGetProperty("chunkSize", out var chunkSizeValue)
            ? chunkSizeValue.GetInt32()
            : BeamDropProtocol.DefaultChunkSizeBytes;
        if (sizeBytes < 0)
        {
            throw new InvalidOperationException("Transfer size must not be negative.");
        }
        if (chunkSize <= 0)
        {
            throw new InvalidOperationException("Transfer chunk size is invalid.");
        }
        var totalChunks = payload.TryGetProperty("totalChunks", out var totalChunksValue)
            ? totalChunksValue.GetInt64()
            : ChunkCalculator.TotalChunks(sizeBytes, chunkSize);
        if (totalChunks != ChunkCalculator.TotalChunks(sizeBytes, chunkSize))
        {
            throw new InvalidOperationException("Transfer chunk metadata does not match payload size.");
        }
        var sha256 = payload.TryGetProperty("sha256", out var shaValue) ? shaValue.GetString() : null;
        if (!IsSha256Hex(sha256))
        {
            throw new InvalidOperationException("Transfer is missing a valid final SHA-256.");
        }
        var encryption = DecodeEncryption(root);
        return new TransferManifest(
            TransferId: root.GetProperty("transferId").GetString() ?? throw new InvalidOperationException("Missing transfer id."),
            Kind: FromWireTransferType(root.GetProperty("transferType").GetString() ?? ""),
            SenderDeviceId: root.GetProperty("senderDeviceId").GetString() ?? throw new InvalidOperationException("Missing sender device id."),
            ReceiverDeviceId: root.GetProperty("receiverDeviceId").GetString() ?? throw new InvalidOperationException("Missing receiver device id."),
            FileName: payload.GetProperty("fileName").GetString() ?? "BeamDrop item",
            MimeType: payload.GetProperty("mimeType").GetString() ?? "application/octet-stream",
            SizeBytes: sizeBytes,
            ChunkSizeBytes: chunkSize,
            TotalChunks: totalChunks,
            Sha256: sha256,
            CreatedAt: DateTimeOffset.Parse(root.GetProperty("createdAt").GetString() ?? DateTimeOffset.UtcNow.ToString("O")),
            SenderPublicKey: root.TryGetProperty("senderPublicKey", out var publicKeyValue) ? publicKeyValue.GetString() : null,
            Encryption: encryption);
    }

    private static TransferEncryptionInfo? DecodeEncryption(JsonElement root)
    {
        if (!root.TryGetProperty("encryption", out var encryption) || encryption.ValueKind is JsonValueKind.Null)
        {
            return null;
        }
        var scheme = encryption.TryGetProperty("scheme", out var schemeValue) ? schemeValue.GetString() : null;
        if (!string.Equals(scheme, SessionCrypto.Scheme, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Unsupported transfer encryption scheme: {scheme}");
        }
        var ephemeralPublicKey = encryption.TryGetProperty("ephemeralPublicKey", out var keyValue) ? keyValue.GetString() : null;
        if (ephemeralPublicKey is not { Length: 64 } || !ephemeralPublicKey.All(Uri.IsHexDigit))
        {
            throw new InvalidOperationException("Transfer encryption ephemeral public key must be 64 hex characters.");
        }
        return new TransferEncryptionInfo(SessionCrypto.Scheme, ephemeralPublicKey.ToLowerInvariant());
    }

    private static bool IsSha256Hex(string? value) =>
        value is { Length: 64 } && value.All(Uri.IsHexDigit);

    public static string ToWireTransferType(TransferKind kind) => kind switch
    {
        TransferKind.Text => "TEXT",
        TransferKind.Url => "URL",
        TransferKind.File => "FILE",
        TransferKind.ClipboardText => "CLIPBOARD_TEXT",
        _ => throw new ArgumentOutOfRangeException(nameof(kind), kind, null)
    };

    public static TransferKind FromWireTransferType(string value) => value switch
    {
        "TEXT" => TransferKind.Text,
        "URL" => TransferKind.Url,
        "FILE" => TransferKind.File,
        "CLIPBOARD_TEXT" => TransferKind.ClipboardText,
        _ => throw new InvalidOperationException($"Unsupported transfer type: {value}")
    };
}
