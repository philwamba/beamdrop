import BeamDropIOSCore
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        List {
            let records = container.history.list()
            if records.isEmpty {
                ContentUnavailableView("No transfers yet", systemImage: "clock", description: Text("Sent and received items appear here."))
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading) {
                        Text(record.fileName).font(.headline)
                        Text("\(record.direction.rawValue) · \(record.status.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}
