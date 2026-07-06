import BeamDropIOSCore
import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        Task {
            await persistIncomingItems()
            extensionContext?.completeRequest(returningItems: nil)
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }

    private func persistIncomingItems() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        let providers = items.flatMap { $0.attachments ?? [] }
        var payloads: [String] = []

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = try? await provider.loadURL(typeIdentifier: UTType.url.identifier) {
                    payloads.append("url:\(url.absoluteString)")
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                if let text = try? await provider.loadString(typeIdentifier: UTType.text.identifier) {
                    payloads.append("text:\(text)")
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let url = try? await provider.loadFileURL(typeIdentifier: UTType.image.identifier) {
                    payloads.append("photo:\(url.absoluteString)")
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.item.identifier) {
                if let url = try? await provider.loadFileURL(typeIdentifier: UTType.item.identifier) {
                    payloads.append("file:\(url.absoluteString)")
                }
            }
        }

        let defaults = UserDefaults(suiteName: BeamDropProtocol.appGroupIdentifier)
        defaults?.set(payloads, forKey: "pendingSharePayloads")
    }
}

private extension NSItemProvider {
    func loadString(typeIdentifier: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func loadURL(typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: item as? URL)
            }
        }
    }

    func loadFileURL(typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: url)
            }
        }
    }
}
