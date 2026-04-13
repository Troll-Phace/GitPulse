//  DashboardViewModel.swift
//  GitPulse

import Foundation
import SwiftUI

// MARK: - Domain Types

/// A single cell in the 16-week contribution heatmap grid.
///
/// Each cell represents one calendar day and carries its contribution count
/// along with pre-computed grid coordinates and intensity level for rendering.
struct HeatmapCell: Identifiable, Sendable {

  /// The calendar day this cell represents (start of day).
  let id: Date

  /// The column index in the heatmap grid (0-15, left to right).
  let weekIndex: Int

  /// The row index in the heatmap grid (0-6, Sunday = 0).
  let dayOfWeek: Int

  /// The number of contributions recorded on this day.
  let count: Int

  /// The intensity bucket (0-4) for color mapping.
  let level: Int
}

/// A single day's contribution activity for the weekly bar chart.
struct DayActivity: Identifiable, Sendable {

  /// The calendar day this activity represents (start of day).
  let id: Date

  /// The abbreviated day name (e.g., "Mon", "Tue").
  let dayName: String

  /// The number of contributions recorded on this day.
  let count: Int
}

/// A recent contribution event formatted for display in the activity feed.
struct ActivityFeedItem: Identifiable, Sendable {

  /// The unique identifier (GitHub event ID).
  let id: String

  /// A human-readable title describing the event (e.g., "Pushed 3 commits").
  let title: String

  /// Supporting detail, typically the repository name or commit message.
  let subtitle: String

  /// A relative time string (e.g., "2m ago", "Yesterday").
  let relativeTime: String

  /// The accent color associated with this event type.
  let eventColor: Color

  /// The raw contribution type for filtering or icon selection.
  let contributionType: Contribution.ContributionType
}

// MARK: - DashboardViewModel

/// Aggregates SwiftData model data into display-ready formats for the Dashboard view.
///
/// The view model receives raw model arrays from `@Query` results via its `update` method
/// and exposes computed statistics, heatmap cells, weekly activity, and a recent activity feed.
/// All properties are safe to access with empty data, returning sensible defaults (0, empty arrays, nil).
@Observable
@MainActor
final class DashboardViewModel {

  // MARK: - Input Properties

  /// All contribution events from SwiftData, typically from a `@Query`.
  var contributions: [Contribution] = []

  /// All tracked repositories from SwiftData.
  var repositories: [Repository] = []

  /// All tracked pull requests from SwiftData.
  var pullRequests: [PullRequest] = []

  /// The authenticated user's profile, if available.
  var userProfile: UserProfile?

  /// The most recent sync metadata record, if available.
  var syncMetadata: SyncMetadata?

  // MARK: - Update

  /// Sets all input properties from view-level `@Query` results.
  ///
  /// Call this from `.onAppear` and `.onChange` modifiers in the Dashboard view
  /// to keep the view model in sync with SwiftData.
  ///
  /// - Parameters:
  ///   - contributions: The latest contribution events.
  ///   - repositories: The latest repository list.
  ///   - pullRequests: The latest pull request list.
  ///   - userProfile: The current user profile, if any.
  ///   - syncMetadata: The most recent sync metadata, if any.
  func update(
    contributions: [Contribution],
    repositories: [Repository],
    pullRequests: [PullRequest],
    userProfile: UserProfile?,
    syncMetadata: SyncMetadata?
  ) {
    self.contributions = contributions
    self.repositories = repositories
    self.pullRequests = pullRequests
    self.userProfile = userProfile
    self.syncMetadata = syncMetadata
  }

  // MARK: - Computed Stats: Commits

  /// The number of push contributions recorded today.
  var todayCommitCount: Int {
    let calendar = Calendar.current
    return contributions.count { contribution in
      contribution.type == .push && calendar.isDateInToday(contribution.date)
    }
  }

