import BeamDropIOSCore
import SwiftUI

struct TransferProgressView: View {
    @State private var progress = TransferProgressState(transferId: "idle", currentItem: "No active transfer", bytesTransferred: 0, totalBytes: 0, status: .queued)

    var body: some View {
        List {
            Section("Current transfer") {
                Text(progress.currentItem).font(.headline)
                ProgressView(value: Double(progress.percent), total: 100)
                LabeledContent("Status", value: progress.status.rawValue)
                Button("Cancel Transfer", role: .destructive) {
                    progress.status = .cancelled
                }
            }
        }
        .navigationTitle("Progress")
    }
}
