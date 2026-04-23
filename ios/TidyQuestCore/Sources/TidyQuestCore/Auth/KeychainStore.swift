import Foundation
import Security

/// Simple Keychain wrapper for storing JWT tokens and device tokens.
/// One key namespace per app bundle to avoid cross-app collisions.
public final class KeychainStore: Sendable {

    private let service: String

    /// - Parameter service: Typically the app bundle ID (e.g., `com.jlgreen11.tidyquest.parent`).
    public init(service: String) {
        self.service = service
    }

    // MARK: - Write

    public func set(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        // Delete any existing item first (update-by-delete-then-add pattern)
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.write(status: status)
        }
    }

    // MARK: - Read

    public func get(forKey key: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.read(status: status)
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Delete

    public func delete(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.delete(status: status)
        }
    }
}

// MARK: - Error

public enum KeychainError: Error, Sendable {
    case write(status: OSStatus)
    case read(status: OSStatus)
    case delete(status: OSStatus)
}

// MARK: - Well-known keys

extension KeychainStore {
    public enum Keys {
        public static let parentJWT     = "parent_jwt"
        public static let deviceToken   = "device_token"
        public static let currentUserId = "current_user_id"
    }
}
