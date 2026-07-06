import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            TabView {
                onboardingPage("BeamDrop", "Send files and text locally between trusted devices.", "paperplane")
                onboardingPage("Pair with QR", "Trust is explicit. Unknown devices cannot silently send content.", "qrcode")
                onboardingPage("Permissions", "Local network and camera are requested only when needed for discovery and QR pairing.", "lock.shield")
                onboardingPage("Clipboard", "iPhone clipboard sends are manual through Paste, Share Sheet, or Shortcuts. BeamDrop does not monitor clipboard silently.", "doc.on.clipboard")
            }
            .tabViewStyle(.page)
            .safeAreaInset(edge: .bottom) {
                Button(action: onComplete) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
    }

    private func onboardingPage(_ title: String, _ text: String, _ symbol: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: symbol)
                .font(.system(size: 72))
                .foregroundStyle(.blue)
            Text(title)
                .font(.largeTitle.bold())
            Text(text)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}
