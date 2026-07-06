import BeamDropIOSCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        if container.onboardingComplete {
            AppTabView()
        } else {
            OnboardingView {
                container.onboardingComplete = true
            }
        }
    }
}

struct AppTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house") }
            NavigationStack { NearbyDevicesView() }
                .tabItem { Label("Nearby", systemImage: "dot.radiowaves.left.and.right") }
            NavigationStack { TrustedDevicesView() }
                .tabItem { Label("Devices", systemImage: "iphone.gen3.radiowaves.left.and.right") }
            NavigationStack { TransferProgressView() }
                .tabItem { Label("Transfers", systemImage: "arrow.up.arrow.down.circle") }
            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
