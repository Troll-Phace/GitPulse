//  StreaksViewModel.swift
//  GitPulse

import Foundation
import SwiftUI

// MARK: - Domain Types

/// A single day cell in the monthly streak calendar.
///
/// Used to render a calendar grid for the current month, showing which days
/// have contributions and which are empty, today, or in the future.
struct CalendarDay: Identifiable, Sendable {

  /// The start-of-day date this cell represents.
  let id: Date

  /// The day-of-month number (1-31).
  let dayNumber: Int

  /// Whether at least one contribution was recorded on this day.
  let hasContribution: Bool

  /// Whether this cell represents today's date.
  let isToday: Bool

  /// Whether this cell represents a future date.
  let isFuture: Bool

  /// Whether this is a placeholder cell before the month's first day.
  let isPlaceholder: Bool
}

/// A bar in the streak history chart.
///
/// Each bar represents a contiguous period of daily contributions,
/// with a normalized height for proportional rendering.
struct StreakBar: Identifiable, Sendable {

  /// Unique identifier for this bar.
  let id: UUID

  /// The underlying streak period with start/end dates.
  let period: StreakPeriod

  /// The bar height relative to the longest streak (0.0-1.0).
  let normalizedHeight: Double

  /// Whether this bar represents the longest streak in history.
  let isLongest: Bool

  /// Whether this bar represents the currently active streak.
  let isCurrent: Bool

  /// A compact label for display (e.g., "14d").
  let label: String
}

// MARK: - StreaksViewModel

/// Aggregates contribution data into streak-focused display values for the Streaks view.
///
/// The view model receives raw contribution and profile data via its `update` method,
/// recalculates streak information using `StreakEngine`, and exposes computed properties
/// for the streak ring, calendar grid, history bars, and warning banner.
/// All properties return sensible defaults when data is empty.
@Observable
@MainActor
final class StreaksViewModel {

  // MARK: - Input Properties

  /// All contribution events from SwiftData, typically from a `@Query`.
  var contributions: [Contribution] = []

  /// The authenticated user's profile, if available.
  var userProfile: UserProfile?

  // MARK: - Mutable State

  /// Whether the user has dismissed the streak-at-risk warning banner.
  var warningDismissed: Bool = false

  // MARK: - Private State

  /// The computed streak statistics, recalculated on each `update` call.
  private var streakInfo: StreakInfo = StreakInfo(
    current: 0,
    longest: 0,
    activeDays: 0,
    history: [],
    isActiveToday: false
  )

  // MARK: - Update

  /// Sets input properties and recalculates streak information.
  ///
  /// Call this from `.task {}` and `.onChange` modifiers in the Streaks view
  /// to keep the view model in sync with SwiftData.
  ///
  /// - Parameters:
  ///   - contributions: The latest contribution events.
  ///   - userProfile: The current user profile, if any.
  func update(
    contributions: [Contribution],
    userProfile: UserProfile?
  ) {
    self.contributions = contributions
    self.userProfile = userProfile
    self.streakInfo = StreakEngine().calculate(
      contributionDates: contributions.map(\.date)
    )
  }

  // MARK: - Computed Properties: Streak Stats

  /// The user's current consecutive-day contribution streak.
  var currentStreak: Int {
    streakInfo.current
  }

  /// The user's longest-ever consecutive-day contribution streak.
  var longestStreak: Int {
    streakInfo.longest
  }

  /// Total number of unique calendar days with at least one contribution.
  var activeDays: Int {
    streakInfo.activeDays
  }

  /// Whether the user has made a contribution today.
  var isActiveToday: Bool {
    streakInfo.isActiveToday
  }

  // MARK: - Computed Properties: Goal Progress

  /// The target streak length for the goal ring (constant for now).
  var streakGoal: Int { 30 }

  /// The progress toward the streak goal as a fraction (0.0-1.0).
  var goalProgress: Double {
    min(Double(currentStreak) / Double(streakGoal), 1.0)
  }

  /// The progress toward the streak goal as a whole percentage (0-100).
  var goalPercentage: Int {
    Int(goalProgress * 100)
  }

  // MARK: - Computed Properties: Warning Banner

  /// Whether to show the streak-at-risk warning banner.
  ///
  /// Shows when the user has an active streak but no contributions today,
  /// and the banner has not been dismissed.
  var showWarningBanner: Bool {
    !isActiveToday && currentStreak > 0 && !warningDismissed
  }

  /// The warning message text for the streak-at-risk banner.
  var warningMessage: String {
    "No commits today. Your \(currentStreak)-day streak will reset at midnight."
  }

  // MARK: - Computed Properties: Longest Streak Date Range

  /// A formatted date range string for the longest streak period (e.g., "Feb 14 - Apr 1, 2026").
  ///
  /// Returns an empty string if no streak history exists.
  var longestStreakDateRange: String {
    guard let longestPeriod = streakInfo.history.first(where: { $0.length == longestStreak }),
      longestStreak > 0
    else {
      return ""
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"

    let yearFormatter = DateFormatter()
    yearFormatter.dateFormat = "MMM d, yyyy"

    let start = formatter.string(from: longestPeriod.startDate)
    let end = yearFormatter.string(from: longestPeriod.endDate)

    return "\(start) - \(end)"
  }

  // MARK: - Computed Properties: Average Daily Commits

  /// The average number of contributions per day over the last 30 days, rounded to 1 decimal.
  var averageDailyCommits: Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) else {
      return 0.0
    }

