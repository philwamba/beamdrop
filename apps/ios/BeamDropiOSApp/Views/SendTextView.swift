import BeamDropIOSCore
import SwiftUI
import UIKit

struct SendTextView: View {
    @State private var text = ""
    @State private var selectedPeer: TrustedPeer?
    @State private var errorMessage: String?
    @EnvironmentObject private var container: AppContainer

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

            Button("Send Text") {
                errorMessage = "Text transfer transport is not connected in the current iPhone MVP build."
            }
                .disabled(text.isEmpty || selectedPeer == nil)
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Send Text")
    }
}
