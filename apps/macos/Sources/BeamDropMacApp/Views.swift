import AppKit
import BeamDropMacCore
import CoreImage.CIFilterBuiltins
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppLogoHeader(title: "Onboarding", subtitle: "Set up BeamDrop for private local transfer.")
            EmptyState(title: "Pair With QR", message: "Trust is explicit. Unknown devices cannot send content until approved.")
            EmptyState(title: "Send Locally", message: "BeamDrop uses the local network when possible and does not require cloud upload for MVP transfers.")
            EmptyState(title: "Clipboard Is Manual", message: "Clipboard sharing is user-controlled from the menu bar or main window.")
            EmptyState(title: "Network Fallback", message: "If Bonjour discovery is blocked, use QR pairing or a manual endpoint.")
            Spacer()
        }
        .padding(24)
    }
}

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isDropTargeted = false
    @State private var confirmCancel = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppLogoHeader(title: "BeamDrop", subtitle: "Private local transfer for trusted devices.")

            PeerPicker()

            VStack(alignment: .leading, spacing: 8) {
                Text("Send Text")
                    .font(.headline)
                TextEditor(text: $appState.sendText)
                    .font(.body)
                    .frame(height: 96)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                HStack {
                    Button("Send Text", systemImage: "text.bubble") { appState.sendCurrentText() }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.sendText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Send Clipboard", systemImage: "doc.on.clipboard") { appState.sendClipboard() }
                    Button("Choose File", systemImage: "paperclip") { appState.chooseAndSendFile() }
                }
            }

            DragDropSendArea(isTargeted: isDropTargeted)
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    guard let provider = providers.first else { return false }
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                        let url: URL?
                        if let data = item as? Data {
                            url = URL(dataRepresentation: data, relativeTo: nil)
                        } else {
                            url = item as? URL
                        }
                        if let url {
                            Task { @MainActor in appState.sendFile(url) }
                        }
                    }
                    return true
                }

            if let progress = appState.activeProgress {
                TransferProgressView(progress: progress) {
                    confirmCancel = true
                }
            }

            Spacer()
        }
        .padding(24)
        .confirmationDialog("Cancel Transfer?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Cancel Transfer", role: .destructive) {
                appState.cancelActiveTransfer()
            }
            Button("Keep Transfer", role: .cancel) {}
        } message: {
            Text("The active transfer will stop and appear as cancelled in history.")
        }
    }
}

