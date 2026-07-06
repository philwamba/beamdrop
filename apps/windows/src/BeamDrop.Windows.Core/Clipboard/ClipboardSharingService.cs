using BeamDrop.Windows.Core.Audit;
using BeamDrop.Windows.Core.Transfers;

namespace BeamDrop.Windows.Core.Clipboard;

public sealed record ClipboardPolicy(
    bool SharingEnabled,
    bool SharingPaused,
    bool BlockSensitiveLookingContent);

public sealed record ClipboardSendStatus(bool Sent, string Message, DateTimeOffset At);

public interface IClipboardReader
{
    string? ReadText();
}

public sealed class ClipboardSharingService
{
    private readonly IClipboardReader _clipboardReader;
    private readonly TransferManager _transferManager;
    private readonly AuditLog _auditLog;
    private ClipboardPolicy _policy = new(SharingEnabled: false, SharingPaused: false, BlockSensitiveLookingContent: true);

    public ClipboardSendStatus LastStatus { get; private set; } = new(false, "Clipboard sharing has not run.", DateTimeOffset.UtcNow);

    public ClipboardSharingService(IClipboardReader clipboardReader, TransferManager transferManager, AuditLog auditLog)
    {
        _clipboardReader = clipboardReader;
        _transferManager = transferManager;
        _auditLog = auditLog;
    }

    public ClipboardPolicy Policy => _policy;

    public void SetSharingEnabled(bool enabled) => _policy = _policy with { SharingEnabled = enabled };

    public void PauseSharing(bool paused)
    {
        _policy = _policy with { SharingPaused = paused };
        if (paused) _auditLog.Add(AuditEventType.ClipboardSendPaused, null, null, "Clipboard sharing paused.");
    }

    public async Task<ClipboardSendStatus> SendClipboardFromTrayAsync(string receiverDeviceId, ITransferTransport transport, CancellationToken cancellationToken)
    {
        if (!_policy.SharingEnabled)
        {
            return SetStatus(false, "Clipboard sharing is disabled.");
        }
        if (_policy.SharingPaused)
        {
            return SetStatus(false, "Clipboard sharing is paused.");
        }
        var text = _clipboardReader.ReadText();
        if (string.IsNullOrWhiteSpace(text))
        {
            return SetStatus(false, "Clipboard is empty or not text.");
        }
        if (_policy.BlockSensitiveLookingContent && SensitiveContentDetector.LooksSensitive(text))
        {
            _auditLog.Add(AuditEventType.ClipboardSendBlocked, receiverDeviceId, null, "Sensitive-looking clipboard content blocked.");
            return SetStatus(false, "Clipboard content looked sensitive and was not sent.");
        }

        var record = await _transferManager.SendTextAsync(receiverDeviceId, text, transport, cancellationToken);
        return SetStatus(record.Status == TransferStatus.Completed, record.Status == TransferStatus.Completed ? "Clipboard sent." : record.ErrorMessage ?? "Clipboard send failed.");
    }

    private ClipboardSendStatus SetStatus(bool sent, string message)
    {
        LastStatus = new ClipboardSendStatus(sent, message, DateTimeOffset.UtcNow);
        return LastStatus;
    }
}

public static class SensitiveContentDetector
{
    private static readonly string[] SensitiveWords =
    {
        "password",
        "passcode",
        "otp",
        "2fa",
        "secret",
        "private key",
        "api_key",
        "token="
    };

    public static bool LooksSensitive(string text)
    {
        var lower = text.ToLowerInvariant();
        if (SensitiveWords.Any(lower.Contains)) return true;
        var digits = text.Count(char.IsDigit);
        return digits >= 12 && MightContainCardOrSsn(text);
    }

    private static bool MightContainCardOrSsn(string text)
    {
        var normalized = new string(text.Where(ch => char.IsDigit(ch) || ch == '-' || ch == ' ').ToArray());
        return normalized.Split(new[] { ' ', '-' }, StringSplitOptions.RemoveEmptyEntries).Any(part => part.Length is 3 or 4 or >= 12);
    }
}
