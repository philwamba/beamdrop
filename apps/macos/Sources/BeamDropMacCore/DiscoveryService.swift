import Foundation
import Network

public struct DiscoveryRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: String { deviceId }
    public let deviceId: String
    public let deviceName: String
    public let platform: BeamDropPlatform
    public let publicKey: String
    public let features: [String]
    public let host: String?
    public let port: Int

    public init(deviceId: String, deviceName: String, platform: BeamDropPlatform, publicKey: String, features: [String], host: String?, port: Int) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
        self.publicKey = publicKey
        self.features = features
        self.host = host
        self.port = port
    }
}

public protocol DiscoveryService {
    func start()
    func stop()
}

public final class BonjourDiscoveryService: DiscoveryService {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.beamdrop.mac.discovery")
    private let onUpdate: @Sendable ([DiscoveryRecord]) -> Void

    public init(onUpdate: @escaping @Sendable ([DiscoveryRecord]) -> Void) {
        self.onUpdate = onUpdate
    }

    public func start() {
        let browser = NWBrowser(for: .bonjour(type: BeamDropProtocol.serviceName, domain: nil), using: .tcp)
        self.browser = browser
        browser.browseResultsChangedHandler = { [onUpdate] results, _ in
            let records = results.compactMap { result -> DiscoveryRecord? in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return DiscoveryRecord(
                    deviceId: name,
                    deviceName: name,
                    platform: .macos,
                    publicKey: "",
                    features: ["pairing", "text", "file"],
                    host: nil,
                    port: BeamDropProtocol.defaultTransferPort
                )
            }
            onUpdate(records)
        }
        browser.start(queue: queue)
    }

    public func stop() {
        browser?.cancel()
        browser = nil
    }
}

public final class BonjourAdvertiser {
    private var listener: NWListener?
    private let identity: DeviceIdentity
    private let port: Int

    public init(identity: DeviceIdentity, port: Int = BeamDropProtocol.defaultTransferPort) {
        self.identity = identity
        self.port = port
    }

    public func start(newConnectionHandler: @escaping @Sendable (NWConnection) -> Void) throws {
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port))!
        let listener = try NWListener(using: .tcp, on: nwPort)
        let txtRecord = NWTXTRecord([
            "deviceId": identity.deviceId,
            "deviceName": identity.deviceName,
            "platform": identity.platform.rawValue,
            "publicKey": identity.publicKey,
            "features": "pairing,text,file,clipboard",
            "port": "\(port)"
        ])
        listener.service = NWListener.Service(
            name: identity.deviceName,
            type: BeamDropProtocol.serviceName,
            domain: nil,
            txtRecord: txtRecord
        )
        listener.newConnectionHandler = newConnectionHandler
        listener.start(queue: DispatchQueue(label: "com.beamdrop.mac.advertiser"))
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }
}

public enum LocalNetworkAddress {
    public static func firstUsableIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let family = interface.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name.hasPrefix("en") || name.hasPrefix("bridge") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            let candidate = String(cString: hostname)
            if !candidate.hasPrefix("127.") && !candidate.hasPrefix("169.254.") {
                address = candidate
                break
            }
        }
        return address
    }
}

public struct NetworkDiagnosticResult: Equatable, Sendable {
    public let title: String
    public let message: String
    public let isBlocking: Bool
}

public enum NetworkDiagnostics {
    public static func run() -> [NetworkDiagnosticResult] {
        var results: [NetworkDiagnosticResult] = []
        if LocalNetworkAddress.firstUsableIPv4Address() == nil {
            results.append(NetworkDiagnosticResult(
                title: "No local IPv4 address",
                message: "BeamDrop could not find a usable local network address. Join the same Wi-Fi or Ethernet network as the other device.",
                isBlocking: true
            ))
        }
        results.append(NetworkDiagnosticResult(
            title: "Bonjour service",
            message: "BeamDrop uses \(BeamDropProtocol.serviceName). Public or corporate Wi-Fi may block Bonjour discovery; use QR/manual endpoint fallback.",
            isBlocking: false
        ))
        results.append(NetworkDiagnosticResult(
            title: "macOS Local Network",
            message: "If discovery fails, allow BeamDrop on the local network and check firewall prompts.",
            isBlocking: false
        ))
        return results
    }
}
