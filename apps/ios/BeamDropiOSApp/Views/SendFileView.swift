import BeamDropIOSCore
import SwiftUI
import UniformTypeIdentifiers

struct SendFileView: View {
    @EnvironmentObject private var container: AppContainer
    @EnvironmentObject private var transfers: TransferCoordinator
    @State private var importing = false
    @State private var selectedFiles: [URL] = []
    @State private var selectedPeer: TrustedPeer?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isSending = false

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
                Text("Large files are sent in 4 MB chunks sealed with the BeamDrop session protocol. BeamDrop verifies the final SHA-256 hash before marking a receive complete.")
                    .foregroundStyle(.secondary)
                Button(isSending ? "Sending…" : "Send Selected File") {
                    guard let peer = selectedPeer else { return }
                    errorMessage = nil
                    statusMessage = nil
                    isSending = true
                    let files = selectedFiles
                    Task {
                        var sentCount = 0
                        for url in files {
                            let scoped = url.startAccessingSecurityScopedResource()
                            let record = await transfers.sendFile(at: url, to: peer)
                            if scoped { url.stopAccessingSecurityScopedResource() }
                            guard record?.status == .completed else {
                                errorMessage = record?.errorMessage ?? transfers.errorMessage ?? "Transfer failed."
                                break
                            }
                            sentCount += 1
                        }
                        isSending = false
                        if sentCount == files.count {
                            statusMessage = "Sent \(sentCount) file\(sentCount == 1 ? "" : "s") to \(peer.deviceName)."
                            selectedFiles = []
                        }
                    }
                }
                .disabled(selectedFiles.isEmpty || selectedPeer == nil || isSending)
            }
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
