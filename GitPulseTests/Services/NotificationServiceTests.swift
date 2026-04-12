//  NotificationServiceTests.swift
//  GitPulseTests

import Foundation
import Testing
@preconcurrency import UserNotifications

@testable import GitPulse

// MARK: - NotificationServiceTests

/// Comprehensive tests for the notification service's evaluation logic,
/// authorization flow, milestone deduplication, and cancellation behavior.
///
/// Each test creates an isolated `UserDefaults` suite and a fresh
/// `MockNotificationCenter` to ensure full determinism with no cross-test state.
@Suite("NotificationService")
@MainActor
struct NotificationServiceTests {

  // MARK: - Helpers

  /// Creates a `StreakInfo` with sensible defaults, allowing selective overrides.
  private func makeStreakInfo(
    current: Int = 0,
    longest: Int = 0,
    activeDays: Int = 0,
    history: [StreakPeriod] = [],
    isActiveToday: Bool = false
  ) -> StreakInfo {
    StreakInfo(
      current: current,
      longest: longest,
      activeDays: activeDays,
      history: history,
      isActiveToday: isActiveToday
    )
  }

  /// Creates an isolated `UserDefaults` instance backed by a unique suite name.
  /// Returns both the defaults and the suite name so the caller can clean up.
  private func makeDefaults() -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "test-notifications-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    return (defaults, suiteName)
  }

  /// Creates a `NotificationService` wired to the given mock and defaults.
  private func makeService(
    center: MockNotificationCenter,
    defaults: UserDefaults
  ) -> NotificationService {
    NotificationService(center: center, defaults: defaults)
  }

  /// Cleans up a test-scoped UserDefaults suite.
  private func cleanUp(suiteName: String) {
    UserDefaults.standard.removePersistentDomain(forName: suiteName)
  }

  /// Returns the first added request matching the given identifier, if any.
  private func findRequest(
    withIdentifier identifier: String,
    in mock: MockNotificationCenter
  ) -> UNNotificationRequest? {
    mock.addedRequests.first { $0.identifier == identifier }
  }

  /// Returns all added requests whose identifier starts with the given prefix.
  private func findRequests(
    withPrefix prefix: String,
    in mock: MockNotificationCenter
  ) -> [UNNotificationRequest] {
    mock.addedRequests.filter { $0.identifier.hasPrefix(prefix) }
  }

  // MARK: - Authorization

  @Test("requestAuthorization returns true when granted")
  func test_requestAuthorization_returnsTrue_whenGranted() async throws {
    let mock = MockNotificationCenter()
    mock.requestAuthorizationResult = .success(true)
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let result = try await service.requestAuthorization()

    #expect(result == true)
    #expect(mock.requestAuthorizationCallCount == 1)
  }

  @Test("requestAuthorization returns false when denied")
  func test_requestAuthorization_returnsFalse_whenDenied() async throws {
    let mock = MockNotificationCenter()
    mock.requestAuthorizationResult = .success(false)
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let result = try await service.requestAuthorization()

    #expect(result == false)
  }

  // MARK: - Streak-at-Risk

  @Test("evaluateAlerts schedules streak-at-risk when not active today and streak > 0")
  func test_evaluateAlerts_schedulesStreakAtRisk_whenNotActiveToday() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 15, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let request = findRequest(withIdentifier: NotificationIdentifier.streakAtRisk, in: mock)
    #expect(request != nil)

    let trigger = request?.trigger as? UNCalendarNotificationTrigger
    #expect(trigger?.dateComponents.hour == 21)
  }

  @Test("evaluateAlerts cancels streak-at-risk when active today")
  func test_evaluateAlerts_cancelsStreakAtRisk_whenActiveToday() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 15, isActiveToday: true)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let removedSets = mock.removedIdentifiers.flatMap { $0 }
    #expect(removedSets.contains(NotificationIdentifier.streakAtRisk))
  }

  @Test("evaluateAlerts does not schedule streak-at-risk when streak is zero")
  func test_evaluateAlerts_doesNotScheduleStreakAtRisk_whenStreakIsZero() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 0, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let request = findRequest(withIdentifier: NotificationIdentifier.streakAtRisk, in: mock)
    #expect(request == nil)
  }

  // MARK: - Streak-Broken

  @Test("evaluateAlerts schedules streak-broken when streak drops to zero")
  func test_evaluateAlerts_schedulesStreakBroken_whenStreakDropsToZero() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }

    // Simulate a previous streak of 10
    defaults.set(10, forKey: "lastKnownStreak")

    let service = makeService(center: mock, defaults: defaults)
    let info = makeStreakInfo(current: 0, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let request = findRequest(withIdentifier: NotificationIdentifier.streakBroken, in: mock)
    #expect(request != nil)
  }

  @Test("evaluateAlerts does not schedule streak-broken when no preexisting streak")
  func test_evaluateAlerts_noStreakBroken_whenNoPreexistingStreak() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }

    // lastKnownStreak defaults to 0 (not set)
    let service = makeService(center: mock, defaults: defaults)
    let info = makeStreakInfo(current: 0, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let request = findRequest(withIdentifier: NotificationIdentifier.streakBroken, in: mock)
    #expect(request == nil)
  }

  // MARK: - Daily Summary

  @Test("evaluateAlerts schedules daily summary with hour 22")
  func test_evaluateAlerts_schedulesDailySummary() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 5, isActiveToday: true)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 10,
      totalPRsMerged: 2,
      todayCommits: 3,
      todayPRs: 1
    )

    let request = findRequest(withIdentifier: NotificationIdentifier.dailySummary, in: mock)
    #expect(request != nil)

    let trigger = request?.trigger as? UNCalendarNotificationTrigger
    #expect(trigger?.dateComponents.hour == 22)
  }

  // MARK: - Milestones (Parameterized)

  @Test(
    "evaluateAlerts fires milestone for streak thresholds",
    arguments: [7, 30, 50, 100, 365]
  )
  func test_evaluateAlerts_firesMilestone_forStreakThresholds(threshold: Int) async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: threshold, isActiveToday: true)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let milestoneRequests = findRequests(
      withPrefix: NotificationIdentifier.milestonePrefix, in: mock
    )
    let identifiers = milestoneRequests.map(\.identifier)
    let expectedId = "\(NotificationIdentifier.milestonePrefix)-streak-\(threshold)"
    #expect(identifiers.contains(expectedId))
  }

  @Test(
    "evaluateAlerts fires milestone for commit thresholds",
    arguments: [100, 500, 1000, 5000]
  )
  func test_evaluateAlerts_firesMilestone_forCommitThresholds(threshold: Int) async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 0, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: threshold,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let milestoneRequests = findRequests(
      withPrefix: NotificationIdentifier.milestonePrefix, in: mock
    )
    let identifiers = milestoneRequests.map(\.identifier)
    let expectedId = "\(NotificationIdentifier.milestonePrefix)-commits-\(threshold)"
    #expect(identifiers.contains(expectedId))
  }

  @Test(
    "evaluateAlerts fires milestone for PR thresholds",
    arguments: [10, 50, 100]
  )
  func test_evaluateAlerts_firesMilestone_forPRThresholds(threshold: Int) async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 0, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: threshold,
      todayCommits: 0,
      todayPRs: 0
    )

    let milestoneRequests = findRequests(
      withPrefix: NotificationIdentifier.milestonePrefix, in: mock
    )
    let identifiers = milestoneRequests.map(\.identifier)
    let expectedId = "\(NotificationIdentifier.milestonePrefix)-prs-\(threshold)"
    #expect(identifiers.contains(expectedId))
  }

  // MARK: - Milestone Deduplication

  @Test("evaluateAlerts does not repeat milestone when already notified")
  func test_evaluateAlerts_doesNotRepeatMilestone_whenAlreadyNotified() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    let info = makeStreakInfo(current: 7, isActiveToday: true)

    // First evaluation -- milestone should fire
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let firstCallMilestoneCount = findRequests(
      withPrefix: NotificationIdentifier.milestonePrefix, in: mock
    ).count

    // Second evaluation with same data -- no new milestone
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let secondCallMilestoneCount = findRequests(
      withPrefix: NotificationIdentifier.milestonePrefix, in: mock
    ).count

    // The count should not have increased between calls
    #expect(secondCallMilestoneCount == firstCallMilestoneCount)
  }

  // MARK: - Configuration

  @Test("evaluateAlerts uses configured alert hour for streak-at-risk")
  func test_evaluateAlerts_usesConfiguredAlertHour() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }

    defaults.set(18, forKey: "streakAlertHour")

    let service = makeService(center: mock, defaults: defaults)
    let info = makeStreakInfo(current: 5, isActiveToday: false)
    try await service.evaluateAlerts(
      streakInfo: info,
      totalCommits: 0,
      totalPRsMerged: 0,
      todayCommits: 0,
      todayPRs: 0
    )

    let request = findRequest(withIdentifier: NotificationIdentifier.streakAtRisk, in: mock)
    let trigger = request?.trigger as? UNCalendarNotificationTrigger
    #expect(trigger?.dateComponents.hour == 18)
  }

  // MARK: - Cancel All

  @Test("cancelAllScheduledNotifications removes known identifiers")
  func test_cancelAllScheduledNotifications_removesKnownIdentifiers() async throws {
    let mock = MockNotificationCenter()
    let (defaults, suiteName) = makeDefaults()
    defer { cleanUp(suiteName: suiteName) }
    let service = makeService(center: mock, defaults: defaults)

    service.cancelAllScheduledNotifications()

    let allRemoved = mock.removedIdentifiers.flatMap { $0 }
    #expect(allRemoved.contains(NotificationIdentifier.streakAtRisk))
    #expect(allRemoved.contains(NotificationIdentifier.dailySummary))
    #expect(allRemoved.contains(NotificationIdentifier.streakBroken))
  }
}
