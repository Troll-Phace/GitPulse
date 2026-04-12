//  MockKeychainService.swift
//  GitPulseTests

import Foundation

@testable import GitPulse

/// In-memory mock of `KeychainProviding` for unit tests.
///
/// Stores tokens in a simple dictionary, matching the upsert-on-save
/// and throw-on-missing-delete semantics of the real `KeychainService`.
final class MockKeychainService: KeychainProviding, @unchecked Sendable {

  /// The in-memory storage backing this mock Keychain.
  private(set) var storage: [String: String] = [:]

  /// Saves a token for the given account, overwriting any existing value.
  ///
  /// Uses upsert semantics to match the real `KeychainService` behavior.
  /// - Parameters:
  ///   - token: The secret token string to store.
  ///   - account: The account identifier.
  func save(token: String, for account: String) throws(KeychainError) {
    storage[account] = token
  }

  /// Retrieves the stored token for the given account.
  ///
  /// - Parameter account: The account identifier to look up.
  /// - Returns: The stored token, or `nil` if no entry exists.
  func retrieve(for account: String) throws(KeychainError) -> String? {
    storage[account]
  }

  /// Deletes the token for the given account.
  ///
  /// - Parameter account: The account identifier whose token should be removed.
  /// - Throws: `.itemNotFound` if no token exists for the account.
  func delete(for account: String) throws(KeychainError) {
    guard storage.removeValue(forKey: account) != nil else {
      throw .itemNotFound
    }
  }
}
