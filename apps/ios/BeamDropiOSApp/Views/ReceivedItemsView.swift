import BeamDropIOSCore
import SwiftUI
import UniformTypeIdentifiers

struct ReceivedItemsView: View {
    @EnvironmentObject private var transfers: TransferCoordinator
    @State private var exporting = false
    @State private var exportDocument = ReceivedTextDocument(text: "")

    private var receivedTexts: [ReceivedTransferItem] {
        transfers.receivedItems.filter { $0.text != nil }
    }

    private var receivedFiles: [ReceivedTransferItem] {
        transfers.receivedItems.filter { $0.fileURL != nil }
    }

    var body: some View {
        List {
            Section("Receive text") {
                if receivedTexts.isEmpty {
                    Text("Incoming text transfers appear here after trust checks, decryption, and hash verification.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(receivedTexts) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text ?? "")
                                .lineLimit(4)
                            Text("From \(item.peerDeviceName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Export latest received text") {
                        exportDocument = ReceivedTextDocument(text: receivedTexts.first?.text ?? "")
                        exporting = true
                    }
                }
            }

            Section("Receive files") {
                if receivedFiles.isEmpty {
                    ContentUnavailableView(
                        "No received files",
                        systemImage: "tray.and.arrow.down",
                        description: Text("Verified files can be saved or exported from here.")
                    )
                } else {
                    ForEach(receivedFiles) { item in
                        if let fileURL = item.fileURL {
                            ShareLink(item: fileURL) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fileURL.lastPathComponent)
                                    Text("From \(item.peerDeviceName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Received")
        .fileExporter(
            isPresented: $exporting,
            document: exportDocument,
            contentType: .plainText,
            defaultFilename: "BeamDrop Text"
        ) { _ in }
    }
}

struct ReceivedTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
