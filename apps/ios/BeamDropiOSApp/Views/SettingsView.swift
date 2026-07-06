import SwiftUI

struct SettingsView: View {
    @State private var deviceName = "iPhone"
    @State private var autoAccept = false

    var body: some View {
        List {
            Section("Device") {
                TextField("Device name", text: $deviceName)
                Toggle("Auto-accept trusted devices", isOn: $autoAccept)
                Text("Auto-accept applies only to trusted devices and should stay off on shared networks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Permissions") {
                Text("Camera is requested only for QR scanning. Local Network is requested only for Bonjour discovery and receiving.")
                    .foregroundStyle(.secondary)
            }
            Section("More") {
                NavigationLink("Privacy") { PrivacyView() }
                NavigationLink("Network Diagnostics") { NetworkDiagnosticsView() }
                NavigationLink("About") { AboutView() }
            }
        }
        .navigationTitle("Settings")
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("Local-first") {
                Text("BeamDrop pairs trusted devices locally and does not require login for local transfer.")
            }
            Section("Clipboard") {
                Text("iPhone clipboard sends are manual through Paste, Share Sheet, or Shortcuts. BeamDrop does not monitor clipboard silently in the background.")
            }
            Section("Trust") {
                Text("Unknown devices require approval. Revoked devices are blocked.")
            }
        }
        .navigationTitle("Privacy")
    }
}

struct NetworkDiagnosticsView: View {
    var body: some View {
        List {
            Section("Bonjour") {
                LabeledContent("Service", value: "_beamdrop._tcp")
                Text("If discovery fails, verify both devices are on the same local network and client isolation is disabled.")
            }
            Section("Local network permission") {
                Text("iOS prompts for Local Network access when BeamDrop browses or advertises Bonjour services.")
            }
            Section("Manual fallback") {
                Text("Use QR pairing when public or corporate Wi-Fi blocks local discovery. Security checks remain the same.")
            }
        }
        .navigationTitle("Network Diagnostics")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("BeamDrop for iPhone")
                    .font(.headline)
                Text("Native SwiftUI app for local-first transfer between trusted devices.")
                Text("MVP development. Public downloads will be published after signing, TestFlight validation, and release testing.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
    }
}
