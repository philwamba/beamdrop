using BeamDrop.Windows.Security;

namespace BeamDrop.Windows.Transfer;

public sealed class TransferCoordinator
{
    public bool CanTransfer(TrustedPeer peer, string publicKey) => peer.CanTransfer(publicKey);
}
