import BeamDropIOSCore
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var transfers: TransferCoordinator

    var body: some View {
        List {
            if transfers.history.isEmpty {
                ContentUnavailableView("No transfers yet", systemImage: "clock", description: Text("Sent and received items appear here."))
            } else {
                ForEach(transfers.history) { record in
                    VStack(alignment: .leading) {
                        Text(record.fileName).font(.headline)
                        Text("\(record.direction.rawValue) · \(record.status.rawValue) · \(record.peerDeviceName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let errorMessage = record.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}
