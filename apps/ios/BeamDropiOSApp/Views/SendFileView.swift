import BeamDropIOSCore
import SwiftUI
import UniformTypeIdentifiers

struct SendFileView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var importing = false
    @State private var selectedFiles: [URL] = []
    @State private var selectedPeer: TrustedPeer?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    importing = true
                } label: {
                    Label("Choose files", systemImage: "doc.badge.plus")
                }
            }
            Section("Selected") {
                if selectedFiles.isEmpty {
                    ContentUnavailableView("No file selected", systemImage: "doc", description: Text("Use the file picker or Share Sheet to send files."))
                } else {
                    ForEach(selectedFiles, id: \.self) { url in
                        Text(url.lastPathComponent)
                    }
                }
            }
            Section("Trusted Device") {
                Picker("Device", selection: $selectedPeer) {
                    Text("Choose").tag(Optional<TrustedPeer>.none)
                    ForEach(container.trustedPeers.list().filter { $0.trustState == .trusted }) { peer in
                        Text(peer.deviceName).tag(Optional(peer))
                    }
                }
                if container.trustedPeers.list().filter({ $0.trustState == .trusted }).isEmpty {
                    Text("Pair a device before sending files.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Transfer Integrity") {
                Text("Large files are sent in 4 MB chunks. BeamDrop verifies the final SHA-256 hash before marking a receive complete.")
                    .foregroundStyle(.secondary)
                Button("Send Selected File") {
                    errorMessage = "File transfer transport is not connected in the current iPhone MVP build."
                }
                .disabled(selectedFiles.isEmpty || selectedPeer == nil)
            }
            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Send File")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            do {
                selectedFiles = try result.get()
                errorMessage = nil
            } catch {
                errorMessage = "File selection failed. Choose a readable file and try again."
            }
        }
    }
}
