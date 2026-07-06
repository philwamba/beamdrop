import AppKit
import BeamDropMacCore
import SwiftUI

@main
struct BeamDropMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("BeamDrop") {
            MainWindowView()
                .environmentObject(appState)
                .onAppear {
                    appDelegate.appState = appState
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState? {
        didSet {
            rebuildMenu()
        }
    }
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.title = "BeamDrop"
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open BeamDrop", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Send Clipboard", action: #selector(sendClipboard), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Show Pairing QR", action: #selector(showPairing), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        let pauseTitle = appState?.clipboardSettings.pauseUntilRestart == true ? "Resume Clipboard Sharing" : "Pause Clipboard Sharing"
        menu.addItem(NSMenuItem(title: pauseTitle, action: #selector(toggleClipboardPause), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Network Diagnostics", action: #selector(openMainWindow), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit BeamDrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    @objc private func sendClipboard() {
        appState?.sendClipboard()
    }

    @objc private func showPairing() {
        appState?.generatePairingQR()
        openMainWindow()
    }

    @objc private func toggleClipboardPause() {
        guard let appState else { return }
        appState.clipboardSettings.pauseUntilRestart.toggle()
        appState.saveClipboardSettings()
        rebuildMenu()
    }
}