    let recentCount = contributions.count { contribution in
      contribution.date >= thirtyDaysAgo
    }

    return (Double(recentCount) / 30.0 * 10).rounded() / 10.0
  }

  /// A formatted string comparing the last 30 days average to the previous 30 days
  /// (e.g., "+0.8 vs last month", "-0.3 vs last month", "same as last month").
  var averageDailyTrend: String {
    let (recent, previous) = averagePair
    let diff = (((recent - previous) * 10).rounded() / 10.0)

    if diff > 0 {
      return "+\(formatDecimal(diff)) vs last month"
    } else if diff < 0 {
      return "\(formatDecimal(diff)) vs last month"
    } else {
      return "same as last month"
    }
  }

  /// The trend direction comparing last 30 days average to previous 30 days.
  var averageDailyTrendDirection: TrendDirection {
    let (recent, previous) = averagePair

    if recent > previous {
      return .up
    } else if recent < previous {
      return .down
    } else {
      return .flat
    }
  }

  // MARK: - Builder Methods

  /// Builds a calendar grid of day cells for the current month.
  ///
  /// The grid includes placeholder cells for days before the month starts
  /// (to align the first day to its correct weekday column), followed by
  /// one cell per calendar day in the month.
  ///
  /// - Returns: An array of `CalendarDay` values for rendering a month grid.
  func buildCalendarDays() -> [CalendarDay] {
    let calendar = Calendar.current
    let now = Date.now
    let today = calendar.startOfDay(for: now)

    guard let monthInterval = calendar.dateInterval(of: .month, for: today),
      let range = calendar.range(of: .day, in: .month, for: today)
    else {
      return []
    }

    let firstDay = monthInterval.start
    // Calendar.weekday: Sunday=1...Saturday=7
    let firstWeekday = calendar.component(.weekday, from: firstDay)
    // Number of placeholder cells before the 1st (Sunday-start grid)
    let placeholderCount = firstWeekday - 1

    // Build contribution date set for fast lookup
    let contributionDays: Set<Date> = Set(
      contributions.map { calendar.startOfDay(for: $0.date) }
    )

    var days: [CalendarDay] = []
    days.reserveCapacity(placeholderCount + range.count)

    // Add placeholder cells
    for placeholderIndex in 0..<placeholderCount {
      let placeholderDate =
        calendar.date(
          byAdding: .day, value: -(placeholderCount - placeholderIndex), to: firstDay
        ) ?? firstDay
      days.append(
        CalendarDay(
          id: placeholderDate,
          dayNumber: 0,
          hasContribution: false,
          isToday: false,
          isFuture: false,
          isPlaceholder: true
        )
      )
    }

    // Add real day cells
    for dayNumber in range {
      guard
        let dayDate = calendar.date(
          bySetting: .day, value: dayNumber, of: firstDay
        )
      else { continue }

      let startOfDay = calendar.startOfDay(for: dayDate)
      let hasContribution = contributionDays.contains(startOfDay)
      let isToday = calendar.isDateInToday(dayDate)
      let isFuture = startOfDay > today

      days.append(
        CalendarDay(
          id: startOfDay,
          dayNumber: dayNumber,
          hasContribution: hasContribution,
          isToday: isToday,
          isFuture: isFuture,
          isPlaceholder: false
        )
      )
    }

    return days
  }

  /// Builds streak history bars for rendering a horizontal bar chart.
  ///
  /// Each bar's height is normalized relative to the longest streak in history.
  /// The longest streak is flagged, and the most recent period overlapping today
  /// or yesterday is marked as the current streak.
  ///
  /// - Returns: An array of `StreakBar` values in chronological order.
  func buildStreakHistoryBars() -> [StreakBar] {
    let history = streakInfo.history
    guard !history.isEmpty else { return [] }

    let maxLength = history.map(\.length).max() ?? 1
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

    var longestMarked = false

    return history.map { period in
      let normalized = maxLength > 0 ? Double(period.length) / Double(maxLength) : 0.0
      let isLongestCandidate = period.length == longestStreak && !longestMarked
      if isLongestCandidate {
        longestMarked = true
      }

      let isLast = period.id == history.last?.id
      let overlapsRecentDay =
        period.endDate >= yesterday
        && period.endDate <= today

      let isCurrent = isLast && overlapsRecentDay

      return StreakBar(
        id: period.id,
        period: period,
        normalizedHeight: normalized,
        isLongest: isLongestCandidate,
        isCurrent: isCurrent,
        label: "\(period.length)d"
      )
    }
  }

  // MARK: - Private Helpers

  /// Computes the average daily contribution counts for the last 30 days and the previous 30 days.
  ///
  /// - Returns: A tuple of (recentAverage, previousAverage), each rounded to 1 decimal.
  private var averagePair: (recent: Double, previous: Double) {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    guard let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today),
      let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: today)
    else {
      return (0.0, 0.0)
    }

    let recentCount = contributions.count { $0.date >= thirtyDaysAgo }
    let previousCount = contributions.count { $0.date >= sixtyDaysAgo && $0.date < thirtyDaysAgo }

    let recent = (Double(recentCount) / 30.0 * 10).rounded() / 10.0
    let previous = (Double(previousCount) / 30.0 * 10).rounded() / 10.0

    return (recent, previous)
  }

  /// Formats a Double to 1 decimal place as a string.
  ///
  /// - Parameter value: The value to format.
  /// - Returns: A string like "0.8" or "-0.3".
  private func formatDecimal(_ value: Double) -> String {
    String(format: "%.1f", value)
  }
}
