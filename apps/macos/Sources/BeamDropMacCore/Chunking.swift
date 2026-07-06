import Foundation

public struct ChunkMetadata: Equatable, Sendable {
    public let index: Int64
    public let offset: Int64
    public let length: Int64
    public let totalChunks: Int64
}

public enum ChunkCalculator {
    public static func totalChunks(sizeBytes: Int64, chunkSize: Int64 = BeamDropProtocol.defaultChunkSizeBytes) -> Int64 {
        guard sizeBytes > 0 else { return 0 }
        precondition(chunkSize > 0, "chunkSize must be positive")
        return (sizeBytes + chunkSize - 1) / chunkSize
    }

    public static func chunks(sizeBytes: Int64, chunkSize: Int64 = BeamDropProtocol.defaultChunkSizeBytes) -> [ChunkMetadata] {
        let count = totalChunks(sizeBytes: sizeBytes, chunkSize: chunkSize)
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let offset = index * chunkSize
            return ChunkMetadata(
                index: index,
                offset: offset,
                length: min(chunkSize, sizeBytes - offset),
                totalChunks: count
            )
        }
    }
}

public struct ResumePlan: Equatable, Sendable {
    public let transferId: String
    public let nextChunkIndex: Int64
    public let remainingChunks: [ChunkMetadata]

    public var canResume: Bool {
        !remainingChunks.isEmpty
    }
}

public enum ResumePlanner {
    public static func plan(transferId: String, sizeBytes: Int64, chunkSize: Int64, completedChunks: Set<Int64>) -> ResumePlan {
        let remaining = ChunkCalculator.chunks(sizeBytes: sizeBytes, chunkSize: chunkSize)
            .filter { !completedChunks.contains($0.index) }
        return ResumePlan(
            transferId: transferId,
            nextChunkIndex: remaining.first?.index ?? ChunkCalculator.totalChunks(sizeBytes: sizeBytes, chunkSize: chunkSize),
            remainingChunks: remaining
        )
    }
}

public enum ProgressCalculator {
    public static func percent(bytesTransferred: Int64, totalBytes: Int64) -> Double {
        guard totalBytes > 0 else { return 100 }
        return min(100, max(0, (Double(bytesTransferred) / Double(totalBytes)) * 100))
    }
}
