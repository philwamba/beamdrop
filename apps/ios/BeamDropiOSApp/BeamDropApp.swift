import BeamDropIOSCore
import SwiftUI

@main
struct BeamDropApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.transfers)
        }
    }
}

@MainActor
final class AppContainer: ObservableObject {
    let keychain = InMemoryKeychainStore()
    let trustedPeers: TrustedPeerRepository
    let history: TransferHistoryRepository
    let settings: SettingsRepository
    let identity: DeviceIdentity
    let transfers: TransferCoordinator
    private let listener = LocalTransferListener()

    @Published var onboardingComplete = false

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BeamDrop", isDirectory: true)
        self.trustedPeers = try! TrustedPeerRepository(store: JSONTrustedPeerStore(fileURL: appSupport.appendingPathComponent("trusted-peers.json")))
        self.history = try! TransferHistoryRepository(store: JSONTransferHistoryStore(fileURL: appSupport.appendingPathComponent("transfer-history.json")))
        self.settings = SettingsRepository(fileURL: appSupport.appendingPathComponent("settings.json"))
        let loadedSettings = (try? settings.load()) ?? BeamDropSettings()
        let identityService = DeviceIdentityService(keychain: keychain)
        self.identity = try! identityService.getOrCreate(deviceName: loadedSettings.deviceName)
        self.transfers = TransferCoordinator(
            identity: identity,
            sessionSecretKey: try! identityService.sessionSecretKey(),
            trustedPeers: trustedPeers,
            history: history,
            dialer: NWTransferDialer(),
            receiveDirectory: appSupport.appendingPathComponent("Received", isDirectory: true)
        )

        // Foreground-only listener: iOS suspends the socket in the background,
        // which is the documented BeamDrop iPhone MVP limitation.
        let transfers = self.transfers
        try? listener.start { connection in
            Task { @MainActor in
                await transfers.handleIncomingConnection(connection)
            }
        }
    }
}
