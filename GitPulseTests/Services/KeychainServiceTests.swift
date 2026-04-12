//  KeychainServiceTests.swift
//  GitPulseTests

import Foundation
import Testing

@testable import GitPulse

// MARK: - KeychainServiceTests

/// Integration tests that exercise the real `KeychainService` against the macOS Keychain.
///
/// Each test instance uses a unique service name (UUID-based) to avoid polluting the
/// user's real Keychain and to prevent cross-test interference. Every test also performs
/// explicit cleanup of any items it creates.
@Suite("KeychainService integration")
@MainActor
struct KeychainServiceTests {

  private let service: KeychainService
  private let testAccount = "test-user"
  private let testToken = "ghp_test1234567890"

  init() {
    service = KeychainService(
      serviceName: "com.gitpulse.tests.keychain-\(UUID().uuidString)"
    )
  }

  // MARK: - Happy Path

  @Test("Save and retrieve round-trips correctly")
  func test_keychain_saveAndRetrieve_roundTrip() throws {
    try service.save(token: testToken, for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == testToken)

    try? service.delete(for: testAccount)
  }

  @Test("Retrieve returns nil for nonexistent account")
  func test_keychain_retrieve_returnsNilForNonexistent() throws {
    let result = try service.retrieve(for: "nonexistent-account")
    #expect(result == nil)
  }

  @Test("Save to existing account updates the token")
  func test_keychain_saveExistingAccount_updatesToken() throws {
    let firstToken = "ghp_first_token_value"
    let secondToken = "ghp_second_token_value"

    try service.save(token: firstToken, for: testAccount)
    try service.save(token: secondToken, for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == secondToken)

    try? service.delete(for: testAccount)
  }

  // MARK: - Deletion

  @Test("Delete removes a stored token")
  func test_keychain_delete_removesStoredToken() throws {
    try service.save(token: testToken, for: testAccount)
    try service.delete(for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == nil)
  }

  @Test("Delete nonexistent account throws itemNotFound")
  func test_keychain_delete_nonexistent_throwsItemNotFound() {
    #expect(throws: KeychainError.itemNotFound) {
      try service.delete(for: "account-that-does-not-exist")
    }
  }

  // MARK: - Multiple Accounts

  @Test("Multiple accounts are stored in isolation")
  func test_keychain_multipleAccounts_isolation() throws {
    let accountA = "user-alpha"
    let accountB = "user-beta"
    let tokenA = "ghp_alpha_token"
    let tokenB = "ghp_beta_token"

    try service.save(token: tokenA, for: accountA)
    try service.save(token: tokenB, for: accountB)

    let retrievedA = try service.retrieve(for: accountA)
    let retrievedB = try service.retrieve(for: accountB)

    #expect(retrievedA == tokenA)
    #expect(retrievedB == tokenB)

    try? service.delete(for: accountA)
    try? service.delete(for: accountB)
  }

  // MARK: - Edge Cases

  @Test("Empty string token round-trips correctly")
  func test_keychain_emptyToken_roundTrips() throws {
    try service.save(token: "", for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == "")

    try? service.delete(for: testAccount)
  }

  @Test("Unicode token round-trips correctly")
  func test_keychain_unicodeToken_roundTrips() throws {
    let unicodeToken = "ghp_t\u{00F6}k\u{00E9}n_\u{1F511}_\u{00FC}nicode_\u{2603}"

    try service.save(token: unicodeToken, for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == unicodeToken)

    try? service.delete(for: testAccount)
  }

  @Test("Long token (1000+ characters) round-trips correctly")
  func test_keychain_longToken_roundTrips() throws {
    let longToken = String(repeating: "abcdefghij", count: 120)
    #expect(longToken.count == 1200)

    try service.save(token: longToken, for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == longToken)

    try? service.delete(for: testAccount)
  }

  @Test("Delete then save again for the same account succeeds")
  func test_keychain_deleteThenSaveAgain_works() throws {
    let firstToken = "ghp_original"
    let secondToken = "ghp_replacement"

    try service.save(token: firstToken, for: testAccount)
    try service.delete(for: testAccount)

    // Verify the token is gone
    let afterDelete = try service.retrieve(for: testAccount)
    #expect(afterDelete == nil)

    // Save a new token to the same account
    try service.save(token: secondToken, for: testAccount)

    let retrieved = try service.retrieve(for: testAccount)
    #expect(retrieved == secondToken)

    try? service.delete(for: testAccount)
  }
}

// MARK: - MockKeychainServiceTests

/// Tests verifying that `MockKeychainService` faithfully reproduces the
/// contract of `KeychainProviding`, so tests using the mock are trustworthy.
@Suite("MockKeychainService fidelity")
@MainActor
struct MockKeychainServiceTests {

  @Test("Save and retrieve round-trips correctly")
  func test_mock_saveAndRetrieve_roundTrip() throws {
    let mock = MockKeychainService()

    try mock.save(token: "ghp_mock_token", for: "mock-user")

    let retrieved = try mock.retrieve(for: "mock-user")
    #expect(retrieved == "ghp_mock_token")
  }

  @Test("Delete nonexistent account throws itemNotFound")
  func test_mock_delete_nonexistent_throwsItemNotFound() {
    let mock = MockKeychainService()

    #expect(throws: KeychainError.itemNotFound) {
      try mock.delete(for: "does-not-exist")
    }
  }

  @Test("Save to existing account upserts the value")
  func test_mock_upsert_updatesExistingValue() throws {
    let mock = MockKeychainService()

    try mock.save(token: "ghp_old", for: "user")
    try mock.save(token: "ghp_new", for: "user")

    let retrieved = try mock.retrieve(for: "user")
    #expect(retrieved == "ghp_new")
    #expect(mock.storage.count == 1)
  }
}
