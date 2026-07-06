using BeamDrop.Windows.Core;
using BeamDrop.Windows.Core.Clipboard;
using BeamDrop.Windows.Core.Diagnostics;
using BeamDrop.Windows.Core.Discovery;
using BeamDrop.Windows.Core.Identity;
using BeamDrop.Windows.Core.Pairing;
using BeamDrop.Windows.Core.Peers;
using BeamDrop.Windows.Core.Security;
using BeamDrop.Windows.Core.Transfers;

namespace BeamDrop.Windows.App.ViewModels;

public sealed class WindowsMvpRuntime
{
    public DeviceIdentity Identity { get; }
    public TrustedPeerRepository TrustedPeers { get; }
    public TransferManager Transfers { get; }
    public ClipboardSharingService Clipboard { get; }
    public PairingService Pairing { get; } = new();
    public NetworkDiagnosticsService Diagnostics { get; } = new();
    public ILocalDiscoveryService Discovery { get; }
    public ITransferHistoryStore History { get; }

    public WindowsMvpRuntime(string deviceName, IClipboardReader clipboardReader, ILocalDiscoveryService? discovery = null)
    {
        var audit = new BeamDrop.Windows.Core.Audit.AuditLog();
        var key = System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(Environment.UserName + Environment.MachineName));
        var identityStore = new InMemoryDeviceIdentityStore();
        var secretStore = new ProtectedSecretStore(new AesLocalSecretProtector(key));
        Identity = new DeviceIdentityService(identityStore, secretStore).GetOrCreate(deviceName);
        TrustedPeers = new TrustedPeerRepository(new InMemoryTrustedPeerStore(), audit);
        History = new InMemoryTransferHistoryStore();
        Transfers = new TransferManager(
            TrustedPeers,
            History,
            new DownloadsReceiveTargetFactory(),
            new RejectingReceiveApprovalPrompt(),
            audit,
            localDeviceId: Identity.DeviceId,
            localPublicKey: Identity.PublicKeyBase64);
        Clipboard = new ClipboardSharingService(clipboardReader, Transfers, audit);
        Discovery = discovery ?? new InMemoryDiscoveryService();
    }

    public async Task PublishDiscoveryAsync(CancellationToken cancellationToken) =>
        await Discovery.PublishAsync(DiscoveryFactory.FromIdentity(Identity), cancellationToken);

    public string ShowPairingQr(ManualConnectionEndpoint? endpoint = null) =>
        Pairing.EncodeForQr(Pairing.GenerateQrPayload(Identity, endpoint ?? new ManualConnectionEndpoint(Environment.MachineName, BeamDropProtocol.DefaultPort)));

    public TrustedPeer ApprovePairingQrText(string qrText, bool autoAcceptTransfers = false) =>
        TrustedPeers.Approve(Pairing.ImportFromQrOrText(qrText), autoAcceptTransfers);

    public async Task RunIncomingTransferOnceAsync(CancellationToken cancellationToken)
    {
        var server = new TcpIncomingTransferServer(
            Transfers,
            manifest =>
            {
                var peer = TrustedPeers.Get(manifest.SenderDeviceId);
                if (peer is null) return new TransferPeer(manifest.SenderDeviceId, manifest.SenderDeviceId, manifest.SenderPublicKey ?? "", false);
                return new TransferPeer(peer.DeviceId, peer.DeviceName, peer.PublicKeyBase64, peer.AutoAcceptTransfers);
            });
        await server.RunOnceAsync(BeamDropProtocol.DefaultPort, cancellationToken);
    }

    public async Task<TransferHistoryRecord> SendTextAsync(string trustedDeviceId, string text, ManualConnectionEndpoint endpoint, CancellationToken cancellationToken) =>
        await Transfers.SendTextAsync(trustedDeviceId, text, new TcpClientTransferTransport(endpoint), cancellationToken);

    public async Task<TransferHistoryRecord> SendFileAsync(string trustedDeviceId, string filePath, ManualConnectionEndpoint endpoint, IProgress<TransferProgress> progress, CancellationToken cancellationToken) =>
        await Transfers.SendFileAsync(trustedDeviceId, filePath, new TcpClientTransferTransport(endpoint), progress, cancellationToken);
}