struct PeerPicker: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Trusted Device")
                .font(.headline)
            if appState.trustedPeers.filter({ $0.status == .trusted }).isEmpty {
                EmptyState(title: "No trusted devices", message: "Pair Android, Windows, iPhone, or another Mac before sending.")
            } else {
                Picker("Trusted Device", selection: $appState.selectedPeer) {
                    ForEach(appState.trustedPeers.filter { $0.status == .trusted }) { peer in
                        Text("\(peer.deviceName) · \(peer.platform.rawValue)")
                            .tag(Optional(peer))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

struct NearbyDevicesView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Nearby Devices", subtitle: "Devices discovered with Bonjour on \(BeamDropProtocol.serviceName).")
            if appState.nearbyDevices.isEmpty {
                EmptyState(title: "No devices found", message: "Public and corporate Wi-Fi can block local discovery. Pair with QR or enter an endpoint manually.")
            } else {
                List(appState.nearbyDevices) { device in
                    VStack(alignment: .leading) {
                        Text(device.deviceName).font(.headline)
                        Text("\(device.platform.rawValue) · port \(device.port)").foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

struct PairingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Header(title: "Show Pairing QR", subtitle: "Scan this code from Android or Windows to trust this Mac.")
                QRCodeView(text: appState.pairingQRText)
                    .frame(width: 260, height: 260)
                    .accessibilityLabel("BeamDrop pairing QR code")
                Button("Refresh QR", systemImage: "arrow.clockwise") { appState.generatePairingQR() }
                Text(appState.identity.deviceName)
                    .font(.headline)
                Text(appState.identity.fingerprint)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 14) {
                Header(title: "Scan QR Or Import Code", subtitle: "Paste QR text from another BeamDrop device when camera scanning is not available on this Mac.")
                TextEditor(text: $appState.pairingImportText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 180)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                Button("Approve Device", systemImage: "checkmark.shield") { appState.importPairingCode() }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.pairingImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                PermissionNote(text: "Only approve devices you physically control. Unknown devices cannot send files until approved.")
            }
        }
        .padding(24)
    }
}

struct TrustedDevicesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var peerPendingRevoke: TrustedPeer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Trusted Devices", subtitle: "Revoke devices immediately if they are lost, replaced, or no longer yours.")
            if appState.trustedPeers.isEmpty {
                EmptyState(title: "No trusted devices", message: "Pair a device with QR to enable local transfer.")
            } else {
                List(appState.trustedPeers) { peer in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(peer.deviceName).font(.headline)
                            Text("\(peer.platform.rawValue) · \(peer.fingerprint ?? "No fingerprint")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let host = peer.endpointHost, let port = peer.endpointPort {
                                Text("\(host):\(port)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(peer.status.rawValue)
                            .foregroundStyle(peer.status == .trusted ? .green : .red)
                        Button("Revoke", role: .destructive) { peerPendingRevoke = peer }
                            .disabled(peer.status == .revoked)
                    }
                    .padding(.vertical, 4)
                }
            }
            Spacer()
        }
        .padding(24)
        .confirmationDialog("Revoke Trust?", isPresented: Binding(
            get: { peerPendingRevoke != nil },
            set: { if !$0 { peerPendingRevoke = nil } }
        ), titleVisibility: .visible) {
            Button("Revoke \(peerPendingRevoke?.deviceName ?? "Device")", role: .destructive) {
                if let peer = peerPendingRevoke {
                    appState.revoke(peer)
                }
                peerPendingRevoke = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(peerPendingRevoke?.deviceName ?? "This device") will be blocked from sending, receiving, or resuming transfers until paired again.")
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Transfer History", subtitle: "Sent, received, failed, rejected, corrupted, and cancelled transfers.")
            if appState.history.isEmpty {
                EmptyState(title: "No transfers yet", message: "Completed and failed transfers will appear here.")
            } else {
                List(appState.history) { record in
                    HStack {
                        Image(systemName: record.direction == .sent ? "arrow.up.circle" : "arrow.down.circle")
                        VStack(alignment: .leading) {
                            Text(record.fileName).font(.headline)
                            Text("\(record.peerDeviceName) · \(record.transferType.rawValue) · \(record.sizeBytes.formatted()) bytes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let error = record.errorMessage {
                                Text(error).font(.caption).foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        Text(record.status.rawValue)
                            .foregroundStyle(statusColor(record.status))
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }

    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .completed: .green
        case .failed, .corrupted, .incomplete, .rejected: .red
        case .cancelled: .orange
        default: .secondary
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Clipboard") {
                Toggle("Enable manual clipboard sharing", isOn: Binding(
                    get: { appState.clipboardSettings.sharingEnabled },
                    set: {
                        appState.clipboardSettings.sharingEnabled = $0
                        appState.saveClipboardSettings()
                    }
                ))
                Toggle("Pause clipboard sharing until restart", isOn: Binding(
                    get: { appState.clipboardSettings.pauseUntilRestart },
                    set: {
                        appState.clipboardSettings.pauseUntilRestart = $0
                        appState.saveClipboardSettings()
                    }
                ))
                PermissionNote(text: "BeamDrop never monitors the clipboard silently. Clipboard sending is always user-controlled from the menu bar or main window.")
            }
            Section("Startup") {
                Toggle("Start BeamDrop at login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.toggleLaunchAtLogin($0) }
                ))
            }
            Section("Privacy") {
                Text("Transfers stay on the local network when possible. Cloud upload is not required for the MVP.")
                Text("Unknown devices are rejected, and revoked devices are blocked before content is accepted.")
            }
            Section("Permissions") {
                Text("macOS may prompt for Local Network, file access, notifications, and login item changes only when those features are used.")
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
}

struct PrivacyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Privacy", subtitle: "BeamDrop is designed for explicit local transfer between trusted devices.")
            EmptyState(title: "Local-First Transfers", message: "BeamDrop does not require login or cloud upload for local MVP transfers.")
            EmptyState(title: "Clipboard Control", message: "Clipboard sharing is manual. BeamDrop does not silently monitor or send clipboard content.")
            EmptyState(title: "Device Trust", message: "Unknown devices are rejected. Revoked devices are blocked before content is accepted.")
            Spacer()
        }
        .padding(24)
    }
}

struct NetworkDiagnosticsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Network Diagnostics", subtitle: "Use this when discovery or transfer fails on local Wi-Fi.")
            ForEach(Array(appState.diagnostics.enumerated()), id: \.offset) { _, result in
                HStack(alignment: .top) {
                    Image(systemName: result.isBlocking ? "exclamationmark.triangle.fill" : "info.circle")
                        .foregroundStyle(result.isBlocking ? .orange : .blue)
                    VStack(alignment: .leading) {
                        Text(result.title).font(.headline)
                        Text(result.message).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            Button("Run Diagnostics Again", systemImage: "arrow.clockwise") { appState.refresh() }
            Spacer()
        }
        .padding(24)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppLogoHeader(title: "About", subtitle: "BeamDrop for macOS")
            EmptyState(title: "Native App", message: "Built with Swift, SwiftUI, AppKit, Network.framework, Bonjour, NSPasteboard, and Keychain.")
            EmptyState(title: "Protocol", message: "Uses BeamDrop protocol 1.0 with 4 MB chunks and final SHA-256 verification.")
            EmptyState(title: "Release Status", message: "MVP development. Production downloads will be published after signing, notarization, and release testing.")
            Spacer()
        }
        .padding(24)
    }
}

struct AppLogoHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("BeamDropLogo", bundle: .module)
                .resizable()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel("BeamDrop app icon")
            Header(title: title, subtitle: subtitle)
        }
    }
}

