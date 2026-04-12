//  StreakEngineTests.swift
//  GitPulseTests

import Foundation
import Testing

@testable import GitPulse

// MARK: - StreakEngineTests

/// Comprehensive tests for the timezone-aware streak calculation engine.
///
/// All tests use a fixed reference date (2025-06-15 at noon ET) and explicit
/// timezones to ensure determinism regardless of the host machine's locale.
@Suite("StreakEngine")
@MainActor
struct StreakEngineTests {

  private let engine = StreakEngine()

  /// Eastern Time — used as the default user timezone for most tests.
  private let eastern = TimeZone(identifier: "America/New_York")!

  /// UTC — used for cross-timezone comparison tests.
  private let utc = TimeZone(identifier: "UTC")!

  /// A fixed reference "now": 2025-06-15 at 12:00:00 noon Eastern Time.
  private let referenceDate: Date = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    let components = DateComponents(
      year: 2025, month: 6, day: 15, hour: 12, minute: 0, second: 0
    )
    return calendar.date(from: components)!
  }()

  // MARK: - Helpers

  /// Creates a deterministic date from explicit components in a given timezone.
  private func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 12,
    minute: Int = 0,
    timeZone: TimeZone? = nil
  ) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone ?? eastern
    let components = DateComponents(
      year: year, month: month, day: day, hour: hour, minute: minute, second: 0
    )
    guard let date = calendar.date(from: components) else {
      fatalError("Failed to create date from components: \(year)-\(month)-\(day) \(hour):\(minute)")
    }
    return date
  }

  /// Creates a range of consecutive dates from startDay to endDay (inclusive)
  /// in the given month/year, all at noon in the eastern timezone.
  private func makeDateRange(
    year: Int,
    month: Int,
    startDay: Int,
    endDay: Int,
    timeZone: TimeZone? = nil
  ) -> [Date] {
    (startDay...endDay).map { day in
      makeDate(year: year, month: month, day: day, timeZone: timeZone)
    }
  }

  // MARK: - Empty & Single-Element Inputs

  /// Empty input should produce all-zero results with no history.
  @Test("Empty input returns all zeros")
  func emptyInput_returnsAllZeros() {
    let result = engine.calculate(
      contributionDates: [],
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 0)
    #expect(result.longest == 0)
    #expect(result.activeDays == 0)
    #expect(result.history.isEmpty)
    #expect(result.isActiveToday == false)
  }

  /// A single contribution on "today" should yield a streak of 1, active today.
  @Test("Single contribution today returns streak of 1")
  func singleContributionToday_returnsStreakOne() {
    let dates = [makeDate(year: 2025, month: 6, day: 15)]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 1)
    #expect(result.isActiveToday == true)
    #expect(result.activeDays == 1)
    #expect(result.longest == 1)
    #expect(result.history.count == 1)
  }

  /// A single contribution yesterday (nothing today) should still report
  /// current=1 via the grace period, but isActiveToday=false.
  @Test("Single contribution yesterday uses grace period")
  func singleContributionYesterday_graceStreakOne() {
    let dates = [makeDate(year: 2025, month: 6, day: 14)]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 1)
    #expect(result.isActiveToday == false)
    #expect(result.activeDays == 1)
  }

  // MARK: - Multi-Day Streaks

  /// Three consecutive days ending today should produce a current streak of 3.
  @Test("Three consecutive days ending today gives streak of 3")
  func threeDayStreak_correctCurrent() {
    let dates = [
      makeDate(year: 2025, month: 6, day: 13),
      makeDate(year: 2025, month: 6, day: 14),
      makeDate(year: 2025, month: 6, day: 15),
    ]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 3)
    #expect(result.isActiveToday == true)
    #expect(result.longest == 3)
  }

  /// A gap in contributions should break the streak. Today + yesterday form
  /// a 2-day current streak; an older 2-day block is a separate period.
  @Test("Gap in contributions breaks the streak")
  func brokenStreak_stopsAtGap() {
    // Current period: June 14–15 (2 days)
    // Gap: June 13
    // Old period: June 11–12 (2 days)
    let dates = [
      makeDate(year: 2025, month: 6, day: 11),
      makeDate(year: 2025, month: 6, day: 12),
      makeDate(year: 2025, month: 6, day: 14),
      makeDate(year: 2025, month: 6, day: 15),
    ]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 2)
    #expect(result.longest == 2)
    #expect(result.history.count == 2)
  }

  /// The longest streak is historical and longer than the current one.
  @Test("Longest streak is identified even when not current")
  func longestNotCurrent_identifiedCorrectly() {
    // Old 10-day streak: June 1–10
    var dates = makeDateRange(year: 2025, month: 6, startDay: 1, endDay: 10)
    // Gap: June 11–12
    // Current 3-day streak: June 13–15
    dates += makeDateRange(year: 2025, month: 6, startDay: 13, endDay: 15)

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 3)
    #expect(result.longest == 10)
    #expect(result.isActiveToday == true)
    #expect(result.history.count == 2)
  }

  // MARK: - Grace Period

  /// A 5-day streak ending yesterday (nothing today) should report current=5
  /// via the grace period, with isActiveToday=false.
  @Test("Grace period preserves 5-day streak ending yesterday")
  func gracePeriod_fiveDayStreakEndingYesterday() {
    // June 10–14 (5 days), nothing on June 15 (today)
    let dates = makeDateRange(year: 2025, month: 6, startDay: 10, endDay: 14)

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 5)
    #expect(result.isActiveToday == false)
    #expect(result.longest == 5)
  }

  /// If the most recent contribution is 2+ days ago, the streak is broken.
  @Test("Streak broken when last contribution is 2+ days ago")
  func nothingTodayOrYesterday_streakBroken() {
    // Streak ending June 12, nothing on June 13/14/15
    let dates = makeDateRange(year: 2025, month: 6, startDay: 8, endDay: 12)

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 0)
    #expect(result.isActiveToday == false)
    #expect(result.longest == 5)
  }

  // MARK: - Deduplication

  /// Multiple contributions on the same local day should count as one active day.
  @Test("Multiple contributions on same day count as one active day")
  func multipleContributionsSameDay_oneActiveDay() {
    // 5 contributions all on June 15 at different hours
    let dates = [
      makeDate(year: 2025, month: 6, day: 15, hour: 8, minute: 0),
      makeDate(year: 2025, month: 6, day: 15, hour: 10, minute: 30),
      makeDate(year: 2025, month: 6, day: 15, hour: 12, minute: 0),
      makeDate(year: 2025, month: 6, day: 15, hour: 18, minute: 45),
      makeDate(year: 2025, month: 6, day: 15, hour: 23, minute: 59),
    ]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.activeDays == 1)
    #expect(result.current == 1)
    #expect(result.isActiveToday == true)
  }

  // MARK: - Timezone Edge Cases

  /// A UTC timestamp of 2025-06-15T03:30:00Z is June 14 at 11:30 PM in ET.
  /// With referenceDate = June 15 noon ET, that contribution falls on "yesterday"
  /// in ET, so grace period gives current=1 with isActiveToday=false.
  @Test("UTC date crossing local midnight maps to correct local day")
  func utcDateCrossesLocalMidnight_correctDay() {
    // 03:30 UTC on June 15 = 11:30 PM ET on June 14
    let date = makeDate(
      year: 2025, month: 6, day: 15, hour: 3, minute: 30, timeZone: utc
    )

    let result = engine.calculate(
      contributionDates: [date],
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 1)
    #expect(result.isActiveToday == false)
    #expect(result.activeDays == 1)
  }

  /// The same UTC timestamp should produce different results when calculated
  /// in different timezones. 2025-06-15T03:30:00Z is:
  ///   - June 15 03:30 in UTC (today for a UTC observer) -> current=1, isActiveToday=true
  ///   - June 14 23:30 in EDT (yesterday for an ET observer) -> current=1, isActiveToday=false
  /// Note: In June, Eastern Time is EDT (UTC-4), so 03:30 UTC = 23:30 EDT on June 14.
  @Test("Same UTC date yields different results in different timezones")
  func differentTimezones_differentResults() {
    // 03:30 UTC on June 15 = June 15 in UTC, but June 14 at 23:30 in EDT
    let date = makeDate(
      year: 2025, month: 6, day: 15, hour: 3, minute: 30, timeZone: utc
    )

    // In UTC: reference is also June 15, so this is "today"
    let utcReference = makeDate(
      year: 2025, month: 6, day: 15, hour: 12, minute: 0, timeZone: utc
    )

    let resultUTC = engine.calculate(
      contributionDates: [date],
      timeZone: utc,
      referenceDate: utcReference
    )

    // In ET (EDT in June): 03:30 UTC = 23:30 EDT on June 14.
    // Reference is June 15 noon ET. So contribution is on "yesterday".
    let resultET = engine.calculate(
      contributionDates: [date],
      timeZone: eastern,
      referenceDate: referenceDate
    )

    // UTC: today has the contribution
    #expect(resultUTC.current == 1)
    #expect(resultUTC.isActiveToday == true)

    // ET: yesterday has the contribution (grace period)
    #expect(resultET.current == 1)
    #expect(resultET.isActiveToday == false)
  }

  // MARK: - Streak History

  /// Three distinct activity periods separated by gaps should produce
  /// three entries in the history array with correct boundaries.
  @Test("Multiple streak periods all appear in history")
  func multipleStreakPeriods_historyContainsAll() {
    // Period 1: June 1–3 (3 days)
    var dates = makeDateRange(year: 2025, month: 6, startDay: 1, endDay: 3)
    // Gap: June 4
    // Period 2: June 5–6 (2 days)
    dates += makeDateRange(year: 2025, month: 6, startDay: 5, endDay: 6)
    // Gap: June 7–13
    // Period 3: June 14–15 (2 days, current)
    dates += makeDateRange(year: 2025, month: 6, startDay: 14, endDay: 15)

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.history.count == 3)

    // Verify chronological ordering and lengths via the history array.
    // Periods are sorted ascending by start date.
    let lengths = result.history.map(\.length)
    #expect(lengths == [3, 2, 2])
  }

  /// A single long streak should produce exactly one history entry whose
  /// length matches the streak duration.
  @Test("Single 30-day streak produces one history entry")
  func singleLongStreak_onePeriodCorrectLength() {
    // May 17 through June 15 = 30 days
    var dates: [Date] = []
    // May 17–31 = 15 days
    dates += makeDateRange(year: 2025, month: 5, startDay: 17, endDay: 31)
    // June 1–15 = 15 days
    dates += makeDateRange(year: 2025, month: 6, startDay: 1, endDay: 15)

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.history.count == 1)
    #expect(result.history[0].length == 30)
    #expect(result.current == 30)
    #expect(result.longest == 30)
    #expect(result.isActiveToday == true)
  }

  // MARK: - Active Days

  /// 10 contributions spread across 7 unique local days (some days have
  /// multiple contributions) should yield activeDays=7.
  @Test("Active days counts unique local days correctly")
  func activeDays_matchesUniqueLocalDays() {
    let dates = [
      // Day 1: June 9 (2 contributions)
      makeDate(year: 2025, month: 6, day: 9, hour: 8),
      makeDate(year: 2025, month: 6, day: 9, hour: 20),
      // Day 2: June 10
      makeDate(year: 2025, month: 6, day: 10),
      // Day 3: June 11 (2 contributions)
      makeDate(year: 2025, month: 6, day: 11, hour: 9),
      makeDate(year: 2025, month: 6, day: 11, hour: 15),
      // Day 4: June 12
      makeDate(year: 2025, month: 6, day: 12),
      // Day 5: June 13 (2 contributions)
      makeDate(year: 2025, month: 6, day: 13, hour: 7),
      makeDate(year: 2025, month: 6, day: 13, hour: 22),
      // Day 6: June 14
      makeDate(year: 2025, month: 6, day: 14),
      // Day 7: June 15
      makeDate(year: 2025, month: 6, day: 15),
    ]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.activeDays == 7)
    #expect(result.current == 7)
  }

  // MARK: - Future Contributions

  /// Contributions in the future (after today) should be included in
  /// activeDays and history, but the current streak only counts backward
  /// from today. So today = current 1, future days do not extend it.
  @Test("Future contributions do not extend current streak")
  func futureContributions_ignoredForCurrent() {
    let dates = [
      makeDate(year: 2025, month: 6, day: 15),  // today
      makeDate(year: 2025, month: 6, day: 16),  // tomorrow
      makeDate(year: 2025, month: 6, day: 17),  // day after
    ]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    // Current streak: only today (the engine walks backward from today)
    #expect(result.current == 1)
    #expect(result.isActiveToday == true)
    // But all three days are counted as active
    #expect(result.activeDays == 3)
    // History will contain one period spanning June 15–17
    #expect(result.history.count == 1)
  }

  // MARK: - Unsorted & Duplicate Input

  /// The engine should handle unsorted input correctly by sorting internally.
  @Test("Unsorted input is handled correctly")
  func unsortedInput_producesCorrectResult() {
    // Dates deliberately out of order
    let dates = [
      makeDate(year: 2025, month: 6, day: 15),
      makeDate(year: 2025, month: 6, day: 13),
      makeDate(year: 2025, month: 6, day: 14),
      makeDate(year: 2025, month: 6, day: 11),
      makeDate(year: 2025, month: 6, day: 12),
    ]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    // June 11–15 = 5 consecutive days
    #expect(result.current == 5)
    #expect(result.longest == 5)
    #expect(result.history.count == 1)
  }

  /// Duplicate timestamps (exact same Date values) should be deduplicated.
  @Test("Duplicate timestamps are deduplicated")
  func duplicateTimestamps_deduplicated() {
    let sameDate = makeDate(year: 2025, month: 6, day: 15, hour: 10)
    let dates = [sameDate, sameDate, sameDate]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.activeDays == 1)
    #expect(result.current == 1)
    #expect(result.history.count == 1)
  }

  // MARK: - Far-Past Contribution

  /// A single contribution far in the past (months ago) should have
  /// current=0 (too old for grace period) but activeDays=1 and one history entry.
  @Test("Far-past contribution yields current streak of 0")
  func farPastContribution_currentStreakZero() {
    let dates = [makeDate(year: 2025, month: 1, day: 1)]

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == 0)
    #expect(result.isActiveToday == false)
    #expect(result.activeDays == 1)
    #expect(result.longest == 1)
    #expect(result.history.count == 1)
  }

  // MARK: - Parameterized Tests

  nonisolated(unsafe) static let scenarios: [StreakScenario] = [
    StreakScenario(
      label: "Today only",
      relativeDays: [0],
      expectedCurrent: 1,
      expectedLongest: 1,
      expectedActiveDays: 1,
      expectedHistoryCount: 1,
      expectedIsActiveToday: true
    ),
    StreakScenario(
      label: "Week-long streak ending today",
      relativeDays: [-6, -5, -4, -3, -2, -1, 0],
      expectedCurrent: 7,
      expectedLongest: 7,
      expectedActiveDays: 7,
      expectedHistoryCount: 1,
      expectedIsActiveToday: true
    ),
    StreakScenario(
      label: "Yesterday only (grace period)",
      relativeDays: [-1],
      expectedCurrent: 1,
      expectedLongest: 1,
      expectedActiveDays: 1,
      expectedHistoryCount: 1,
      expectedIsActiveToday: false
    ),
    StreakScenario(
      label: "Two separate single-day periods",
      relativeDays: [-5, 0],
      expectedCurrent: 1,
      expectedLongest: 1,
      expectedActiveDays: 2,
      expectedHistoryCount: 2,
      expectedIsActiveToday: true
    ),
  ]

  @Test("Parameterized streak scenarios", arguments: scenarios)
  func parameterized_streakScenarios(scenario: StreakScenario) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = eastern

    let dates = scenario.relativeDays.map { offset in
      calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? referenceDate
    }

    let result = engine.calculate(
      contributionDates: dates,
      timeZone: eastern,
      referenceDate: referenceDate
    )

    #expect(result.current == scenario.expectedCurrent)
    #expect(result.longest == scenario.expectedLongest)
    #expect(result.activeDays == scenario.expectedActiveDays)
    #expect(result.history.count == scenario.expectedHistoryCount)
    #expect(result.isActiveToday == scenario.expectedIsActiveToday)
  }
}

// MARK: - StreakScenario

/// A parameterized test case scenario for the streak engine.
struct StreakScenario: CustomStringConvertible, Sendable {
  let label: String
  /// Days relative to the reference date (0 = today, -1 = yesterday, etc.)
  let relativeDays: [Int]
  let expectedCurrent: Int
  let expectedLongest: Int
  let expectedActiveDays: Int
  let expectedHistoryCount: Int
  let expectedIsActiveToday: Bool

  var description: String { label }
}
