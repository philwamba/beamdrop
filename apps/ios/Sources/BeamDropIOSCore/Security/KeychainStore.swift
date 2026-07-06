import Foundation

public protocol KeychainStoring {
    func save(key: String, data: Data) throws
    func load(key: String) throws -> Data?
    func delete(key: String) throws
}

public enum KeychainStoreError: Error, Equatable {
    case unhandledStatus(Int32)
}

public final class InMemoryKeychainStore: KeychainStoring {
    private var values: [String: Data] = [:]

    public init() {}

    public func save(key: String, data: Data) throws {
        values[key] = data
    }

    public func load(key: String) throws -> Data? {
        values[key]
    }

    public func delete(key: String) throws {
        values.removeValue(forKey: key)
    }
}

#if canImport(Security)
import Security

public final class KeychainStore: KeychainStoring {
    private let service: String
    private let accessGroup: String?

    public init(service: String = "com.beamdrop.ios", accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func save(key: String, data: Data) throws {
        try delete(key: key)
        var query = baseQuery(key: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.unhandledStatus(status) }
    }

    public func load(key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainStoreError.unhandledStatus(status) }
        return item as? Data
    }

    public func delete(key: String) throws {
        let status = SecItemDelete(baseQuery(key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery(key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
#endif
