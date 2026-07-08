import BeamDropIOSCore
import SwiftUI
import UIKit

struct SendTextView: View {
    @State private var text = ""
    @State private var selectedPeer: TrustedPeer?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isSending = false
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var transfers: TransferCoordinator

    var body: some View {
        Form {
            Section("Text") {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                Button {
                    text = UIPasteboard.general.string ?? ""
                } label: {
                    Label("Paste Clipboard Text Manually", systemImage: "doc.on.clipboard")
                }
                Text("BeamDrop does not monitor the iPhone clipboard silently. Paste is always user-triggered.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Trusted device") {
                Picker("Device", selection: $selectedPeer) {
                    Text("Choose").tag(Optional<TrustedPeer>.none)
                    ForEach(container.trustedPeers.list().filter { $0.trustState == .trusted }) { peer in
                        Text(peer.deviceName).tag(Optional(peer))
                    }
                }
            }

            Button(isSending ? "Sending…" : "Send Text") {
                guard let peer = selectedPeer else { return }
                errorMessage = nil
                statusMessage = nil
                isSending = true
                Task {
                    let record = await transfers.sendText(text, to: peer)
                    isSending = false
                    if record?.status == .completed {
                        statusMessage = "Sent to \(peer.deviceName). Session-encrypted, SHA-256 verified on arrival."
                    } else {
                        errorMessage = record?.errorMessage ?? transfers.errorMessage ?? "Transfer failed."
                    }
                }
            }
                .disabled(text.isEmpty || selectedPeer == nil || isSending)
            if let statusMessage {
                Section {
                    Text(statusMessage).foregroundStyle(.green)
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Send Text")
    }
}
