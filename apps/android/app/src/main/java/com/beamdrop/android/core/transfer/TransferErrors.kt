package com.beamdrop.android.core.transfer

sealed class TransferError(message: String) : Exception(message) {
    data class UnknownPeerRejected(val deviceId: String) : TransferError("Unknown peer rejected: $deviceId")
    data class RevokedPeerRejected(val deviceId: String) : TransferError("Revoked peer rejected: $deviceId")
    data class ReceiverRejected(val transferId: String) : TransferError("Receiver rejected transfer: $transferId")
    data class TransferCancelled(val transferId: String) : TransferError("Transfer cancelled: $transferId")
    data class MissingEndpoint(val deviceId: String) : TransferError("Peer has no usable endpoint: $deviceId")
    data class HashMismatch(val transferId: String) : TransferError("Transfer hash verification failed: $transferId")
    data class IncompleteTransfer(val transferId: String) : TransferError("Transfer incomplete: $transferId")
    data class TransportFailed(val reason: String) : TransferError(reason)
}

