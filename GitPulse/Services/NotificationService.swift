//  NotificationService.swift
//  GitPulse

import Foundation
@preconcurrency import UserNotifications

// MARK: - GitPulseNotification

/// Types of notifications GitPulse can send to the user.
enum GitPulseNotification {
  /// The user's streak is at risk because no contributions have been recorded today.
  case streakAtRisk(currentStreak: Int, hoursRemaining: Int)
  /// A daily summary of the user's activity.
  case dailySummary(commits: Int, prs: Int)
  /// A milestone achievement has been reached.
  case milestone(type: MilestoneType, value: Int)
  /// The user's contribution streak has been broken.
  case streakBroken(wasLength: Int)
}

// MARK: - MilestoneType

/// Categories of milestones that trigger celebration notifications.
enum MilestoneType {
  /// A streak duration milestone (e.g., 7, 30, 50, 100, 365 days).
  case streak(days: Int)
  /// A total commit count milestone (e.g., 100, 500, 1000, 5000).
  case totalCommits(count: Int)
  /// A total merged PR count milestone (e.g., 10, 50, 100).
  case totalPRsMerged(count: Int)
}

// MARK: - NotificationError

/// Errors that can occur during notification operations.
enum NotificationError: Error, LocalizedError {
  /// The user denied notification authorization.
  case authorizationDenied
  /// A notification could not be scheduled.
  case schedulingFailed(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .authorizationDenied:
      "Notification authorization was denied by the user."
    case .schedulingFailed(let underlying):
      "Failed to schedule notification: \(underlying.localizedDescription)"
    }
  }
}

// MARK: - NotificationIdentifier

/// Notification identifier constants matching ARCHITECTURE.md section 7.6.
enum NotificationIdentifier {
  /// Identifier for streak-at-risk alerts.
  static let streakAtRisk = "streak-at-risk"
  /// Identifier for daily summary notifications.
  static let dailySummary = "daily-summary"
  /// Prefix for milestone achievement notifications.
  static let milestonePrefix = "milestone-reached"
  /// Identifier for streak-broken notifications.
  static let streakBroken = "streak-broken"
}

// MARK: - UserDefaults Keys

/// UserDefaults keys used by the notification service.
private enum NotificationDefaultsKey {
  /// The hour (0–23) at which streak-at-risk alerts fire. Default: 21 (9 PM).
  static let streakAlertHour = "streakAlertHour"
  /// The last known streak value, used to detect streak-broken transitions.
  static let lastKnownStreak = "lastKnownStreak"
  /// An array of milestone keys that have already been notified.
  static let notifiedMilestones = "notifiedMilestones"
}

// MARK: - NotificationCenterProviding

/// A thin abstraction over `UNUserNotificationCenter` for testability.
///
/// All methods mirror the corresponding `UNUserNotificationCenter` API surface
/// needed by `NotificationService`.
protocol NotificationCenterProviding: Sendable {
  /// Requests authorization for notifications with the specified options.
  ///
  /// - Parameter options: The notification authorization options to request.
  /// - Returns: `true` if the user granted authorization.
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

  /// Adds a notification request to the notification center.
  ///
  /// - Parameter request: The notification request to schedule.
  func add(_ request: UNNotificationRequest) async throws

  /// Removes pending notification requests with the specified identifiers.
  ///
  /// - Parameter identifiers: The identifiers of the requests to remove.
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])

  /// Returns all pending notification requests.
  ///
  /// - Returns: An array of pending notification requests.
  func pendingNotificationRequests() async -> [UNNotificationRequest]
}

// MARK: - SystemNotificationCenter

/// Concrete implementation of `NotificationCenterProviding` that delegates
/// to `UNUserNotificationCenter.current()`.
struct SystemNotificationCenter: NotificationCenterProviding {

