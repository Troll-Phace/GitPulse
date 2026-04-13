//  StreaksViewModelTests.swift
//  GitPulseTests

import Foundation
import SwiftData
import Testing

@testable import GitPulse

// MARK: - StreaksViewModelTests

/// Comprehensive tests for the streaks view model's computed statistics,
/// goal progress, warning banner, calendar grid builder, streak history
/// bars, average daily commits, and trend direction.
///
/// Contributions are created directly without inserting into a container
/// since no `@Relationship` properties are involved.
@Suite("StreaksViewModel")
@MainActor
struct StreaksViewModelTests {

  // MARK: - Helpers

  /// Creates a `Contribution` with sensible defaults.
  private func makeContribution(
    id: String = UUID().uuidString,
    type: Contribution.ContributionType = .push,
    date: Date = .now,
    repositoryName: String = "test-repo",
    repositoryOwner: String = "testuser",
    message: String? = nil,
    additions: Int = 10,
    deletions: Int = 5,
    commitCount: Int = 1
  ) -> Contribution {
    Contribution(
      id: id,
      type: type,
      date: date,
      repositoryName: repositoryName,
      repositoryOwner: repositoryOwner,
      message: message,
      additions: additions,
      deletions: deletions,
      commitCount: commitCount
    )
  }

  /// Creates a `UserProfile` with sensible defaults.
  private func makeUserProfile(
    username: String = "testuser",
    currentStreak: Int = 0,
    longestStreak: Int = 0,
    activeDays: Int = 0,
    totalContributions: Int = 0
  ) -> UserProfile {
    UserProfile(
      username: username,
      avatarURL: "https://example.com/avatar.png",
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      activeDays: activeDays,
      totalContributions: totalContributions
    )
  }

  /// Returns a `Date` at the start of the calendar day `days` before today.
  private func daysAgo(_ days: Int) -> Date {
    Calendar.current.date(
      byAdding: .day, value: -days,
      to: Calendar.current.startOfDay(for: .now)
    )!
  }

  /// Returns the start of today.
  private var startOfToday: Date {
    Calendar.current.startOfDay(for: .now)
  }

  // MARK: - Empty State Tests

