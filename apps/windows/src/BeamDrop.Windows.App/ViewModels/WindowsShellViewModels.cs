using BeamDrop.Windows.Core.Clipboard;
using BeamDrop.Windows.Core.Diagnostics;
using BeamDrop.Windows.Core.Discovery;
using BeamDrop.Windows.Core.Pairing;
using BeamDrop.Windows.Core.Peers;
using BeamDrop.Windows.Core.Transfers;

namespace BeamDrop.Windows.App.ViewModels;

public sealed class TrayMenuModel
{
    public bool ClipboardSharingEnabled { get; init; }
    public bool ClipboardSharingPaused { get; init; }
    public string LastClipboardStatus { get; init; } = "";
    public IReadOnlyList<string> TrustedDeviceNames { get; init; } = Array.Empty<string>();
    public string SendClipboardActionLabel => "Send Clipboard";
    public string PauseClipboardActionLabel => ClipboardSharingPaused ? "Resume Clipboard Sharing" : "Pause Clipboard Sharing";
}

public sealed class WindowsShellViewModel
{
    private readonly TrustedPeerRepository _trustedPeers;
    private readonly ClipboardSharingService _clipboardSharing;
    private readonly NetworkDiagnosticsService _diagnostics;
    private readonly PairingService _pairingService;

    public WindowsShellViewModel(
        TrustedPeerRepository trustedPeers,
        ClipboardSharingService clipboardSharing,
        NetworkDiagnosticsService diagnostics,
        PairingService pairingService)
    {
        _trustedPeers = trustedPeers;
        _clipboardSharing = clipboardSharing;
        _diagnostics = diagnostics;
        _pairingService = pairingService;
    }

    public TrayMenuModel BuildTrayMenu() => new()
    {
        ClipboardSharingEnabled = _clipboardSharing.Policy.SharingEnabled,
        ClipboardSharingPaused = _clipboardSharing.Policy.SharingPaused,
        LastClipboardStatus = _clipboardSharing.LastStatus.Message,
        TrustedDeviceNames = _trustedPeers.List().Where(peer => peer.TrustState == BeamDrop.Windows.Core.TrustState.Trusted).Select(peer => peer.DeviceName).ToList()
    };

    public string GeneratePairingQrText(BeamDrop.Windows.Core.Identity.DeviceIdentity identity, ManualConnectionEndpoint? endpoint = null) =>
        _pairingService.EncodeForQr(_pairingService.GenerateQrPayload(identity, endpoint));

    public PairingRequest ImportPairingQrText(string qrText) => _pairingService.ImportFromQrOrText(qrText);

    public DiagnosticResult BuildNetworkDiagnostics(IReadOnlyList<DiscoveryRecord> records) =>
        _diagnostics.BuildDiscoveryDiagnostics(records);

    public IReadOnlyList<TransferHistoryRecord> History(ITransferHistoryStore store) => store.List();
}
