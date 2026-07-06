import Foundation

public protocol TransferHistoryStoring {
    func loadHistory() throws -> [TransferHistoryRecord]
    func saveHistory(_ records: [TransferHistoryRecord]) throws
}

public final class InMemoryTransferHistoryStore: TransferHistoryStoring {
    public var records: [TransferHistoryRecord]

    public init(records: [TransferHistoryRecord] = []) {
        self.records = records
    }

    public func loadHistory() throws -> [TransferHistoryRecord] { records }
    public func saveHistory(_ records: [TransferHistoryRecord]) throws { self.records = records }
}

public final class JSONTransferHistoryStore: TransferHistoryStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func loadHistory() throws -> [TransferHistoryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try decoder.decode([TransferHistoryRecord].self, from: Data(contentsOf: fileURL))
    }

    public func saveHistory(_ records: [TransferHistoryRecord]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(records).write(to: fileURL, options: [.atomic])
    }
}

public final class TransferHistoryRepository {
    private let store: TransferHistoryStoring
    private var records: [TransferHistoryRecord]

    public init(store: TransferHistoryStoring) throws {
        self.store = store
        self.records = try store.loadHistory()
    }

    public func list() -> [TransferHistoryRecord] {
        records.sorted { $0.createdAt > $1.createdAt }
    }

    public func upsert(_ record: TransferHistoryRecord) throws {
        records.removeAll { $0.transferId == record.transferId }
        records.append(record)
        try store.saveHistory(records)
    }
}
