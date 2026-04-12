//  MockNotificationCenter.swift
//  GitPulseTests

import Foundation
@preconcurrency import UserNotifications

@testable import GitPulse

/// In-memory mock of `NotificationCenterProviding` for unit tests.
///
/// Tracks call counts, captures arguments, and returns configurable results
/// so tests can verify notification scheduling behavior without touching
/// the real `UNUserNotificationCenter`.
final class MockNotificationCenter: NotificationCenterProviding, @unchecked Sendable {

  // MARK: - Stubs

  /// The result to return from `requestAuthorization(options:)`.
  var requestAuthorizationResult: Result<Bool, Error> = .success(true)

  /// An optional error that `add(_:)` will throw when non-nil.
  var addShouldThrow: Error?

  /// Pending notification requests returned by `pendingNotificationRequests()`.
  var stubbedPendingRequests: [UNNotificationRequest] = []

  // MARK: - Call Tracking

  /// The number of times `requestAuthorization(options:)` has been called.
  private(set) var requestAuthorizationCallCount = 0

  /// The number of times `add(_:)` has been called.
  private(set) var addCallCount = 0

  /// All notification requests passed to `add(_:)`, in order.
  private(set) var addedRequests: [UNNotificationRequest] = []

  /// All identifier arrays passed to `removePendingNotificationRequests(withIdentifiers:)`.
  private(set) var removedIdentifiers: [[String]] = []

  /// The number of times `pendingNotificationRequests()` has been called.
  private(set) var pendingNotificationRequestsCallCount = 0

  // MARK: - NotificationCenterProviding

  /// Returns the configured `requestAuthorizationResult`.
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    requestAuthorizationCallCount += 1
    return try requestAuthorizationResult.get()
  }

  /// Records the request and optionally throws the configured error.
  func add(_ request: UNNotificationRequest) async throws {
    addCallCount += 1
    addedRequests.append(request)
    if let error = addShouldThrow {
      throw error
    }
  }

  /// Records the identifiers for later assertion.
  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    removedIdentifiers.append(identifiers)
  }

  /// Returns the stubbed pending requests.
  func pendingNotificationRequests() async -> [UNNotificationRequest] {
    pendingNotificationRequestsCallCount += 1
    return stubbedPendingRequests
  }
}
