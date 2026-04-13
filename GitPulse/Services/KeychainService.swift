//  KeychainService.swift
//  GitPulse

import Foundation
import Security

// MARK: - KeychainError

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, LocalizedError, Equatable {
  /// The item already exists in the Keychain.
  case duplicateItem
  /// No matching item was found in the Keychain.
  case itemNotFound
  /// The data retrieved from the Keychain could not be decoded.
  case unexpectedData
  /// An unhandled Keychain status code was returned.
  case unhandled(OSStatus)

  var errorDescription: String? {
    switch self {
    case .duplicateItem:
      "An item with this account already exists in the Keychain."
    case .itemNotFound:
      "No matching item was found in the Keychain."
    case .unexpectedData:
      "The Keychain item data could not be decoded as a UTF-8 string."
    case .unhandled(let status):
      "Keychain operation failed with status: \(status)."
    }
  }
}

// MARK: - KeychainProviding

/// A protocol for secure credential storage via the macOS Keychain.
protocol KeychainProviding: Sendable {
  /// Saves a token string to the Keychain for the given account.
  ///
  /// If an item for the account already exists, it is updated in place.
  /// - Parameters:
  ///   - token: The secret token string to store.
  ///   - account: The account identifier (typically a GitHub username).
  func save(token: String, for account: String) throws(KeychainError)

  /// Retrieves a previously stored token from the Keychain.
  ///
  /// - Parameter account: The account identifier to look up.
  /// - Returns: The stored token string, or `nil` if no item exists.
  func retrieve(for account: String) throws(KeychainError) -> String?

  /// Deletes a stored token from the Keychain.
  ///
  /// - Parameter account: The account identifier whose token should be removed.
  func delete(for account: String) throws(KeychainError)
}

// MARK: - KeychainService

/// A concrete Keychain wrapper that stores generic-password items using the Security framework.
///
/// Uses `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, and `SecItemDelete`
/// to manage GitHub Personal Access Tokens in the macOS Keychain.
struct KeychainService: KeychainProviding {
  /// The Keychain service name used to scope stored items.
  private let serviceName: String

  /// Creates a new KeychainService.
  ///
  /// - Parameter serviceName: The Keychain service identifier. Defaults to
  ///   `"com.gitpulse.github-token"`.
  init(serviceName: String = "com.gitpulse.github-token") {
    self.serviceName = serviceName
  }

  // MARK: - Private Helpers

  /// Builds the base Keychain query dictionary for the given account.
  ///
  /// - Parameter account: The account identifier.
  /// - Returns: A dictionary suitable for use with `SecItem*` functions.
  private func baseQuery(for account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: serviceName,
      kSecAttrAccount as String: account,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
      kSecAttrSynchronizable as String: false,
      kSecUseDataProtectionKeychain as String: true,
    ]
  }

  // MARK: - KeychainProviding

  /// Saves a token string to the Keychain for the given account.
  ///
  /// Uses upsert semantics: if the item already exists, it is updated rather than
  /// producing a duplicate-item error.
  /// - Parameters:
  ///   - token: The secret token string to store.
  ///   - account: The account identifier (typically a GitHub username).
  func save(token: String, for account: String) throws(KeychainError) {
    guard let data = token.data(using: .utf8) else {
      throw .unexpectedData
    }

    var query = baseQuery(for: account)
    query[kSecValueData as String] = data

    let status = SecItemAdd(query as CFDictionary, nil)

    switch status {
    case errSecSuccess:
      return
    case errSecDuplicateItem:
      let updateAttributes: [String: Any] = [kSecValueData as String: data]
      let updateStatus = SecItemUpdate(
        baseQuery(for: account) as CFDictionary,
        updateAttributes as CFDictionary
      )
      guard updateStatus == errSecSuccess else {
        throw .unhandled(updateStatus)
      }
    default:
      throw .unhandled(status)
    }
  }

  /// Retrieves a previously stored token from the Keychain.
  ///
  /// - Parameter account: The account identifier to look up.
  /// - Returns: The stored token string, or `nil` if no item exists for this account.
  func retrieve(for account: String) throws(KeychainError) -> String? {
    var query = baseQuery(for: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      guard let data = result as? Data,
        let token = String(data: data, encoding: .utf8)
      else {
        throw .unexpectedData
      }
      return token
    case errSecItemNotFound:
      return nil
    default:
      throw .unhandled(status)
    }
  }

  /// Deletes a stored token from the Keychain.
  ///
  /// - Parameter account: The account identifier whose token should be removed.
  func delete(for account: String) throws(KeychainError) {
    let status = SecItemDelete(baseQuery(for: account) as CFDictionary)

    switch status {
    case errSecSuccess:
      return
    case errSecItemNotFound:
      throw .itemNotFound
    default:
      throw .unhandled(status)
    }
  }
}
