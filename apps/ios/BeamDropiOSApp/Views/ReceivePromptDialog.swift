import BeamDropIOSCore
import SwiftUI

struct ReceivePromptDialog: View {
    let request: TransferEnvelope
    let sender: TrustedPeer
    let accept: () -> Void
    let reject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Receive transfer?")
                .font(.title2.bold())
            Text(sender.deviceName)
            Text("\(request.transferType.rawValue) · \(request.payloadMetadata.fileName) · \(request.payloadMetadata.sizeBytes) bytes")
                .foregroundStyle(.secondary)
            Text("Trust state: \(sender.trustState.rawValue)")
                .font(.caption)
            HStack {
                Button("Accept", action: accept).buttonStyle(.borderedProminent)
                Button("Reject", role: .cancel, action: reject)
            }
        }
        .padding()
    }
}
