import Foundation
import Security

enum KeychainStore {
    private static let service = "com.bingequeue.com"
    private static let tokenAccount = "mobileAuthToken"
    private static let userAccount = "mobileAuthUser"

    static func saveToken(_ token: String) throws {
        try save(Data(token.utf8), account: tokenAccount)
    }

    static func loadToken() -> String? {
        guard let data = load(account: tokenAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func saveUser(_ user: UserProfile) throws {
        let data = try JSONEncoder().encode(user)
        try save(data, account: userAccount)
    }

    static func loadUser() -> UserProfile? {
        guard let data = load(account: userAccount) else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func clear() {
        delete(account: tokenAccount)
        delete(account: userAccount)
    }

    private static func save(_ data: Data, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case unexpectedStatus(OSStatus)
}
