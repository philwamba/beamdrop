import SwiftUI
import UniformTypeIdentifiers

struct SendFileView: View {
    @State private var importing = false
    @State private var selectedFiles: [URL] = []

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
        }
        .navigationTitle("Send File")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            selectedFiles = (try? result.get()) ?? []
        }
    }
}
