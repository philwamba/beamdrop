import BeamDropIOSCore
import SwiftUI
import UIKit

struct SendTextView: View {
    @State private var text = ""
    @State private var selectedPeer: TrustedPeer?
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        Form {
            Section("Text") {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
                Button {
                    text = UIPasteboard.general.string ?? ""
                } label: {
                    Label("Paste clipboard text manually", systemImage: "doc.on.clipboard")
                }
            }

            Section("Trusted device") {
                Picker("Device", selection: $selectedPeer) {
                    Text("Choose").tag(Optional<TrustedPeer>.none)
                    ForEach(container.trustedPeers.list().filter { $0.trustState == .trusted }) { peer in
                        Text(peer.deviceName).tag(Optional(peer))
                    }
                }
            }

            Button("Send Text") {}
                .disabled(text.isEmpty || selectedPeer == nil)
        }
        .navigationTitle("Send Text")
    }
}
