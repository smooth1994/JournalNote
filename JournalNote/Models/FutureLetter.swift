//
//  FutureLetter.swift
//  JournalNote
//

import Foundation
import CryptoKit
import Security
import WCDBSwift

final class FutureLetter: TableCodable {
    var id: String = UUID().uuidString
    var body: String = ""
    var openAt: Date = Date()
    var createdAt: Date = Date()
    var isOpened: Bool = false

    enum CodingKeys: String, CodingTableKey {
        typealias Root = FutureLetter
        case id, body, openAt, createdAt, isOpened
        static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(id, isPrimary: true)
            BindColumnConstraint(body, isNotNull: true, defaultTo: "")
            BindColumnConstraint(openAt, isNotNull: true)
            BindColumnConstraint(createdAt, isNotNull: true)
            BindColumnConstraint(isOpened, isNotNull: true, defaultTo: false)
        }
    }

    init() {}

    init(body: String, openAt: Date) {
        self.body = body
        self.openAt = openAt
    }
}

/// Encrypts sealed-letter content before it crosses the WCDB persistence boundary.
/// The random AES key is kept in Keychain; WCDB only contains ciphertext.
enum FutureLetterCipher {
    private static let prefix = "jn-aes-gcm-v1:"
    private static let service = "com.journalnote.future-letter"
    private static let account = "content-encryption-key-v1"

    static func encrypt(_ text: String) throws -> String {
        guard !text.hasPrefix(prefix) else { return text }
        let sealedBox = try AES.GCM.seal(Data(text.utf8), using: SymmetricKey(data: try keyData()))
        guard let combined = sealedBox.combined else {
            throw CocoaError(.coderInvalidValue)
        }
        return prefix + combined.base64EncodedString()
    }

    static func decrypt(_ value: String) throws -> String {
        guard value.hasPrefix(prefix) else { return value }
        let encoded = String(value.dropFirst(prefix.count))
        guard let data = Data(base64Encoded: encoded) else {
            throw CocoaError(.coderReadCorrupt)
        }
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: SymmetricKey(data: try keyData()))
        guard let text = String(data: decrypted, encoding: .utf8) else {
            throw CocoaError(.coderReadCorrupt)
        }
        return text
    }

    private static func keyData() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return data
        }
        guard status == errSecItemNotFound else { throw keychainError(status) }

        var data = Data(count: 32)
        let randomStatus = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw keychainError(randomStatus) }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw keychainError(addStatus) }
        return data
    }

    private static func keychainError(_ status: OSStatus) -> NSError {
        NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(status, nil) as String? ?? "钥匙串访问失败"]
        )
    }
}
