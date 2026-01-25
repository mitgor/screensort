import Foundation
import Security

/// Thread-safe keychain storage for authentication tokens.
final class KeychainService: Sendable {
    private let serviceName = "com.screensort.youtube"

    enum Key: String {
        case accessToken = "accessToken"
        case refreshToken = "refreshToken"
        case tokenExpiry = "tokenExpiry"
    }

    // MARK: - Save

    func save(_ value: String, for key: Key) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataCorrupted
        }

        // Delete existing item first
        try? delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    // MARK: - Load

    func load(_ key: Key) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.loadFailed(status: status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataCorrupted
        }

        return string
    }

    // MARK: - Delete

    func delete(_ key: Key) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    // MARK: - Clear All

    func clearAll() throws {
        for key in [Key.accessToken, Key.refreshToken, Key.tokenExpiry] {
            try delete(key)
        }
    }

    // MARK: - Token Management Helpers

    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws {
        try save(accessToken, for: .accessToken)
        try save(refreshToken, for: .refreshToken)

        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        try save(ISO8601DateFormatter().string(from: expiryDate), for: .tokenExpiry)
    }

    func loadTokens() throws -> (accessToken: String, refreshToken: String, expiry: Date)? {
        guard let accessToken = try load(.accessToken),
              let refreshToken = try load(.refreshToken),
              let expiryString = try load(.tokenExpiry),
              let expiry = ISO8601DateFormatter().date(from: expiryString) else {
            return nil
        }

        return (accessToken, refreshToken, expiry)
    }

    var isAccessTokenExpired: Bool {
        guard let tokens = try? loadTokens() else { return true }
        return tokens.expiry < Date()
    }
}