  /// Requests notification authorization from the system.
  ///
  /// - Parameter options: The authorization options to request.
  /// - Returns: `true` if the user granted authorization.
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    try await UNUserNotificationCenter.current().requestAuthorization(options: options)
  }

  /// Adds a notification request to the system notification center.
  ///
  /// - Parameter request: The notification request to schedule.
  func add(_ request: UNNotificationRequest) async throws {
    try await UNUserNotificationCenter.current().add(request)
  }

  /// Removes pending notification requests with the specified identifiers.
  ///
  /// - Parameter identifiers: The identifiers of the requests to remove.
  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    UNUserNotificationCenter.current().removePendingNotificationRequests(
      withIdentifiers: identifiers
    )
  }

  /// Returns all pending notification requests from the system.
  ///
  /// - Returns: An array of pending notification requests.
  func pendingNotificationRequests() async -> [UNNotificationRequest] {
    await UNUserNotificationCenter.current().pendingNotificationRequests()
  }
}

// MARK: - NotificationProviding

/// A protocol defining the interface for the notification service.
///
/// Implementations manage authorization, alert evaluation, and cancellation
/// of local notifications for streak and milestone tracking.
protocol NotificationProviding: Sendable {
  /// Requests notification authorization from the user.
  ///
  /// - Returns: `true` if the user granted authorization.
  func requestAuthorization() async throws(NotificationError) -> Bool

  /// Evaluates the current user state and schedules or cancels notifications as needed.
  ///
  /// Called after each sync cycle to determine which notifications should fire.
  ///
  /// - Parameters:
  ///   - streakInfo: The current streak statistics.
  ///   - totalCommits: The total number of contributions recorded.
  ///   - totalPRsMerged: The total number of merged pull requests.
  ///   - todayCommits: The number of commits made today.
  ///   - todayPRs: The number of pull requests created today.
  func evaluateAlerts(
    streakInfo: StreakInfo,
    totalCommits: Int,
    totalPRsMerged: Int,
    todayCommits: Int,
    todayPRs: Int
  ) async throws(NotificationError)

  /// Cancels all scheduled GitPulse notifications.
  func cancelAllScheduledNotifications()
}

// MARK: - NotificationService

/// Manages local notification scheduling for streak alerts, daily summaries,
/// and milestone celebrations.
///
/// Uses `UNUserNotificationCenter` (via a protocol abstraction) to schedule
/// time-based and immediate notifications. All state (last known streak,
/// notified milestones) is persisted in `UserDefaults`.
struct NotificationService: NotificationProviding {

  /// The notification center used to schedule and manage notifications.
  private let center: NotificationCenterProviding

  /// The UserDefaults store for notification preferences and state.
  private let defaults: UserDefaults

  /// Creates a new notification service.
  ///
  /// - Parameters:
  ///   - center: The notification center to use. Defaults to `SystemNotificationCenter()`.
  ///   - defaults: The UserDefaults store for preferences. Defaults to `.standard`.
  init(
    center: NotificationCenterProviding = SystemNotificationCenter(),
    defaults: UserDefaults = .standard
  ) {
    self.center = center
    self.defaults = defaults
  }

  // MARK: - Milestone Thresholds

  /// Streak day thresholds that trigger milestone notifications.
  private static let streakThresholds = [7, 30, 50, 100, 365]

  /// Total commit count thresholds that trigger milestone notifications.
  private static let commitThresholds = [100, 500, 1000, 5000]

  /// Total merged PR count thresholds that trigger milestone notifications.
  private static let prThresholds = [10, 50, 100]

  // MARK: - NotificationProviding

  /// Requests notification authorization from the user.
  ///
  /// Requests alert, badge, and sound permissions.
  ///
  /// - Returns: `true` if the user granted authorization.
  func requestAuthorization() async throws(NotificationError) -> Bool {
    do {
      return try await center.requestAuthorization(options: [.alert, .badge, .sound])
    } catch {
      throw .schedulingFailed(underlying: error)
    }
  }

