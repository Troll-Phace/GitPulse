//  DashboardViewModelTests.swift
//  GitPulseTests

import Foundation
import SwiftData
import Testing

@testable import GitPulse

// MARK: - DashboardViewModelTests

/// Comprehensive tests for the dashboard view model's computed statistics,
/// heatmap generation, weekly activity builder, activity feed, and status text.
///
/// Tests that involve `Repository`/`LanguageStat` relationships use an in-memory
/// `ModelContainer` so the `@Relationship` property works correctly. Simpler
/// model types (Contribution, PullRequest, UserProfile, SyncMetadata) are created
/// directly without a container when relationships are not involved.
@Suite("DashboardViewModel")
@MainActor
struct DashboardViewModelTests {

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

  /// Creates a `Repository` and inserts it into the given context so
  /// the `@Relationship` property for `languages` is functional.
  private func makeRepository(
    context: ModelContext,
    id: Int = Int.random(in: 1...100_000),
    name: String = "test-repo",
    fullName: String = "testuser/test-repo",
    language: String? = "Swift",
    starCount: Int = 0,
    languages: [LanguageStat] = []
  ) -> Repository {
    let now = Date()
    let repo = Repository(
      id: id,
      name: name,
      fullName: fullName,
      language: language,
      starCount: starCount,
      createdAt: now,
      updatedAt: now,
      languages: languages
    )
    context.insert(repo)
    return repo
  }

  /// Creates a `PullRequest` with sensible defaults.
  private func makePullRequest(
    id: Int = Int.random(in: 1...100_000),
    number: Int = 1,
    title: String = "Test PR",
    state: PullRequest.PRState = .open,
    repositoryFullName: String = "testuser/test-repo",
    createdAt: Date = .now,
    mergedAt: Date? = nil,
    closedAt: Date? = nil
  ) -> PullRequest {
    PullRequest(
      id: id,
      number: number,
      title: title,
      state: state,
      repositoryFullName: repositoryFullName,
      createdAt: createdAt,
      mergedAt: mergedAt,
      closedAt: closedAt
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

  /// Creates a `SyncMetadata` with sensible defaults.
  private func makeSyncMetadata(
    date: Date = .now,
    rateLimitRemaining: Int = 4500,
    rateLimitReset: Date = Date.now.addingTimeInterval(3600)
  ) -> SyncMetadata {
    SyncMetadata(
      key: "lastSync",
      date: date,
      eventsProcessed: 100,
      rateLimitRemaining: rateLimitRemaining,
      rateLimitReset: rateLimitReset
    )
  }

  /// Returns a `Date` representing the start of today.
  private var startOfToday: Date {
    Calendar.current.startOfDay(for: .now)
  }

  /// Returns a `Date` representing the start of yesterday.
  private var startOfYesterday: Date {
    Calendar.current.date(byAdding: .day, value: -1, to: startOfToday)!
  }

  // MARK: - Empty State

  @Test("Empty state returns zero counts, nil language, and default text")
  func test_dashboard_emptyState_returnsDefaults() {
    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitCount == 0)
    #expect(vm.activePRCount == 0)
    #expect(vm.currentStreak == 0)
    #expect(vm.longestStreak == 0)
    #expect(vm.languageCount == 0)
    #expect(vm.topLanguage == nil)
    #expect(vm.totalContributionsInPeriod == 0)
    #expect(vm.lastSyncedText == "Never")
    #expect(vm.rateLimitText == "Unknown")
  }

  @Test("Empty state heatmap returns 112 cells all with level 0")
  func test_dashboard_emptyState_heatmapReturns112EmptyCells() {
    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let cells = vm.buildHeatmapCells()

    #expect(cells.count == 112)
    #expect(cells.allSatisfy { $0.level == 0 })
    #expect(cells.allSatisfy { $0.count == 0 })
  }

  @Test("Empty state weekly activity returns 7 items all with count 0")
  func test_dashboard_emptyState_weeklyActivityReturns7EmptyDays() {
    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let weekly = vm.buildWeeklyActivity()

    #expect(weekly.count == 7)
    #expect(weekly.allSatisfy { $0.count == 0 })
  }

  @Test("Empty state recent activity returns empty array")
  func test_dashboard_emptyState_recentActivityIsEmpty() {
    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let feed = vm.buildRecentActivity()

    #expect(feed.isEmpty)
  }

  // MARK: - Today Commit Count

  @Test("Today commit count includes only push contributions from today")
  func test_dashboard_todayCommitCount_countsTodayPushesOnly() {
    let vm = DashboardViewModel()
    let now = Date.now

    let contributions = (0..<5).map { i in
      makeContribution(
        id: "push-\(i)",
        type: .push,
        date: now,
        commitCount: 1
      )
    }

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitCount == 5)
  }