  /// The trend direction comparing today's push count to yesterday's push count.
  var todayCommitTrend: TrendDirection {
    let todayCount = todayCommitCount
    let yesterdayCount = yesterdayCommitCount
    if todayCount > yesterdayCount { return .up }
    if todayCount < yesterdayCount { return .down }
    return .flat
  }

  /// A formatted percentage string showing the change from yesterday (e.g., "+33%", "-50%", "0%").
  var todayCommitTrendValue: String {
    let todayCount = todayCommitCount
    let yesterdayCount = yesterdayCommitCount

    guard yesterdayCount > 0 else {
      return todayCount > 0 ? "+100%" : "0%"
    }

    let change = Double(todayCount - yesterdayCount) / Double(yesterdayCount) * 100.0
    let rounded = Int(change.rounded())

    if rounded > 0 {
      return "+\(rounded)%"
    } else if rounded < 0 {
      return "\(rounded)%"
    } else {
      return "0%"
    }
  }

  /// The last 7 days of daily push contribution counts, ordered oldest to newest.
  ///
  /// Returns an array of exactly 7 `Double` values suitable for sparkline rendering.
  var recentCommitSparkline: [Double] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    return (0..<7).reversed().map { daysAgo in
      guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
        return 0.0
      }
      let count = contributions.count { contribution in
        contribution.type == .push && calendar.isDate(contribution.date, inSameDayAs: day)
      }
      return Double(count)
    }
  }

  // MARK: - Computed Stats: Pull Requests

  /// The number of pull requests currently in the `.open` state.
  var activePRCount: Int {
    pullRequests.count { $0.state == .open }
  }

  /// The number of pull requests in review (equivalent to `activePRCount`
  /// since we do not track review state separately).
  var inReviewCount: Int {
    activePRCount
  }

  // MARK: - Computed Stats: Streaks

  /// The user's current consecutive-day contribution streak.
  var currentStreak: Int {
    userProfile?.currentStreak ?? 0
  }

  /// The user's longest-ever consecutive-day contribution streak.
  var longestStreak: Int {
    userProfile?.longestStreak ?? 0
  }

  // MARK: - Computed Stats: Languages

  /// The number of unique programming languages across all tracked repositories.
  var languageCount: Int {
    let allNames = repositories.flatMap { $0.languages.map(\.name) }
    return Set(allNames).count
  }

  /// The top language by total bytes across all repositories, with its percentage of the total.
  ///
  /// Returns `nil` if no language data is available.
  var topLanguage: (name: String, percentage: Double)? {
    let aggregated = aggregatedLanguageBytes()
    guard let top = aggregated.max(by: { $0.value < $1.value }) else { return nil }
    let total = aggregated.values.reduce(0, +)
    guard total > 0 else { return nil }
    let percentage = (Double(top.value) / Double(total)) * 100.0
    return (name: top.key, percentage: percentage)
  }

  /// The language breakdown as proportional bar segments, sorted by bytes descending.
  ///
  /// Each segment contains the language name, its fraction of the total bytes (0.0-1.0),
  /// and the associated color from the `LanguageStat.color` hex field.
  var languageBarSegments: [(name: String, fraction: Double, color: Color)] {
    let aggregated = aggregatedLanguageBytes()
    let total = aggregated.values.reduce(0, +)
    guard total > 0 else { return [] }

    let colorMap = aggregatedLanguageColors()
    return
      aggregated
      .sorted { $0.value > $1.value }
      .map { entry in
        let fraction = Double(entry.value) / Double(total)
        let hexColor = colorMap[entry.key] ?? "#808080"
        return (name: entry.key, fraction: fraction, color: Color(hex: hexColor))
      }
  }

  /// The total number of contributions within the heatmap's 16-week window.
  var totalContributionsInPeriod: Int {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    guard let startDate = calendar.date(byAdding: .day, value: -111, to: today),
      let endDate = calendar.date(byAdding: .day, value: 1, to: today)
    else { return 0 }
    return contributions.count { contribution in
      contribution.date >= startDate && contribution.date < endDate
    }
  }

  // MARK: - Builder Methods

  /// Builds the 112-cell heatmap grid representing 16 weeks of contribution activity.
  ///
  /// Cells are assigned dynamic intensity levels based on percentile thresholds of the user's
  /// actual activity distribution. Falls back to default thresholds (1-3, 4-7, 8-12, 13+) when
  /// fewer than 4 non-zero days exist.
  ///
  /// - Returns: An array of exactly 112 `HeatmapCell` values, one per day.
  func buildHeatmapCells() -> [HeatmapCell] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    guard let startDate = calendar.date(byAdding: .day, value: -111, to: today) else { return [] }

    // Group contributions by local calendar day within the 16-week window
    var countsPerDay: [Date: Int] = [:]

    for contribution in contributions {
      let day = calendar.startOfDay(for: contribution.date)
      if day >= startDate, day <= today {
        countsPerDay[day, default: 0] += 1
      }
    }

    // Calculate dynamic intensity thresholds
    let nonZeroCounts = countsPerDay.values.filter { $0 > 0 }.sorted()
    let thresholds = computeThresholds(from: nonZeroCounts)

    // Build the 112 cells
    var cells: [HeatmapCell] = []
    cells.reserveCapacity(112)

    for dayOffset in 0..<112 {
      guard let cellDate = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else {
        continue
      }

      let weekIndex = dayOffset / 7
      let weekday = calendar.component(.weekday, from: cellDate)
      let dayOfWeek = weekday - 1  // Calendar.weekday is 1-based (Sunday=1), convert to 0-based

      let count = countsPerDay[cellDate] ?? 0
      let level = intensityLevel(for: count, thresholds: thresholds)

      cells.append(
        HeatmapCell(
          id: cellDate,
          weekIndex: weekIndex,
          dayOfWeek: dayOfWeek,
          count: count,
          level: level
        ))
    }

    return cells
  }

  /// Builds the weekly activity breakdown for the last 7 days.
  ///
  /// - Returns: An array of exactly 7 `DayActivity` values, ordered from 6 days ago to today.
  func buildWeeklyActivity() -> [DayActivity] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let dayNameFormatter = DateFormatter()
    dayNameFormatter.dateFormat = "EEE"

    return (0..<7).reversed().map { daysAgo in
      guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
        return DayActivity(id: today, dayName: "???", count: 0)
      }

      let count = contributions.count { contribution in
        calendar.isDate(contribution.date, inSameDayAs: day)
      }

      let dayName = dayNameFormatter.string(from: day)

      return DayActivity(id: day, dayName: dayName, count: count)
    }
  }

  /// Builds the recent activity feed from the most recent contributions.
  ///
  /// - Returns: Up to 10 `ActivityFeedItem` values, sorted by most recent first.
  func buildRecentActivity() -> [ActivityFeedItem] {
    let sorted = contributions.sorted { $0.date > $1.date }
    let recent = sorted.prefix(10)
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated

    return recent.map { contribution in
      let title = activityTitle(for: contribution)
      let subtitle = contribution.message ?? contribution.repositoryName
      let relativeTime = formatter.localizedString(for: contribution.date, relativeTo: .now)
      let eventColor = color(for: contribution.type)

      return ActivityFeedItem(
        id: contribution.id,
        title: title,
        subtitle: subtitle,
        relativeTime: relativeTime,
        eventColor: eventColor,
        contributionType: contribution.type
      )
    }
  }

  // MARK: - Status Properties

  /// A human-readable string showing when the last successful sync occurred.
  ///
  /// Returns "Never" if no sync has been recorded.
  var lastSyncedText: String {
    guard let date = syncMetadata?.date else { return "Never" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: .now)
  }

  /// A summary of the current GitHub API rate limit status.
  ///
  /// Returns "Unknown" if no sync metadata is available.
  var rateLimitText: String {
    guard let metadata = syncMetadata else { return "Unknown" }
    let remaining = metadata.rateLimitRemaining
    return "\(remaining) / 5,000 remaining"
  }

  // MARK: - Private Helpers

  /// The number of push contributions recorded yesterday.
  private var yesterdayCommitCount: Int {
    let calendar = Calendar.current
    return contributions.count { contribution in
      contribution.type == .push && calendar.isDateInYesterday(contribution.date)
    }
  }

  /// Aggregates total bytes per language name across all repositories.
  ///
  /// - Returns: A dictionary mapping language name to total byte count.
  private func aggregatedLanguageBytes() -> [String: Int] {
    var aggregated: [String: Int] = [:]
    for repo in repositories {
      for stat in repo.languages {
        aggregated[stat.name, default: 0] += stat.bytes
      }
    }
    return aggregated
  }

  /// Builds a mapping from language name to the most recently encountered hex color.
  ///
  /// - Returns: A dictionary mapping language name to hex color string.
  private func aggregatedLanguageColors() -> [String: String] {
    var colors: [String: String] = [:]
    for repo in repositories {
      for stat in repo.languages {
        colors[stat.name] = stat.color
      }
    }
    return colors
  }

  /// Computes intensity thresholds from a sorted array of non-zero contribution counts.
  ///
  /// If fewer than 4 non-zero days exist, returns the default GitHub thresholds.
  /// Otherwise, uses the 25th, 50th, and 75th percentile values.
  ///
  /// - Parameter nonZeroCounts: Sorted ascending array of non-zero daily contribution counts.
  /// - Returns: A tuple of three threshold values (p25, p50, p75).
  private func computeThresholds(from nonZeroCounts: [Int]) -> (p25: Int, p50: Int, p75: Int) {
    guard nonZeroCounts.count >= 4 else {
      return (p25: 3, p50: 7, p75: 12)
    }

    let count = nonZeroCounts.count
    let p25 = nonZeroCounts[count / 4]
    let p50 = nonZeroCounts[count / 2]
    let p75 = nonZeroCounts[(count * 3) / 4]

    return (p25: max(p25, 1), p50: max(p50, p25 + 1), p75: max(p75, p50 + 1))
  }

  /// Maps a contribution count to an intensity level (0-4) based on the provided thresholds.
  ///
  /// - Parameters:
  ///   - count: The number of contributions for a day.
  ///   - thresholds: The percentile-based threshold tuple.
  /// - Returns: An integer level from 0 (no contributions) to 4 (very high activity).
  private func intensityLevel(for count: Int, thresholds: (p25: Int, p50: Int, p75: Int)) -> Int {
    switch count {
    case 0:
      return 0
    case 1...thresholds.p25:
      return 1
    case (thresholds.p25 + 1)...thresholds.p50:
      return 2
    case (thresholds.p50 + 1)...thresholds.p75:
      return 3
    default:
      return 4
    }
  }

  /// Generates a human-readable title for a contribution event.
  ///
  /// - Parameter contribution: The contribution to describe.
  /// - Returns: A string like "Pushed 3 commits" or "Opened PR".
  private func activityTitle(for contribution: Contribution) -> String {
    switch contribution.type {
    case .push:
      let count = max(contribution.commitCount, 1)
      return count == 1 ? "Pushed 1 commit" : "Pushed \(count) commits"
    case .pullRequest:
      return "Opened pull request"
    case .pullRequestReview:
      return "Reviewed pull request"
    case .issue:
      return "Opened issue"
    case .create:
      return "Created repository"
    case .fork:
      return "Forked repository"
    }
  }

  /// Returns the accent color associated with a contribution type.
  ///
  /// - Parameter type: The contribution event type.
  /// - Returns: A `Color` from the design system palette.
  private func color(for type: Contribution.ContributionType) -> Color {
    switch type {
    case .push:
      return .gpGreen
    case .pullRequest, .pullRequestReview:
      return .gpBlue
    case .issue:
      return .gpPurple
    case .create, .fork:
      return .gpOrange
    }
  }
}
