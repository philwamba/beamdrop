import Foundation

#if canImport(Network)
import Network
#endif

public enum TransferTransportError: Error, Equatable, LocalizedError {
    case connectionClosed
    case connectFailed(String)
    case invalidEndpoint
    case invalidFrame
    case frameTooLarge(Int)
    case envelopeTooLarge

    public var errorDescription: String? {
        switch self {
        case .connectionClosed: "Connection closed before the transfer finished."
        case .connectFailed(let reason): "Could not connect to peer: \(reason)."
        case .invalidEndpoint: "Trusted peer has no usable local endpoint."
        case .invalidFrame: "Received a malformed transfer frame."
        case .frameTooLarge(let size): "Received a transfer frame of \(size) bytes, above the allowed maximum."
        case .envelopeTooLarge: "Transfer envelope header exceeded the allowed maximum."
        }
    }
}

/// One bidirectional byte stream between two BeamDrop devices.
public protocol TransferConnecting: Sendable {
    /// Sends all bytes, throwing if the connection fails.
    func send(_ data: Data) async throws
    /// Returns the next available bytes (up to `maxLength`), or nil at end of stream.
    func receive(maxLength: Int) async throws -> Data?
    func close()
}

/// Opens outbound connections to a trusted peer's advertised endpoint.
public protocol TransferDialing: Sendable {
    func connect(to endpoint: EndpointHint) async throws -> any TransferConnecting
}

/// Wire layout shared by both directions:
/// - one JSON transfer envelope terminated by `\n`
/// - encrypted transfers: each sealed chunk framed as `UInt32 big-endian length || bytes`
/// - legacy plaintext transfers: exactly `sizeBytes` raw payload bytes
public enum TransferWire {
    public static let maxEnvelopeBytes = 64 * 1024
    /// Sealed chunk = chunk plaintext + nonce/tag overhead; allow a little slack.
    public static let maxFrameBytes = BeamDropProtocol.defaultChunkSizeBytes + 1024

    public static func encodeFrame(_ payload: Data) -> Data {
        var frame = withUnsafeBytes(of: UInt32(payload.count).bigEndian) { Data($0) }
        frame.append(payload)
        return frame
    }

    public static func frameLength(fromHeader header: Data) throws -> Int {
        guard header.count == 4 else { throw TransferTransportError.invalidFrame }
        let length = header.reduce(0) { ($0 << 8) | Int($1) }
        guard length <= maxFrameBytes else { throw TransferTransportError.frameTooLarge(length) }
        return length
    }
}

/// Buffers a `TransferConnecting` stream so callers can read exact byte counts
/// and the newline-terminated envelope header.
public actor TransferStreamReader {
    private let connection: any TransferConnecting
    private var buffer = Data()
    private var reachedEnd = false

    public init(connection: any TransferConnecting) {
        self.connection = connection
    }

    public func readEnvelopeLine() async throws -> Data {
        while true {
            if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newlineIndex]
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                return Data(line)
            }
            guard buffer.count <= TransferWire.maxEnvelopeBytes else { throw TransferTransportError.envelopeTooLarge }
            try await fill()
        }
    }

    public func read(exactly count: Int) async throws -> Data {
        while buffer.count < count {
            try await fill()
        }
        let bytes = buffer.prefix(count)
        buffer.removeFirst(count)
        return Data(bytes)
    }

    public func readFrame() async throws -> Data {
        let length = try TransferWire.frameLength(fromHeader: try await read(exactly: 4))
        return try await read(exactly: length)
    }

    private func fill() async throws {
        guard !reachedEnd, let next = try await connection.receive(maxLength: 64 * 1024), !next.isEmpty else {
            reachedEnd = true
            throw TransferTransportError.connectionClosed
        }
        buffer.append(next)
    }
}

#if canImport(Network)
/// `TransferConnecting` over an `NWConnection`. NWConnection is internally
/// thread-safe, so the wrapper is safely Sendable.
public final class NWTransferConnection: TransferConnecting, @unchecked Sendable {
    private let connection: NWConnection
    private static let queue = DispatchQueue(label: "com.beamdrop.ios.transfer-connection")

    public init(connection: NWConnection) {
        self.connection = connection
    }

    public static func connect(to endpoint: EndpointHint, timeout: TimeInterval = 10) async throws -> NWTransferConnection {
        guard endpoint.isUsable, let host = endpoint.host, let port = endpoint.port, let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw TransferTransportError.invalidEndpoint
        }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
        return try await withCheckedThrowingContinuation { continuation in
            let resumed = LockedFlag()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if resumed.trySet() { continuation.resume(returning: NWTransferConnection(connection: connection)) }
                case .failed(let error):
                    connection.cancel()
                    if resumed.trySet() { continuation.resume(throwing: TransferTransportError.connectFailed(error.localizedDescription)) }
                case .cancelled:
                    if resumed.trySet() { continuation.resume(throwing: TransferTransportError.connectFailed("cancelled")) }
                default:
                    break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                if resumed.trySet() {
                    connection.cancel()
                    continuation.resume(throwing: TransferTransportError.connectFailed("timed out after \(Int(timeout))s"))
                }
            }
            connection.start(queue: queue)
        }
    }

    public func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: TransferTransportError.connectFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    public func receive(maxLength: Int) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { data, _, isComplete, error in
                if let data, !data.isEmpty {
                    continuation.resume(returning: data)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else if let error {
                    continuation.resume(throwing: TransferTransportError.connectFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    public func close() {
        connection.cancel()
    }
}

public struct NWTransferDialer: TransferDialing {
    public init() {}

    public func connect(to endpoint: EndpointHint) async throws -> any TransferConnecting {
        try await NWTransferConnection.connect(to: endpoint)
    }
}

/// Small lock so continuation resume happens exactly once across NWConnection callbacks.
private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func trySet() -> Bool {
        lock.withLock {
            guard !value else { return false }
            value = true
            return true
        }
    }
}
#endif