  @Test("Today commit count excludes non-push contribution types")
  func test_dashboard_todayCommitCount_excludesNonPushTypes() {
    let vm = DashboardViewModel()
    let now = Date.now

    let contributions = [
      makeContribution(id: "push-1", type: .push, date: now),
      makeContribution(id: "push-2", type: .push, date: now),
      makeContribution(id: "pr-1", type: .pullRequest, date: now),
      makeContribution(id: "issue-1", type: .issue, date: now),
      makeContribution(id: "create-1", type: .create, date: now),
      makeContribution(id: "fork-1", type: .fork, date: now),
      makeContribution(id: "review-1", type: .pullRequestReview, date: now),
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitCount == 2)
  }

  // MARK: - Trend Calculation

  @Test("Trend is up when today has more pushes than yesterday")
  func test_dashboard_todayCommitTrend_upWhenTodayExceedsYesterday() {
    let vm = DashboardViewModel()
    let today = Date.now
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

    var contributions: [Contribution] = []
    // 4 pushes today
    for i in 0..<4 {
      contributions.append(makeContribution(id: "today-\(i)", type: .push, date: today))
    }
    // 2 pushes yesterday
    for i in 0..<2 {
      contributions.append(makeContribution(id: "yesterday-\(i)", type: .push, date: yesterday))
    }

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitTrend == .up)
    #expect(vm.todayCommitTrendValue.hasPrefix("+"))
  }

  @Test("Trend is down when today has fewer pushes than yesterday")
  func test_dashboard_todayCommitTrend_downWhenTodayLessThanYesterday() {
    let vm = DashboardViewModel()
    let today = Date.now
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

    var contributions: [Contribution] = []
    // 1 push today
    contributions.append(makeContribution(id: "today-0", type: .push, date: today))
    // 4 pushes yesterday
    for i in 0..<4 {
      contributions.append(makeContribution(id: "yesterday-\(i)", type: .push, date: yesterday))
    }

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitTrend == .down)
  }

  @Test("Trend handles zero yesterday gracefully with +100% when today has contributions")
  func test_dashboard_todayCommitTrend_handlesZeroYesterday() {
    let vm = DashboardViewModel()
    let today = Date.now

    let contributions = [
      makeContribution(id: "today-0", type: .push, date: today),
      makeContribution(id: "today-1", type: .push, date: today),
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitTrendValue == "+100%")
  }

  @Test("Trend is flat and 0% when both today and yesterday have zero pushes")
  func test_dashboard_todayCommitTrend_flatWhenBothZero() {
    let vm = DashboardViewModel()

    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.todayCommitTrend == .flat)
    #expect(vm.todayCommitTrendValue == "0%")
  }

  // MARK: - Active PR Count

  @Test("Active PR count includes only open PRs")
  func test_dashboard_activePRCount_countsOnlyOpenPRs() {
    let vm = DashboardViewModel()
    let now = Date.now

    let pullRequests = [
      makePullRequest(id: 1, state: .open, createdAt: now),
      makePullRequest(id: 2, state: .open, createdAt: now),
      makePullRequest(id: 3, state: .open, createdAt: now),
      makePullRequest(id: 4, state: .merged, createdAt: now, mergedAt: now),
      makePullRequest(id: 5, state: .merged, createdAt: now, mergedAt: now),
      makePullRequest(id: 6, state: .closed, createdAt: now, closedAt: now),
    ]

    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: pullRequests,
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.activePRCount == 3)
  }

  // MARK: - Streak Passthrough

  @Test("Streak values pass through from UserProfile")
  func test_dashboard_streakPassthrough_readsFromUserProfile() {
    let vm = DashboardViewModel()
    let profile = makeUserProfile(currentStreak: 14, longestStreak: 47)

    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: profile,
      syncMetadata: nil
    )

    #expect(vm.currentStreak == 14)
    #expect(vm.longestStreak == 47)
  }

  // MARK: - Language Count and Top Language

  @Test("Language count and top language computed correctly across repositories")
  func test_dashboard_languageStats_computedCorrectlyAcrossRepos() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let swiftStat1 = LanguageStat(name: "Swift", bytes: 5000, color: "#F05138")
    let pythonStat = LanguageStat(name: "Python", bytes: 2000, color: "#3572A5")
    let repo1 = makeRepository(
      context: context,
      id: 1,
      name: "repo-a",
      fullName: "testuser/repo-a",
      languages: [swiftStat1, pythonStat]
    )

    let swiftStat2 = LanguageStat(name: "Swift", bytes: 3000, color: "#F05138")
    let jsStat = LanguageStat(name: "JavaScript", bytes: 1000, color: "#F1E05A")
    let repo2 = makeRepository(
      context: context,
      id: 2,
      name: "repo-b",
      fullName: "testuser/repo-b",
      languages: [swiftStat2, jsStat]
    )

    try context.save()

    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [repo1, repo2],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    // Swift (8000) + Python (2000) + JavaScript (1000) = 3 unique languages
    #expect(vm.languageCount == 3)

    // Top language is Swift with 8000 / 11000 = ~72.7%
    let top = vm.topLanguage
    #expect(top != nil)
    #expect(top?.name == "Swift")

    let expectedPercentage = (8000.0 / 11000.0) * 100.0
    let actualPercentage = top?.percentage ?? 0
    #expect(abs(actualPercentage - expectedPercentage) < 0.1)
  }

  // MARK: - Heatmap

  @Test("Heatmap cells have correct structure: 112 cells, valid weekIndex and dayOfWeek ranges")
  func test_dashboard_heatmapCells_haveCorrectStructure() {
    let vm = DashboardViewModel()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    // Place a contribution 50 days ago so at least one cell has count > 0
    let fiftyDaysAgo = calendar.date(byAdding: .day, value: -50, to: today)!
    let contributions = [
      makeContribution(id: "hm-1", date: fiftyDaysAgo)
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let cells = vm.buildHeatmapCells()

    #expect(cells.count == 112)

    // All weekIndex values should be in 0...15
    #expect(cells.allSatisfy { $0.weekIndex >= 0 && $0.weekIndex <= 15 })

    // All dayOfWeek values should be in 0...6
    #expect(cells.allSatisfy { $0.dayOfWeek >= 0 && $0.dayOfWeek <= 6 })

    // At least one cell should have count > 0
    let nonZeroCells = cells.filter { $0.count > 0 }
    #expect(nonZeroCells.count >= 1)

    // Non-zero cells should have level > 0
    #expect(nonZeroCells.allSatisfy { $0.level > 0 })
  }

  @Test("Heatmap cells with contributions have appropriate intensity levels")
  func test_dashboard_heatmapCells_assignCorrectIntensityLevels() {
    let vm = DashboardViewModel()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    // Create contributions on today: 15 events should give level 4 (default thresholds: >12)
    var contributions: [Contribution] = []
    for i in 0..<15 {
      contributions.append(
        makeContribution(
          id: "level-\(i)",
          date: today.addingTimeInterval(TimeInterval(i * 60))
        )
      )
    }

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let cells = vm.buildHeatmapCells()
    // Find today's cell
    let todayCell = cells.first { calendar.isDate($0.id, inSameDayAs: today) }

    #expect(todayCell != nil)
    #expect(todayCell?.count == 15)
    // With fewer than 4 non-zero days, default thresholds apply: 13+ = level 4
    #expect(todayCell?.level == 4)
  }

  // MARK: - Weekly Activity

  @Test("Weekly activity returns 7 days with correct counts for contributions")
  func test_dashboard_weeklyActivity_returns7DaysWithCorrectCounts() {
    let vm = DashboardViewModel()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    // Place 3 contributions today and 2 contributions 3 days ago
    let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

    var contributions: [Contribution] = []
    for i in 0..<3 {
      contributions.append(
        makeContribution(
          id: "today-w-\(i)",
          date: today.addingTimeInterval(TimeInterval(i * 60))
        )
      )
    }
    for i in 0..<2 {
      contributions.append(
        makeContribution(
          id: "past-w-\(i)",
          date: threeDaysAgo.addingTimeInterval(TimeInterval(i * 60))
        )
      )
    }

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let weekly = vm.buildWeeklyActivity()

    #expect(weekly.count == 7)

    // The last item (index 6) is today
    #expect(weekly[6].count == 3)

    // 3 days ago is at index 3 (index 6 - 3 = 3)
    #expect(weekly[3].count == 2)

    // Each item should have a non-empty dayName
    #expect(weekly.allSatisfy { !$0.dayName.isEmpty })
  }

  @Test("Weekly activity counts all contribution types, not just pushes")
  func test_dashboard_weeklyActivity_countsAllContributionTypes() {
    let vm = DashboardViewModel()
    let now = Date.now

    let contributions = [
      makeContribution(id: "wa-push", type: .push, date: now),
      makeContribution(id: "wa-pr", type: .pullRequest, date: now),
      makeContribution(id: "wa-issue", type: .issue, date: now),
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let weekly = vm.buildWeeklyActivity()
    // Today should count all 3
    #expect(weekly.last?.count == 3)
  }

  // MARK: - Recent Activity Feed

  @Test("Recent activity feed returns items in reverse chronological order with correct titles")
  func test_dashboard_recentActivity_reverseChronologicalWithCorrectTitles() {
    let vm = DashboardViewModel()
    let now = Date.now

    let contributions = [
      makeContribution(
        id: "feed-push",
        type: .push,
        date: now.addingTimeInterval(-3600),
        commitCount: 3
      ),
      makeContribution(
        id: "feed-pr",
        type: .pullRequest,
        date: now.addingTimeInterval(-1800)
      ),
      makeContribution(
        id: "feed-create",
        type: .create,
        date: now.addingTimeInterval(-600)
      ),
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let feed = vm.buildRecentActivity()

    #expect(feed.count == 3)

    // Most recent first (create at -600, then pr at -1800, then push at -3600)
    #expect(feed[0].contributionType == .create)
    #expect(feed[0].title == "Created repository")

    #expect(feed[1].contributionType == .pullRequest)
    #expect(feed[1].title == "Opened pull request")

    #expect(feed[2].contributionType == .push)
    #expect(feed[2].title == "Pushed 3 commits")
  }

  @Test("Recent activity feed is limited to 5 items")
  func test_dashboard_recentActivity_limitedTo5Items() {
    let vm = DashboardViewModel()
    let now = Date.now

    let contributions = (0..<15).map { i in
      makeContribution(
        id: "bulk-\(i)",
        type: .push,
        date: now.addingTimeInterval(TimeInterval(-i * 60))
      )
    }

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let feed = vm.buildRecentActivity()

    #expect(feed.count == 5)
  }

  @Test("Recent activity push title handles single commit correctly")
  func test_dashboard_recentActivity_singleCommitPushTitle() {
    let vm = DashboardViewModel()

    let contributions = [
      makeContribution(id: "single-push", type: .push, date: .now, commitCount: 1)
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let feed = vm.buildRecentActivity()

    #expect(feed.count == 1)
    #expect(feed[0].title == "Pushed 1 commit")
  }

  // MARK: - Sync Status Text

  @Test("Last synced text is Never when syncMetadata is nil")
  func test_dashboard_lastSyncedText_neverWhenNilMetadata() {
    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.lastSyncedText == "Never")
  }

  @Test("Last synced text shows relative time when syncMetadata exists")
  func test_dashboard_lastSyncedText_showsRelativeTimeWhenMetadataExists() {
    let vm = DashboardViewModel()
    // Sync happened 5 minutes ago
    let fiveMinutesAgo = Date.now.addingTimeInterval(-300)
    let metadata = makeSyncMetadata(date: fiveMinutesAgo)

    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: metadata
    )

    // The text should not be "Never"
    #expect(vm.lastSyncedText != "Never")
  }

  // MARK: - Rate Limit Text

  @Test("Rate limit text shows formatted remaining count out of 5000")
  func test_dashboard_rateLimitText_showsFormattedRemaining() {
    let vm = DashboardViewModel()
    let metadata = makeSyncMetadata(rateLimitRemaining: 4500)

    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: metadata
    )

    #expect(vm.rateLimitText.contains("4500"))
    #expect(vm.rateLimitText.contains("5,000"))
  }

  @Test("Rate limit text is Unknown when syncMetadata is nil")
  func test_dashboard_rateLimitText_unknownWhenNilMetadata() {
    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    #expect(vm.rateLimitText == "Unknown")
  }

  // MARK: - Sparkline

  @Test("Recent commit sparkline returns exactly 7 values")
  func test_dashboard_recentCommitSparkline_returns7Values() {
    let vm = DashboardViewModel()
    let today = Date.now

    let contributions = [
      makeContribution(id: "spark-0", type: .push, date: today)
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let sparkline = vm.recentCommitSparkline

    #expect(sparkline.count == 7)
    // Last value (today) should be 1.0
    #expect(sparkline[6] == 1.0)
    // Other days should be 0.0
    #expect(sparkline[0] == 0.0)
  }

  // MARK: - Total Contributions in Period

  @Test("Total contributions in period counts contributions within the 16-week window")
  func test_dashboard_totalContributionsInPeriod_countsWithinWindow() {
    let vm = DashboardViewModel()
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let withinWindow = calendar.date(byAdding: .day, value: -50, to: today)!
    let outsideWindow = calendar.date(byAdding: .day, value: -120, to: today)!

    let contributions = [
      makeContribution(id: "in-1", date: today),
      makeContribution(id: "in-2", date: withinWindow),
      makeContribution(id: "out-1", date: outsideWindow),
    ]

    vm.update(
      contributions: contributions,
      repositories: [],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    // Only the 2 contributions within the 112-day window should count
    #expect(vm.totalContributionsInPeriod == 2)
  }

  // MARK: - Language Bar Segments

  @Test("Language bar segments are sorted by bytes descending with correct fractions")
  func test_dashboard_languageBarSegments_sortedByBytesDescending() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let swiftStat = LanguageStat(name: "Swift", bytes: 7000, color: "#F05138")
    let pythonStat = LanguageStat(name: "Python", bytes: 3000, color: "#3572A5")
    let repo = makeRepository(
      context: context,
      id: 1,
      name: "repo",
      languages: [swiftStat, pythonStat]
    )

    try context.save()

    let vm = DashboardViewModel()
    vm.update(
      contributions: [],
      repositories: [repo],
      pullRequests: [],
      userProfile: nil,
      syncMetadata: nil
    )

    let segments = vm.languageBarSegments

    #expect(segments.count == 2)
    // First segment is Swift (70%)
    #expect(segments[0].name == "Swift")
    #expect(abs(segments[0].fraction - 0.7) < 0.01)
    // Second segment is Python (30%)
    #expect(segments[1].name == "Python")
    #expect(abs(segments[1].fraction - 0.3) < 0.01)
  }
}
