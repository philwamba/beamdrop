import BeamDropIOSCore
import SwiftUI

struct TrustedDevicesView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var refresh = UUID()

    var body: some View {
        List {
            let peers = container.trustedPeers.list()
            if peers.isEmpty {
                ContentUnavailableView("No trusted devices", systemImage: "person.2.slash", description: Text("Pair with QR code to trust a device."))
            } else {
                ForEach(peers) { peer in
                    NavigationLink { DeviceDetailView(peer: peer) } label: {
                        DeviceRow(peer: peer)
                    }
                    .swipeActions {
                        Button("Revoke", role: .destructive) {
                            try? container.trustedPeers.revoke(deviceId: peer.deviceId)
                            refresh = UUID()
                        }
                    }
                }
            }
        }
        .id(refresh)
        .navigationTitle("Trusted Devices")
        .toolbar {
            NavigationLink { PairDeviceView() } label: {
                Image(systemName: "plus")
            }
        }
    }
}

struct DeviceDetailView: View {
    let peer: TrustedPeer

    var body: some View {
        List {
            Section(peer.deviceName) {
                LabeledContent("Platform", value: peer.platform.rawValue)
                LabeledContent("Trust", value: peer.trustState.rawValue)
                LabeledContent("Fingerprint", value: peer.fingerprint)
            }
            if peer.trustState == .revoked {
                Section {
                    Text("Revoked devices cannot transfer or resume until paired again.")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Device")
    }
}
