import CryptoKit
import Foundation

public enum SHA256Hashing {
    public static func hash(data: Data) -> String {
        SHA256.hash(data: data).hexString
    }

    public static func hash(fileURL: URL, chunkSize: Int = 1024 * 1024) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: chunkSize)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}
        return hasher.finalize().hexString
    }

    public static func verify(data: Data, expectedHex: String) -> Bool {
        hash(data: data).caseInsensitiveCompare(expectedHex) == .orderedSame
    }

    public static func verify(fileURL: URL, expectedHex: String) throws -> Bool {
        try hash(fileURL: fileURL).caseInsensitiveCompare(expectedHex) == .orderedSame
    }
}

extension Digest {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