  /// Evaluates the current user state and schedules or cancels notifications as needed.
  ///
  /// The evaluation follows this order:
  /// 1. Read the previous `lastKnownStreak` before updating.
  /// 2. Detect and schedule streak-broken notifications.
  /// 3. Schedule or cancel streak-at-risk notifications.
  /// 4. Schedule the daily summary.
  /// 5. Check and fire any new milestone notifications.
  /// 6. Update `lastKnownStreak` with the current value.
  ///
  /// - Parameters:
  ///   - streakInfo: The current streak statistics.
  ///   - totalCommits: The total number of contributions recorded.
  ///   - totalPRsMerged: The total number of merged pull requests.
  ///   - todayCommits: The number of commits made today.
  ///   - todayPRs: The number of pull requests created today.
  func evaluateAlerts(
    streakInfo: StreakInfo,
    totalCommits: Int,
    totalPRsMerged: Int,
    todayCommits: Int,
    todayPRs: Int
  ) async throws(NotificationError) {
    // 1. Read previous streak value BEFORE updating
    let previousStreak = defaults.integer(forKey: NotificationDefaultsKey.lastKnownStreak)

    // 2. Streak-broken detection
    if streakInfo.current == 0 && previousStreak > 0 {
      try await scheduleStreakBroken(wasLength: previousStreak)
    }

    // 3. Streak-at-risk or cancel
    if !streakInfo.isActiveToday && streakInfo.current > 0 {
      try await scheduleStreakAtRisk(currentStreak: streakInfo.current)
    } else if streakInfo.isActiveToday {
      center.removePendingNotificationRequests(
        withIdentifiers: [NotificationIdentifier.streakAtRisk]
      )
    }

    // 4. Daily summary
    try await scheduleDailySummary(commits: todayCommits, prs: todayPRs)

    // 5. Milestones
    try await checkAndFireMilestones(
      streakDays: streakInfo.current,
      totalCommits: totalCommits,
      totalPRsMerged: totalPRsMerged
    )

    // 6. Update lastKnownStreak with current value
    defaults.set(streakInfo.current, forKey: NotificationDefaultsKey.lastKnownStreak)
  }

  /// Cancels all scheduled GitPulse notifications.
  ///
  /// Removes all known fixed-identifier notifications and any milestone-prefixed ones.
  func cancelAllScheduledNotifications() {
    let fixedIdentifiers = [
      NotificationIdentifier.streakAtRisk,
      NotificationIdentifier.dailySummary,
      NotificationIdentifier.streakBroken,
    ]

    center.removePendingNotificationRequests(withIdentifiers: fixedIdentifiers)

    // Cancel milestone notifications asynchronously
    Task {
      let pending = await center.pendingNotificationRequests()
      let milestoneIdentifiers =
        pending
        .map(\.identifier)
        .filter { $0.hasPrefix(NotificationIdentifier.milestonePrefix) }

      if !milestoneIdentifiers.isEmpty {
        center.removePendingNotificationRequests(withIdentifiers: milestoneIdentifiers)
      }
    }
  }

  // MARK: - Private Scheduling Helpers

  /// Schedules a streak-at-risk notification at the configured alert hour.
  ///
  /// The notification fires today at the configured hour (default 21:00) if
  /// that time has not yet passed.
  ///
  /// - Parameter currentStreak: The current streak length to include in the message.
  private func scheduleStreakAtRisk(currentStreak: Int) async throws(NotificationError) {
    let content = UNMutableNotificationContent()
    content.title = "Streak at Risk!"
    content.body =
      "Your \(currentStreak)-day streak is at risk! Make a contribution to keep it alive."
    content.sound = .default

    let alertHour = defaults.object(forKey: NotificationDefaultsKey.streakAlertHour) as? Int ?? 21

    var dateComponents = DateComponents()
    dateComponents.hour = alertHour
    dateComponents.minute = 0

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    let request = UNNotificationRequest(
      identifier: NotificationIdentifier.streakAtRisk,
      content: content,
      trigger: trigger
    )

    do {
      try await center.add(request)
    } catch {
      throw .schedulingFailed(underlying: error)
    }
  }

  /// Schedules a streak-broken notification at 00:05.
  ///
  /// Fires shortly after midnight to inform the user that their streak has ended.
  ///
  /// - Parameter wasLength: The length of the streak that was broken.
  private func scheduleStreakBroken(wasLength: Int) async throws(NotificationError) {
    let content = UNMutableNotificationContent()
    content.title = "Streak Broken"
    content.body = "Your \(wasLength)-day streak has ended. Start a new one today!"
    content.sound = .default

    var dateComponents = DateComponents()
    dateComponents.hour = 0
    dateComponents.minute = 5

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    let request = UNNotificationRequest(
      identifier: NotificationIdentifier.streakBroken,
      content: content,
      trigger: trigger
    )

    do {
      try await center.add(request)
    } catch {
      throw .schedulingFailed(underlying: error)
    }
  }

