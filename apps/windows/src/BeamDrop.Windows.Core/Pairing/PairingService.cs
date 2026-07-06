using System.Text.Json;
using System.Text.Json.Serialization;
using BeamDrop.Windows.Core.Discovery;
using BeamDrop.Windows.Core.Identity;

namespace BeamDrop.Windows.Core.Pairing;

public sealed record PairingQrPayload(
    string Type,
    string ProtocolVersion,
    string ServiceName,
    string PairingSessionId,
    string DeviceId,
    string DeviceName,
    BeamDropPlatform Platform,
    string PublicKey,
    string Fingerprint,
    PairingEndpoint? Endpoint,
    long ExpiresAtEpochMillis);

public sealed record PairingEndpoint(string? Host, int? Port, string Route = "local");

public sealed record PairingRequest(PairingQrPayload RemotePayload, DateTimeOffset ReceivedAt);

public sealed record PairingApproval(string DeviceId, bool Approved, string? Reason);

public sealed class PairingService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    public PairingQrPayload GenerateQrPayload(DeviceIdentity identity, ManualConnectionEndpoint? endpoint = null, TimeSpan? lifetime = null)
    {
        var expiresAt = DateTimeOffset.UtcNow.Add(lifetime ?? TimeSpan.FromMinutes(5));
        return new PairingQrPayload(
            Type: "beamdrop_pairing",
            ProtocolVersion: BeamDropProtocol.ProtocolVersion,
            ServiceName: BeamDropProtocol.ServiceName,
            PairingSessionId: $"pair-{Guid.NewGuid():N}",
            DeviceId: identity.DeviceId,
            DeviceName: identity.DeviceName,
            Platform: BeamDropPlatform.Windows,
            PublicKey: identity.PublicKeyBase64,
            Fingerprint: identity.Fingerprint,
            Endpoint: endpoint is null ? null : new PairingEndpoint(endpoint.HostName, endpoint.Port),
            ExpiresAtEpochMillis: expiresAt.ToUnixTimeMilliseconds());
    }

    public string EncodeForQr(PairingQrPayload payload) => JsonSerializer.Serialize(payload, JsonOptions);

    public PairingRequest ImportFromQrOrText(string rawPayload)
    {
        var payload = JsonSerializer.Deserialize<PairingQrPayload>(rawPayload, JsonOptions)
            ?? throw new InvalidOperationException("Pairing QR payload is invalid.");
        Validate(payload);
        return new PairingRequest(payload, DateTimeOffset.UtcNow);
    }

    public static void Validate(PairingQrPayload payload)
    {
        if (payload.Type != "beamdrop_pairing") throw new InvalidOperationException("QR payload is not a BeamDrop pairing payload.");
        if (payload.ProtocolVersion != BeamDropProtocol.ProtocolVersion) throw new InvalidOperationException("Unsupported BeamDrop protocol version.");
        if (payload.ServiceName != BeamDropProtocol.ServiceName) throw new InvalidOperationException("QR payload is not for BeamDrop.");
        if (payload.ExpiresAtEpochMillis <= DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()) throw new InvalidOperationException("Pairing QR payload expired.");
        if (string.IsNullOrWhiteSpace(payload.DeviceId)) throw new InvalidOperationException("Pairing payload missing device id.");
        if (string.IsNullOrWhiteSpace(payload.PublicKey)) throw new InvalidOperationException("Pairing payload missing public key.");
    }
}
