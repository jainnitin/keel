import Foundation
import KeelCore
import Security

actor KeychainPasswordStore: PasswordStore {
  static let shared = KeychainPasswordStore()

  private let service = "com.jainnitin.Keel.document-password"

  func password(for identity: DocumentIdentity) throws -> String? {
    var query = baseQuery(for: identity)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    switch status {
    case errSecSuccess:
      guard
        let data = item as? Data,
        let password = String(data: data, encoding: .utf8)
      else {
        let deleteStatus = SecItemDelete(baseQuery(for: identity) as CFDictionary)
        guard deleteStatus == errSecSuccess || deleteStatus == errSecItemNotFound else {
          throw KeychainError.operationFailed(deleteStatus)
        }
        throw KeychainError.invalidStoredValue
      }
      return password
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainError.operationFailed(status)
    }
  }

  func setPassword(_ password: String, for identity: DocumentIdentity) throws {
    guard let data = password.data(using: .utf8) else {
      throw KeychainError.invalidPasswordEncoding
    }

    let query = baseQuery(for: identity)
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
    ]
    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    switch updateStatus {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      var item = query
      for (key, value) in attributes {
        item[key] = value
      }
      let addStatus = SecItemAdd(item as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainError.operationFailed(addStatus)
      }
    default:
      throw KeychainError.operationFailed(updateStatus)
    }
  }

  func removePassword(for identity: DocumentIdentity) throws {
    let status = SecItemDelete(baseQuery(for: identity) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.operationFailed(status)
    }
  }

  private func baseQuery(for identity: DocumentIdentity) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: identity.rawValue,
      kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
    ]
  }
}

enum KeychainError: LocalizedError {
  case invalidPasswordEncoding
  case invalidStoredValue
  case operationFailed(OSStatus)

  var errorDescription: String? {
    switch self {
    case .invalidPasswordEncoding:
      "The password could not be encoded for secure storage."
    case .invalidStoredValue:
      "The saved password in Keychain is invalid."
    case .operationFailed(let status):
      if let message = SecCopyErrorMessageString(status, nil) as String? {
        "Keychain could not complete the operation: \(message)"
      } else {
        "Keychain could not complete the operation (error \(status))."
      }
    }
  }
}
