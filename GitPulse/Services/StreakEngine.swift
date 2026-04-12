//  StreakEngine.swift
//  GitPulse

import Foundation

// MARK: - Domain Types

/// A contiguous period of daily contribution activity.
///
/// Each period represents a run of consecutive calendar days (in the user's
/// local time zone) where at least one contribution was recorded.
struct StreakPeriod: Identifiable, Sendable, Equatable {

  /// Unique identifier for this streak period.
  let id: UUID

  /// The first calendar day of this streak period (start of day in user's time zone).
  let startDate: Date

  /// The last calendar day of this streak period (start of day in user's time zone).
  let endDate: Date

  /// The number of days in this streak period, inclusive of both start and end.
  var length: Int {
    (Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
  }
}

/// A snapshot of all streak-related statistics derived from contribution dates.
struct StreakInfo: Sendable, Equatable {

  /// The user's current active streak in days.
  let current: Int

  /// The longest streak ever recorded.
  let longest: Int

  /// Total number of unique calendar days with at least one contribution.
  let activeDays: Int

  /// Chronological list of all contiguous contribution periods.
  let history: [StreakPeriod]

  /// Whether the user has made a contribution today (in their local time zone).
  let isActiveToday: Bool
}

// MARK: - StreakEngine

/// A pure, timezone-aware streak calculation engine.
///
/// `StreakEngine` converts UTC contribution timestamps into the user's local
/// calendar days and then computes current streak, longest streak, active day
/// count, and a full history of contiguous activity periods.
///
/// The engine is stateless and `Sendable`; all inputs are passed per call.
struct StreakEngine: Sendable {

  /// Calculates streak statistics from UTC contribution dates.
  ///
  /// - Parameters:
  ///   - contributionDates: An array of `Date` values representing UTC timestamps
  ///     of individual contributions. Duplicates and ordering are handled internally.
  ///   - timeZone: The user's local time zone, used to determine calendar-day
  ///     boundaries. Defaults to `.autoupdatingCurrent`.
  ///   - referenceDate: The "now" anchor for determining "today" and the current
  ///     streak. Defaults to `.now`. Pass an explicit value in tests.
  /// - Returns: A ``StreakInfo`` value with computed statistics.
  func calculate(
    contributionDates: [Date],
    timeZone: TimeZone = .autoupdatingCurrent,
    referenceDate: Date = .now
  ) -> StreakInfo {
    guard !contributionDates.isEmpty else {
      return StreakInfo(
        current: 0,
        longest: 0,
        activeDays: 0,
        history: [],
        isActiveToday: false
      )
    }

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone

    let uniqueDays = uniqueLocalDays(from: contributionDates, calendar: calendar)
    let (currentStreak, isActiveToday) = calculateCurrentStreak(
      uniqueDays: uniqueDays,
      today: referenceDate,
      calendar: calendar
    )
    let history = buildStreakPeriods(from: uniqueDays, calendar: calendar)
    let longestStreak = history.map(\.length).max() ?? 0

    return StreakInfo(
      current: currentStreak,
      longest: longestStreak,
      activeDays: uniqueDays.count,
      history: history,
      isActiveToday: isActiveToday
    )
  }

  // MARK: - Private Helpers

  /// Converts UTC dates into deduplicated, sorted local-day dates.
  ///
  /// - Parameters:
  ///   - dates: Raw UTC contribution timestamps.
  ///   - calendar: A calendar configured with the user's time zone.
  /// - Returns: Sorted ascending array of unique start-of-day dates in the user's time zone.
  private func uniqueLocalDays(from dates: [Date], calendar: Calendar) -> [Date] {
    let startOfDays = dates.map { calendar.startOfDay(for: $0) }
    let unique = Set(startOfDays)
    return unique.sorted()
  }

  /// Determines the current streak length and whether today is active.
  ///
  /// The algorithm checks today first, then yesterday. If neither has
  /// contributions the current streak is zero. When today has no contributions
  /// but yesterday does, a "grace period" applies: the streak reflects the
  /// run ending yesterday while `isActiveToday` is `false`.
  ///
  /// - Parameters:
  ///   - uniqueDays: Sorted, deduplicated local-day dates.
  ///   - today: The reference "now" date.
  ///   - calendar: A calendar configured with the user's time zone.
  /// - Returns: A tuple of the streak length and whether today has contributions.
  private func calculateCurrentStreak(
    uniqueDays: [Date],
    today: Date,
    calendar: Calendar
  ) -> (current: Int, isActiveToday: Bool) {
    let todayStart = calendar.startOfDay(for: today)
    let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

    let daySet = Set(uniqueDays)
    let hasToday = daySet.contains(todayStart)
    let hasYesterday = daySet.contains(yesterdayStart)

    var streak: Int
    var checkDate: Date

    if hasToday {
      streak = 1
      checkDate = yesterdayStart
    } else if hasYesterday {
      streak = 0
      checkDate = yesterdayStart
    } else {
      return (0, false)
    }

    // Walk backward through consecutive days
    while daySet.contains(checkDate) {
      streak += 1
      checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
    }

    return (streak, hasToday)
  }

  /// Builds an array of contiguous activity periods from sorted unique days.
  ///
  /// Walks the sorted days forward, grouping consecutive calendar days into
  /// ``StreakPeriod`` values. A gap of more than one day between entries
  /// closes the current period and starts a new one.
  ///
  /// - Parameters:
  ///   - uniqueDays: Sorted ascending array of unique local-day dates.
  ///   - calendar: A calendar configured with the user's time zone.
  /// - Returns: An array of ``StreakPeriod`` values in chronological order.
  private func buildStreakPeriods(from uniqueDays: [Date], calendar: Calendar) -> [StreakPeriod] {
    guard let first = uniqueDays.first else { return [] }

    var periods: [StreakPeriod] = []
    var periodStart = first
    var periodEnd = first

    for day in uniqueDays.dropFirst() {
      let nextExpected = calendar.date(byAdding: .day, value: 1, to: periodEnd) ?? periodEnd

      if calendar.isDate(day, inSameDayAs: nextExpected) {
        periodEnd = day
      } else {
        periods.append(StreakPeriod(id: UUID(), startDate: periodStart, endDate: periodEnd))
        periodStart = day
        periodEnd = day
      }
    }

    // Close the final period
    periods.append(StreakPeriod(id: UUID(), startDate: periodStart, endDate: periodEnd))

    return periods
  }
}
