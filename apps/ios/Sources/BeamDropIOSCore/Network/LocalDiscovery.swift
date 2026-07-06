import Foundation

#if canImport(Network)
import Network
#endif

public struct NearbyDevice: Identifiable, Equatable, Sendable {
    public var id: String { deviceId }
    public var deviceId: String
    public var deviceName: String
    public var platform: BeamDropPlatform
    public var publicKey: String
    public var endpoint: EndpointHint
    public var trustState: TrustState
}

public protocol LocalDiscoveryServicing {
    func start(onUpdate: @escaping @Sendable ([NearbyDevice]) -> Void)
    func stop()
}

public final class BonjourDiscoveryService: LocalDiscoveryServicing {
    #if canImport(Network)
    private var browser: NWBrowser?
    #endif

    public init() {}

    public func start(onUpdate: @escaping @Sendable ([NearbyDevice]) -> Void) {
        #if canImport(Network)
        let descriptor = NWBrowser.Descriptor.bonjour(type: BeamDropProtocol.serviceName, domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.browseResultsChangedHandler = { _, _ in
            onUpdate([])
        }
        browser.start(queue: .main)
        self.browser = browser
        #else
        onUpdate([])
        #endif
    }

    public func stop() {
        #if canImport(Network)
        browser?.cancel()
        browser = nil
        #endif
    }
}

public final class LocalTransferListener {
    #if canImport(Network)
    private var listener: NWListener?
    #endif

    public init() {}

    public func start(port: Int = BeamDropProtocol.defaultPort) throws {
        #if canImport(Network)
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: UInt16(port))!)
        listener?.newConnectionHandler = { connection in
            connection.cancel()
        }
        listener?.start(queue: .main)
        #endif
    }

    public func stop() {
        #if canImport(Network)
        listener?.cancel()
        listener = nil
        #endif
    }
}
