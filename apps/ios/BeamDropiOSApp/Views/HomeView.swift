import BeamDropIOSCore
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(container.identity.deviceName)
                        .font(.title2.bold())
                    Text("iPhone · protocol \(container.identity.protocolVersion)")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Quick actions") {
                NavigationLink { PairDeviceView() } label: {
                    Label("Pair new device", systemImage: "qrcode")
                }
                NavigationLink { SendTextView() } label: {
                    Label("Send text", systemImage: "text.bubble")
                }
                NavigationLink { SendFileView() } label: {
                    Label("Send file", systemImage: "doc.badge.plus")
                }
            }

            Section("Trusted devices") {
                let peers = container.trustedPeers.list().filter { $0.trustState == .trusted }
                if peers.isEmpty {
                    ContentUnavailableView("No trusted devices", systemImage: "person.crop.circle.badge.questionmark", description: Text("Pair with QR code before sending locally."))
                } else {
                    ForEach(peers) { peer in
                        DeviceRow(peer: peer)
                    }
                }
            }
        }
        .navigationTitle("BeamDrop")
    }
}

struct DeviceRow: View {
    let peer: TrustedPeer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(peer.deviceName).font(.headline)
            Text("\(peer.platform.rawValue) · \(peer.trustState.rawValue) · \(peer.fingerprint)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
