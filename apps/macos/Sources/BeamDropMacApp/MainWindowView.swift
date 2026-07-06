import BeamDropMacCore
import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: SidebarSection = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            Group {
                switch selection {
                case .onboarding:
                    OnboardingView()
                case .home:
                    HomeView()
                case .nearby:
                    NearbyDevicesView()
                case .pairing:
                    PairingView()
                case .history:
                    HistoryView()
                case .trusted:
                    TrustedDevicesView()
                case .settings:
                    SettingsView()
                case .privacy:
                    PrivacyView()
                case .diagnostics:
                    NetworkDiagnosticsView()
                case .about:
                    AboutView()
                }
            }
            .frame(minWidth: 680, minHeight: 520)
            .alert("BeamDrop", isPresented: Binding(
                get: { appState.lastError != nil },
                set: { if !$0 { appState.lastError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appState.lastError ?? "")
            }
            .sheet(item: $appState.pendingReceive) { request in
                ReceiveApprovalDialog(request: request)
            }
        }
    }
}

private enum SidebarSection: String, CaseIterable, Identifiable {
    case onboarding
    case home
    case nearby
    case pairing
    case history
    case trusted
    case settings
    case privacy
    case diagnostics
    case about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .onboarding: "Onboarding"
        case .home: "Home"
        case .nearby: "Nearby Devices"
        case .pairing: "Pair New Device"
        case .history: "History"
        case .trusted: "Trusted Devices"
        case .settings: "Settings"
        case .privacy: "Privacy"
        case .diagnostics: "Network Diagnostics"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .onboarding: "sparkles"
        case .home: "paperplane"
        case .nearby: "antenna.radiowaves.left.and.right"
        case .pairing: "qrcode"
        case .history: "clock"
        case .trusted: "lock.shield"
        case .settings: "gearshape"
        case .privacy: "hand.raised"
        case .diagnostics: "waveform.path.ecg"
        case .about: "info.circle"
        }
    }
}