  @Test("Empty contributions returns zero streak values")
  func test_streaks_emptyContributions_returnsZeroStreakValues() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    #expect(vm.currentStreak == 0)
    #expect(vm.longestStreak == 0)
    #expect(vm.activeDays == 0)
    #expect(vm.isActiveToday == false)
  }

  @Test("Empty state warning banner is hidden when currentStreak is zero")
  func test_streaks_emptyState_warningBannerHidden() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    #expect(vm.showWarningBanner == false)
  }

  @Test("Empty contributions calendar returns non-empty array for current month")
  func test_streaks_emptyContributions_calendarReturnsNonEmptyArray() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    let days = vm.buildCalendarDays()

    #expect(!days.isEmpty)
  }

  // MARK: - Streak Value Tests

  @Test("Current streak computed from 5 consecutive days of contributions")
  func test_streaks_currentStreak_fiveConsecutiveDays() {
    let vm = StreaksViewModel()

    // Contributions for today and 4 previous consecutive days
    let contributions = (0...4).map { i in
      makeContribution(id: "streak-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.currentStreak == 5)
  }

  @Test("Longest streak reflects the longer of two streak periods")
  func test_streaks_longestStreak_reflectsLongerPeriod() {
    let vm = StreaksViewModel()

    // First streak: 3 days ending 10 days ago (days 12, 11, 10)
    // Gap at day 9
    // Second streak: today through 2 days ago (days 0, 1, 2) = 3 days
    // Longer streak: 4 days ending 20 days ago (days 23, 22, 21, 20)
    var contributions: [Contribution] = []

    // Longer historical streak: 4 days
    for i in 20...23 {
      contributions.append(makeContribution(id: "long-\(i)", date: daysAgo(i)))
    }

    // Recent streak: 3 days (today, yesterday, 2 days ago)
    for i in 0...2 {
      contributions.append(makeContribution(id: "recent-\(i)", date: daysAgo(i)))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.longestStreak == 4)
    #expect(vm.currentStreak == 3)
  }

  @Test("Active days count matches unique day count")
  func test_streaks_activeDays_matchesUniqueDayCount() {
    let vm = StreaksViewModel()

    // 3 unique days: today, 2 days ago, 5 days ago
    // Two contributions on today to verify deduplication
    let contributions = [
      makeContribution(id: "today-1", date: daysAgo(0)),
      makeContribution(id: "today-2", date: daysAgo(0)),
      makeContribution(id: "two-ago", date: daysAgo(2)),
      makeContribution(id: "five-ago", date: daysAgo(5)),
    ]

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.activeDays == 3)
  }

  @Test("isActiveToday is true when today has contributions")
  func test_streaks_isActiveToday_trueWhenTodayHasContributions() {
    let vm = StreaksViewModel()

    let contributions = [
      makeContribution(id: "now", date: Date.now)
    ]

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.isActiveToday == true)
  }

  // MARK: - Goal Progress Tests

  @Test("Goal progress fraction is 0.5 when streak is 15 and goal is 30")
  func test_streaks_goalProgress_halfWayAt15() {
    let vm = StreaksViewModel()

    // Build a 15-day streak (today + 14 previous days)
    let contributions = (0..<15).map { i in
      makeContribution(id: "goal-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.currentStreak == 15)
    #expect(vm.goalProgress == 0.5)
  }

  @Test("Goal progress capped at 1.0 when streak exceeds goal")
  func test_streaks_goalProgress_cappedAtOneWhenExceedsGoal() {
    let vm = StreaksViewModel()

    // Build a 45-day streak
    let contributions = (0..<45).map { i in
      makeContribution(id: "over-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.currentStreak == 45)
    #expect(vm.goalProgress == 1.0)
  }

  @Test("Goal percentage is Int of goalProgress times 100")
  func test_streaks_goalPercentage_isIntOfProgressTimes100() {
    let vm = StreaksViewModel()

    // 15 day streak, goal = 30 => 50%
    let contributions = (0..<15).map { i in
      makeContribution(id: "pct-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.goalPercentage == Int(vm.goalProgress * 100))
    #expect(vm.goalPercentage == 50)
  }

  // MARK: - Warning Banner Tests

  @Test("Warning shows when streak active from yesterday but no today contribution")
  func test_streaks_warningBanner_showsWhenStreakActiveButNoToday() {
    let vm = StreaksViewModel()

    // Streak from yesterday and day before only (grace period: still counted)
    let contributions = [
      makeContribution(id: "y-1", date: daysAgo(1)),
      makeContribution(id: "y-2", date: daysAgo(2)),
    ]

    vm.update(contributions: contributions, userProfile: nil)

    // StreakEngine should report a current streak via grace period but isActiveToday = false
    #expect(vm.currentStreak > 0)
    #expect(vm.isActiveToday == false)
    #expect(vm.showWarningBanner == true)
  }

  @Test("Warning hidden when warningDismissed is true")
  func test_streaks_warningBanner_hiddenWhenDismissed() {
    let vm = StreaksViewModel()

    // Set up streak from yesterday
    let contributions = [
      makeContribution(id: "wd-1", date: daysAgo(1)),
      makeContribution(id: "wd-2", date: daysAgo(2)),
    ]

    vm.update(contributions: contributions, userProfile: nil)
    vm.warningDismissed = true

    #expect(vm.showWarningBanner == false)
  }

  @Test("Warning hidden when today is active")
  func test_streaks_warningBanner_hiddenWhenTodayActive() {
    let vm = StreaksViewModel()

    // Streak including today
    let contributions = [
      makeContribution(id: "wa-0", date: daysAgo(0)),
      makeContribution(id: "wa-1", date: daysAgo(1)),
    ]

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.isActiveToday == true)
    #expect(vm.showWarningBanner == false)
  }

  @Test("Warning message includes the current streak count")
  func test_streaks_warningMessage_includesStreakCount() {
    let vm = StreaksViewModel()

    // 3-day streak from yesterday (days 1, 2, 3)
    let contributions = (1...3).map { i in
      makeContribution(id: "msg-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    let streakCount = vm.currentStreak
    #expect(vm.warningMessage.contains("\(streakCount)"))
  }

  // MARK: - Calendar Tests

  @Test("Calendar days count matches placeholders plus days in current month")
  func test_streaks_calendarDays_countMatchesPlaceholdersPlusDaysInMonth() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    let days = vm.buildCalendarDays()

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let range = calendar.range(of: .day, in: .month, for: today)!
    let monthInterval = calendar.dateInterval(of: .month, for: today)!
    let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
    let placeholderCount = firstWeekday - 1

    #expect(days.count == placeholderCount + range.count)
  }

  @Test("Exactly one non-placeholder calendar day is marked as today")
  func test_streaks_calendarDays_exactlyOneTodayMarked() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    let days = vm.buildCalendarDays()
    let nonPlaceholderDays = days.filter { !$0.isPlaceholder }
    let todayDays = nonPlaceholderDays.filter(\.isToday)

    #expect(todayDays.count == 1)
  }

  @Test("Future days after today are marked with isFuture true")
  func test_streaks_calendarDays_futureDaysMarkedCorrectly() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    let days = vm.buildCalendarDays()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let nonPlaceholderDays = days.filter { !$0.isPlaceholder }
    for day in nonPlaceholderDays {
      if day.id > today {
        #expect(day.isFuture == true)
      } else {
        #expect(day.isFuture == false)
      }
    }
  }

  @Test("Contribution days are marked with hasContribution true in calendar")
  func test_streaks_calendarDays_contributionDaysMarked() {
    let vm = StreaksViewModel()

    // Add contribution today and 2 days ago (both should be in the current month for this test)
    let contributions = [
      makeContribution(id: "cal-0", date: daysAgo(0)),
      makeContribution(id: "cal-2", date: daysAgo(2)),
    ]

    vm.update(contributions: contributions, userProfile: nil)

    let days = vm.buildCalendarDays()
    let calendar = Calendar.current

    let todayCell = days.first {
      !$0.isPlaceholder && calendar.isDate($0.id, inSameDayAs: startOfToday)
    }
    #expect(todayCell?.hasContribution == true)

    let twoDaysAgoDate = daysAgo(2)
    // Only check if 2 days ago is still in the current month
    if calendar.isDate(twoDaysAgoDate, equalTo: startOfToday, toGranularity: .month) {
      let twoAgoCell = days.first {
        !$0.isPlaceholder && calendar.isDate($0.id, inSameDayAs: twoDaysAgoDate)
      }
      #expect(twoAgoCell?.hasContribution == true)
    }
  }

  // MARK: - Streak History Bars Tests

  @Test("Empty history returns empty bars array")
  func test_streaks_historyBars_emptyWhenNoContributions() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    let bars = vm.buildStreakHistoryBars()

    #expect(bars.isEmpty)
  }

  @Test("Longest bar has normalizedHeight of 1.0")
  func test_streaks_historyBars_longestBarNormalizedToOne() {
    let vm = StreaksViewModel()

    // Two streak periods:
    // Period 1: 10 days ending 20 days ago (days 20-29)
    // Period 2: 3 days ending today (days 0-2)
    var contributions: [Contribution] = []

    for i in 20...29 {
      contributions.append(makeContribution(id: "long-bar-\(i)", date: daysAgo(i)))
    }
    for i in 0...2 {
      contributions.append(makeContribution(id: "short-bar-\(i)", date: daysAgo(i)))
    }

    vm.update(contributions: contributions, userProfile: nil)

    let bars = vm.buildStreakHistoryBars()
    let maxBar = bars.max(by: { $0.normalizedHeight < $1.normalizedHeight })

    #expect(maxBar?.normalizedHeight == 1.0)
  }

  @Test("Exactly one bar is flagged as isLongest")
  func test_streaks_historyBars_exactlyOneLongestFlagged() {
    let vm = StreaksViewModel()

    // Two streak periods of different lengths
    var contributions: [Contribution] = []
    for i in 15...20 {
      contributions.append(makeContribution(id: "hist-a-\(i)", date: daysAgo(i)))
    }
    for i in 0...2 {
      contributions.append(makeContribution(id: "hist-b-\(i)", date: daysAgo(i)))
    }

    vm.update(contributions: contributions, userProfile: nil)

    let bars = vm.buildStreakHistoryBars()
    let longestBars = bars.filter(\.isLongest)

    #expect(longestBars.count == 1)
  }

  @Test("Current bar is flagged when last period overlaps today or yesterday")
  func test_streaks_historyBars_currentBarFlaggedWhenOverlapsRecent() {
    let vm = StreaksViewModel()

    // Current streak: today + yesterday + 2 days ago
    let contributions = (0...2).map { i in
      makeContribution(id: "current-bar-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    let bars = vm.buildStreakHistoryBars()
    let currentBars = bars.filter(\.isCurrent)

    #expect(currentBars.count == 1)
  }

  // MARK: - Average Daily Commits Tests

  @Test("Average daily commits computed over last 30 days")
  func test_streaks_averageDailyCommits_computedOverLast30Days() {
    let vm = StreaksViewModel()

    // 15 contributions in the last 30 days => 15/30 = 0.5
    let contributions = (0..<15).map { i in
      makeContribution(id: "avg-\(i)", date: daysAgo(i * 2))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.averageDailyCommits == 0.5)
  }

  @Test("Trend direction is up when recent 30 days exceed previous 30 days")
  func test_streaks_trendDirection_upWhenRecentExceedsPrevious() {
    let vm = StreaksViewModel()

    var contributions: [Contribution] = []

    // 20 contributions in last 30 days
    for i in 0..<20 {
      contributions.append(makeContribution(id: "up-recent-\(i)", date: daysAgo(i)))
    }

    // 5 contributions in previous 30 days (days 30-59)
    for i in 0..<5 {
      contributions.append(
        makeContribution(id: "up-prev-\(i)", date: daysAgo(30 + i))
      )
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.averageDailyTrendDirection == .up)
  }

  @Test("Trend direction is down when recent 30 days fewer than previous 30 days")
  func test_streaks_trendDirection_downWhenRecentFewerThanPrevious() {
    let vm = StreaksViewModel()

    var contributions: [Contribution] = []

    // 3 contributions in last 30 days
    for i in 0..<3 {
      contributions.append(makeContribution(id: "down-recent-\(i)", date: daysAgo(i)))
    }

    // 20 contributions in previous 30 days (days 30-59)
    for i in 0..<20 {
      contributions.append(
        makeContribution(id: "down-prev-\(i)", date: daysAgo(30 + i))
      )
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.averageDailyTrendDirection == .down)
  }

  // MARK: - Longest Streak Date Range Test

  @Test("Longest streak date range returns non-empty formatted string")
  func test_streaks_longestStreakDateRange_returnsFormattedString() {
    let vm = StreaksViewModel()

    // Build a streak from 10 days ago through 5 days ago (6 days)
    // and a current streak of 2 days (today + yesterday)
    var contributions: [Contribution] = []
    for i in 5...10 {
      contributions.append(makeContribution(id: "range-long-\(i)", date: daysAgo(i)))
    }
    for i in 0...1 {
      contributions.append(makeContribution(id: "range-cur-\(i)", date: daysAgo(i)))
    }

    vm.update(contributions: contributions, userProfile: nil)

    #expect(!vm.longestStreakDateRange.isEmpty)
    #expect(vm.longestStreakDateRange.contains("-"))
  }

  @Test("Longest streak date range is empty when no history")
  func test_streaks_longestStreakDateRange_emptyWhenNoHistory() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    #expect(vm.longestStreakDateRange.isEmpty)
  }

  // MARK: - Additional Edge Cases

  @Test("Single day streak produces current streak of 1")
  func test_streaks_singleDayStreak_currentStreakIsOne() {
    let vm = StreaksViewModel()

    let contributions = [
      makeContribution(id: "single", date: daysAgo(0))
    ]

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.currentStreak == 1)
    #expect(vm.longestStreak == 1)
    #expect(vm.activeDays == 1)
  }

  @Test("Streak broken by gap resets current streak to zero")
  func test_streaks_gapBreaksStreak_currentStreakZero() {
    let vm = StreaksViewModel()

    // Contributions only 5 and 6 days ago (no today, no yesterday)
    let contributions = [
      makeContribution(id: "gap-5", date: daysAgo(5)),
      makeContribution(id: "gap-6", date: daysAgo(6)),
    ]

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.currentStreak == 0)
    #expect(vm.longestStreak == 2)
  }

  @Test("Goal progress is zero when no contributions")
  func test_streaks_goalProgress_zeroWithNoContributions() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    #expect(vm.goalProgress == 0.0)
    #expect(vm.goalPercentage == 0)
  }

  @Test("Average daily commits is zero with no contributions")
  func test_streaks_averageDailyCommits_zeroWithNoContributions() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    #expect(vm.averageDailyCommits == 0.0)
  }

  @Test("Trend direction is flat when both periods have zero contributions")
  func test_streaks_trendDirection_flatWhenBothPeriodsZero() {
    let vm = StreaksViewModel()
    vm.update(contributions: [], userProfile: nil)

    #expect(vm.averageDailyTrendDirection == .flat)
  }

  @Test("History bars label contains the period length followed by d")
  func test_streaks_historyBars_labelContainsLengthAndD() {
    let vm = StreaksViewModel()

    // 5-day streak ending today
    let contributions = (0..<5).map { i in
      makeContribution(id: "label-\(i)", date: daysAgo(i))
    }

    vm.update(contributions: contributions, userProfile: nil)

    let bars = vm.buildStreakHistoryBars()

    #expect(!bars.isEmpty)
    #expect(bars[0].label == "5d")
  }

  @Test("Multiple contributions same day counted as single active day")
  func test_streaks_multipleContributionsSameDay_singleActiveDay() {
    let vm = StreaksViewModel()

    let contributions = [
      makeContribution(id: "dup-1", date: daysAgo(0)),
      makeContribution(id: "dup-2", date: daysAgo(0)),
      makeContribution(id: "dup-3", date: daysAgo(0)),
    ]

    vm.update(contributions: contributions, userProfile: nil)

    #expect(vm.activeDays == 1)
    #expect(vm.currentStreak == 1)
  }

  @Test("Update replaces previous state completely")
  func test_streaks_update_replacesPreviousState() {
    let vm = StreaksViewModel()

    // First update: 5-day streak
    let first = (0..<5).map { i in
      makeContribution(id: "first-\(i)", date: daysAgo(i))
    }
    vm.update(contributions: first, userProfile: nil)
    #expect(vm.currentStreak == 5)

    // Second update: empty
    vm.update(contributions: [], userProfile: nil)
    #expect(vm.currentStreak == 0)
    #expect(vm.longestStreak == 0)
    #expect(vm.activeDays == 0)
  }
}
