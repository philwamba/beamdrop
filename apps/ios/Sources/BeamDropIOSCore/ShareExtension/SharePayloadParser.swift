import Foundation

public enum SharePayload: Equatable, Sendable {
    case text(String)
    case link(URL)
    case file(URL)
    case photo(URL)
}

public enum SharePayloadParser {
    public static func parse(text: String?) -> SharePayload? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if let url = URL(string: text), url.scheme != nil {
            return .link(url)
        }
        return .text(text)
    }

    public static func parseFile(url: URL, typeIdentifier: String?) -> SharePayload {
        if let typeIdentifier, typeIdentifier.lowercased().contains("image") {
            return .photo(url)
        }
        return .file(url)
    }
}
