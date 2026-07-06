import SwiftUI

struct SettingsView: View {
    @State private var deviceName = "iPhone"
    @State private var autoAccept = false

    var body: some View {
        List {
            Section("Device") {
                TextField("Device name", text: $deviceName)
                Toggle("Auto-accept trusted devices", isOn: $autoAccept)
            }
            Section("More") {
                NavigationLink("Privacy") { PrivacyView() }
                NavigationLink("Network diagnostics") { NetworkDiagnosticsView() }
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
        }
        .navigationTitle("Diagnostics")
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                Text("BeamDrop for iPhone")
                    .font(.headline)
                Text("Native SwiftUI app for local-first transfer between trusted devices.")
            }
        }
        .navigationTitle("About")
    }
}
