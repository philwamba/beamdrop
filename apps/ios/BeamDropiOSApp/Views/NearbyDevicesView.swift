import BeamDropIOSCore
import SwiftUI

struct NearbyDevicesView: View {
    @State private var devices: [NearbyDevice] = []

    var body: some View {
        List {
            Section {
                if devices.isEmpty {
                    ContentUnavailableView("No nearby devices", systemImage: "dot.radiowaves.left.and.right", description: Text("BeamDrop looks for _beamdrop._tcp on your local network. Use QR pairing if discovery is blocked."))
                } else {
                    ForEach(devices) { device in
                        VStack(alignment: .leading) {
                            Text(device.deviceName)
                            Text("\(device.platform.rawValue) · \(device.trustState.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section("Permission") {
                Text("iPhone shows the Local Network prompt when BeamDrop starts Bonjour discovery or a local listener.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nearby Devices")
    }
}
