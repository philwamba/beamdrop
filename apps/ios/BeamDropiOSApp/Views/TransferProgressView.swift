import BeamDropIOSCore
import SwiftUI

struct TransferProgressView: View {
    @State private var progress = TransferProgressState(transferId: "idle", currentItem: "No active transfer", bytesTransferred: 0, totalBytes: 0, status: .queued)
    @State private var confirmCancel = false

    var body: some View {
        List {
            Section("Current transfer") {
                Text(progress.currentItem).font(.headline)
                ProgressView(value: Double(progress.percent), total: 100)
                LabeledContent("Status", value: progress.status.rawValue)
                LabeledContent("Progress", value: "\(progress.percent)%")
                Button("Cancel Transfer", role: .destructive) {
                    confirmCancel = true
                }
                .disabled(progress.transferId == "idle" || progress.status == .cancelled)
            }
            Section("Empty State") {
                Text("Active transfers show file name, peer device, percentage, size, speed, verification, and cancellation state.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Transfer Progress")
        .confirmationDialog("Cancel Transfer?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Transfer", role: .destructive) {
                progress.status = .cancelled
            }
            Button("Keep Transfer", role: .cancel) {}
        } message: {
            Text("The transfer will stop and appear as cancelled in history.")
        }
    }
}
