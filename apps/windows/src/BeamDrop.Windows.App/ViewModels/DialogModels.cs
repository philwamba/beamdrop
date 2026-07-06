using BeamDrop.Windows.Core;
using BeamDrop.Windows.Core.Pairing;
using BeamDrop.Windows.Core.Transfers;

namespace BeamDrop.Windows.App.ViewModels;

public sealed record PairingApprovalDialogModel(
    string DeviceName,
    string Platform,
    string Fingerprint,
    string Message)
{
    public static PairingApprovalDialogModel FromRequest(PairingRequest request) =>
        new(
            request.RemotePayload.DeviceName,
            request.RemotePayload.Platform.ToString(),
            request.RemotePayload.Fingerprint,
            "Approve this device before it can become trusted. Unknown devices cannot transfer without approval.");
}

public sealed record ReceiveApprovalDialogModel(
    string SenderDevice,
    string FileName,
    string FileSize,
    string Message)
{
    public static ReceiveApprovalDialogModel FromRequest(IncomingTransferRequest request) =>
        new(
            request.Sender.DeviceName,
            request.Manifest.FileName,
            FormatBytes(request.Manifest.SizeBytes),
            "Accept or reject this transfer. Accepting content does not create trust for unknown devices.");

    private static string FormatBytes(long bytes)
    {
        string[] units = { "B", "KB", "MB", "GB" };
        var value = (double)bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }
        return unit == 0 ? $"{bytes} B" : $"{value:0.0} {units[unit]}";
    }
}

public sealed record TransferProgressUiModel(
    string FileName,
    string PeerDevice,
    int Percentage,
    string Speed,
    string Size,
    bool CanCancel)
{
    public static TransferProgressUiModel FromProgress(TransferProgress progress) =>
        new(
            progress.FileName,
            progress.PeerDeviceName,
            progress.Percent,
            $"{FormatBytes(progress.SpeedBytesPerSecond)}/s",
            $"{FormatBytes(progress.BytesTransferred)} of {FormatBytes(progress.TotalBytes)}",
            progress.Status is TransferStatus.Queued or TransferStatus.WaitingForApproval or TransferStatus.Transferring or TransferStatus.Verifying);

    private static string FormatBytes(long bytes)
    {
        string[] units = { "B", "KB", "MB", "GB" };
        var value = (double)bytes;
        var unit = 0;
        while (value >= 1024 && unit < units.Length - 1)
        {
            value /= 1024;
            unit++;
        }
        return unit == 0 ? $"{bytes} B" : $"{value:0.0} {units[unit]}";
    }
}
