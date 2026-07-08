import BeamDropIOSCore
import SwiftUI

struct TransferProgressView: View {
    @EnvironmentObject private var transfers: TransferCoordinator
    @State private var confirmCancel = false

    private var isCancellable: Bool {
        guard let progress = transfers.progress else { return false }
        return progress.status == .transferring || progress.status == .queued
    }

    var body: some View {
        List {
            Section("Current transfer") {
                if let progress = transfers.progress {
                    Text(progress.currentItem).font(.headline)
                    ProgressView(value: Double(progress.percent), total: 100)
                    LabeledContent("Status", value: progress.status.rawValue)
                    LabeledContent("Progress", value: "\(progress.percent)%")
                    LabeledContent("Bytes", value: "\(progress.bytesTransferred) / \(progress.totalBytes)")
                    Button("Cancel Transfer", role: .destructive) {
                        confirmCancel = true
                    }
                    .disabled(!isCancellable)
                } else {
                    Text("No active transfer").font(.headline)
                    Text("Transfers run while BeamDrop is in the foreground and are sealed with the session protocol before leaving this iPhone.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Transfer Progress")
        .confirmationDialog("Cancel Transfer?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Transfer", role: .destructive) {
                transfers.cancelCurrentTransfer()
            }
            Button("Keep Transfer", role: .cancel) {}
        } message: {
            Text("The transfer will stop and appear as cancelled in history.")
        }
    }
}
