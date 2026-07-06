import SwiftUI
import UniformTypeIdentifiers

struct ReceivedItemsView: View {
    @State private var exporting = false
    @State private var exportDocument = ReceivedTextDocument(text: "Received BeamDrop text")

    var body: some View {
        List {
            Section("Receive text") {
                Text("Incoming text transfers appear here after trust checks and approval.")
                    .foregroundStyle(.secondary)
                Button("Export received text") {
                    exporting = true
                }
            }

            Section("Receive files") {
                ContentUnavailableView(
                    "No received files",
                    systemImage: "tray.and.arrow.down",
                    description: Text("Verified files can be saved or exported from here.")
                )
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
