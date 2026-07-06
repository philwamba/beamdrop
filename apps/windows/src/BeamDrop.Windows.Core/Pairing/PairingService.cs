using System.Text.Json;
using System.Text.Json.Serialization;
using BeamDrop.Windows.Core.Discovery;
using BeamDrop.Windows.Core.Identity;

namespace BeamDrop.Windows.Core.Pairing;

public sealed record PairingQrPayload(
    string ProtocolVersion,
    string ServiceName,
    string PairingSessionId,
    string DeviceId,
    string DeviceName,
    BeamDropPlatform Platform,
    string PublicKeyBase64,
    string Fingerprint,
    string? HostName,
    int? Port,
    DateTimeOffset ExpiresAt);

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
        return new PairingQrPayload(
            ProtocolVersion: BeamDropProtocol.ProtocolVersion,
            ServiceName: BeamDropProtocol.ServiceName,
            PairingSessionId: $"pair-{Guid.NewGuid():N}",
            DeviceId: identity.DeviceId,
            DeviceName: identity.DeviceName,
            Platform: BeamDropPlatform.Windows,
            PublicKeyBase64: identity.PublicKeyBase64,
            Fingerprint: identity.Fingerprint,
            HostName: endpoint?.HostName,
            Port: endpoint?.Port,
            ExpiresAt: DateTimeOffset.UtcNow.Add(lifetime ?? TimeSpan.FromMinutes(2)));
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
        if (payload.ProtocolVersion != BeamDropProtocol.ProtocolVersion) throw new InvalidOperationException("Unsupported BeamDrop protocol version.");
        if (payload.ServiceName != BeamDropProtocol.ServiceName) throw new InvalidOperationException("QR payload is not for BeamDrop.");
        if (payload.ExpiresAt <= DateTimeOffset.UtcNow) throw new InvalidOperationException("Pairing QR payload expired.");
        if (string.IsNullOrWhiteSpace(payload.DeviceId)) throw new InvalidOperationException("Pairing payload missing device id.");
        if (string.IsNullOrWhiteSpace(payload.PublicKeyBase64)) throw new InvalidOperationException("Pairing payload missing public key.");
    }
}
