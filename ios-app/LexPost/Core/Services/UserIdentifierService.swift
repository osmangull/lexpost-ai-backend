import Foundation
import Security

/// Cihaza özel anonim kullanıcı tanımlayıcısını üretir ve Keychain'de saklar.
/// Keychain kullanıldığı için uygulama silinip tekrar kurulsa bile aynı ID korunur.
enum UserIdentifierService {
    private static let service = "com.lexpost.identifier"
    private static let account = "anonymousUserId"

    static var userId: String {
        if let existing = readFromKeychain() {
            return existing
        }
        let newId = UUID().uuidString
        saveToKeychain(newId)
        return newId
    }

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let id = String(data: data, encoding: .utf8) else {
            return nil
        }
        return id
    }

    private static func saveToKeychain(_ id: String) {
        guard let data = id.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String:   data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