  /// Schedules a daily summary notification at the configured hour (default 22:00).
  ///
  /// Replaces any previously scheduled daily summary by using the same identifier.
  ///
  /// - Parameters:
  ///   - commits: The number of commits made today.
  ///   - prs: The number of pull requests created today.
  private func scheduleDailySummary(commits: Int, prs: Int) async throws(NotificationError) {
    let content = UNMutableNotificationContent()
    content.title = "Daily Summary"
    content.body = "Today: \(commits) commits, \(prs) pull requests."
    content.sound = .default

    var dateComponents = DateComponents()
    dateComponents.hour = 22
    dateComponents.minute = 0

    let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    let request = UNNotificationRequest(
      identifier: NotificationIdentifier.dailySummary,
      content: content,
      trigger: trigger
    )

    do {
      try await center.add(request)
    } catch {
      throw .schedulingFailed(underlying: error)
    }
  }

  /// Checks current values against milestone thresholds and fires notifications for new ones.
  ///
  /// Each milestone is tracked by a unique key (e.g., `"streak-7"`, `"commits-1000"`).
  /// Once notified, the key is stored in UserDefaults to prevent duplicate notifications.
  ///
  /// - Parameters:
  ///   - streakDays: The current streak in days.
  ///   - totalCommits: The total number of contributions.
  ///   - totalPRsMerged: The total number of merged pull requests.
  private func checkAndFireMilestones(
    streakDays: Int,
    totalCommits: Int,
    totalPRsMerged: Int
  ) async throws(NotificationError) {
    var notified = notifiedMilestoneKeys()

    // Check streak milestones
    for threshold in Self.streakThresholds where streakDays >= threshold {
      let key = "streak-\(threshold)"
      if !notified.contains(key) {
        try await scheduleMilestone(
          key: key,
          title: "Milestone Reached!",
          body: "Amazing! You've hit a \(threshold)-day contribution streak!"
        )
        notified.insert(key)
        markMilestoneNotified(key)
      }
    }

    // Check commit milestones
    for threshold in Self.commitThresholds where totalCommits >= threshold {
      let key = "commits-\(threshold)"
      if !notified.contains(key) {
        try await scheduleMilestone(
          key: key,
          title: "Milestone Reached!",
          body: "You've reached \(threshold) total contributions!"
        )
        notified.insert(key)
        markMilestoneNotified(key)
      }
    }

    // Check PR milestones
    for threshold in Self.prThresholds where totalPRsMerged >= threshold {
      let key = "prs-\(threshold)"
      if !notified.contains(key) {
        try await scheduleMilestone(
          key: key,
          title: "Milestone Reached!",
          body: "You've merged \(threshold) pull requests!"
        )
        notified.insert(key)
        markMilestoneNotified(key)
      }
    }
  }

  /// Schedules an immediate milestone notification with the given key.
  ///
  /// - Parameters:
  ///   - key: The milestone key (e.g., `"streak-7"`), used to build the identifier.
  ///   - title: The notification title.
  ///   - body: The notification body text.
  private func scheduleMilestone(
    key: String,
    title: String,
    body: String
  ) async throws(NotificationError) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let identifier = "\(NotificationIdentifier.milestonePrefix)-\(key)"
    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: nil  // immediate delivery
    )

    do {
      try await center.add(request)
    } catch {
      throw .schedulingFailed(underlying: error)
    }
  }

  /// Reads the set of milestone keys that have already been notified.
  ///
  /// - Returns: A set of milestone key strings (e.g., `"streak-7"`, `"commits-500"`).
  private func notifiedMilestoneKeys() -> Set<String> {
    let array = defaults.stringArray(forKey: NotificationDefaultsKey.notifiedMilestones) ?? []
    return Set(array)
  }

  /// Records a milestone key as having been notified.
  ///
  /// Appends the key to the persisted array in UserDefaults.
  ///
  /// - Parameter key: The milestone key to mark as notified.
  private func markMilestoneNotified(_ key: String) {
    var array = defaults.stringArray(forKey: NotificationDefaultsKey.notifiedMilestones) ?? []
    array.append(key)
    defaults.set(array, forKey: NotificationDefaultsKey.notifiedMilestones)
  }
}