struct ReceiveApprovalDialog: View {
    let request: PendingReceiveRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Header(title: "Receive File?", subtitle: "\(request.senderName) wants to send \(request.fileName).")
            Text("\(request.sizeBytes.formatted()) bytes")
                .foregroundStyle(.secondary)
            Text("Accepting this transfer does not change trusted-device settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("Reject", role: .cancel) {
                    request.reject()
                    dismiss()
                }
                Spacer()
                Button("Accept", systemImage: "checkmark") {
                    request.accept()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}

struct TransferProgressView: View {
    let progress: TransferProgress
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(progress.fileName).font(.headline)
                    Text("\(progress.peerDeviceName) · \(progress.status.rawValue)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel", role: .destructive, action: cancel)
                    .disabled(progress.status == .completed)
            }
            ProgressView(value: progress.percent, total: 100)
            Text("\(Int(progress.percent))% · \(progress.bytesTransferred.formatted()) / \(progress.totalBytes.formatted()) bytes · \(Int(progress.speedBytesPerSecond).formatted()) B/s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct QRCodeView: View {
    let text: String

    var body: some View {
        if let image = QRCodeGenerator.makeCIImage(from: text),
           let cgImage = CIContext().createCGImage(image, from: image.extent) {
            Image(nsImage: NSImage(cgImage: cgImage, size: NSSize(width: 260, height: 260)))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            EmptyState(title: "QR unavailable", message: "Copy the pairing text instead.")
        }
    }
}

struct DragDropSendArea: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 28))
            Text("Drop a file to send")
                .font(.headline)
            Text("BeamDrop streams files in 4 MB chunks and verifies SHA-256 after receive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 116)
        .background(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isTargeted ? Color.accentColor : Color.secondary.opacity(0.18)))
    }
}

struct Header: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }
}

struct EmptyState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PermissionNote: View {
    let text: String

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "hand.raised")
            Text(text)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }
}
