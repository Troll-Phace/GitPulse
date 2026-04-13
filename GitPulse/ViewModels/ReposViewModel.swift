//  ReposViewModel.swift
//  GitPulse

import Foundation
import SwiftUI

// MARK: - Domain Types

/// A slice of the language distribution donut chart, representing one programming language's
/// share of the total codebase across all tracked repositories.
struct LanguageSlice: Identifiable, Sendable {

  /// The language name, used as the unique identifier.
  let id: String

  /// The display name of the programming language (e.g., "Swift", "Python").
  let name: String

  /// The total number of bytes written in this language across all repositories.
  let bytes: Int

  /// The percentage of total bytes this language represents (0-100).
  let percentage: Double

  /// The GitHub-assigned color for this language.
  let color: Color
}

/// A repository formatted for display in the repository list.
struct RepoDisplayItem: Identifiable, Sendable {

  /// The unique GitHub repository ID.
  let id: Int

  /// The short repository name (e.g., "GitPulse").
  let name: String

  /// The full `owner/repo` name (e.g., "octocat/GitPulse").
  let fullName: String

  /// An optional description of the repository.
  let descriptionText: String?

  /// The primary programming language, if detected.
  let language: String?

  /// The color associated with the primary language.
  let languageColor: Color

  /// The number of stars (stargazers) on the repository.
  let starCount: Int

  /// The number of forks of the repository.
  let forkCount: Int

  /// Whether the repository is private.
  let isPrivate: Bool

  /// The timestamp of the most recent push to the repository.
  let lastPushDate: Date?

  /// The total number of contribution events matching this repository.
  let commitCount: Int

  /// Seven values representing daily push counts for the last 7 days, oldest first.
  let recentActivitySparkline: [Double]
}

/// Detailed data for a single repository, displayed in the drill-in sheet.
struct RepoDetailData: Identifiable, Sendable {

  /// The unique GitHub repository ID.
  let id: Int

  /// The short repository name.
  let name: String

  /// The full `owner/repo` name.
  let fullName: String

  /// An optional description of the repository.
  let descriptionText: String?

  /// The number of stars on the repository.
  let starCount: Int

  /// The number of forks of the repository.
  let forkCount: Int

  /// The per-repo language breakdown as chart slices.
  let languageBreakdown: [LanguageSlice]

  /// The most recent commits for this repository.
  let recentCommits: [RecentCommitItem]

  /// Daily commit counts for the last 30 days.
  let dailyCommitCounts: [DayCommitCount]
}

/// A single recent commit formatted for display in the repo detail sheet.
struct RecentCommitItem: Identifiable, Sendable {

  /// The GitHub event ID for this commit.
  let id: String

  /// The commit message or PR title.
  let message: String

  /// The first 7 characters of the event ID, mimicking a short git hash.
  let shortHash: String

  /// A human-readable relative time string (e.g., "2h ago").
  let relativeTime: String
}

/// A single day's commit count for the repo detail activity chart.
struct DayCommitCount: Identifiable, Sendable {

  /// The calendar day this count represents (start of day).
  let id: Date

  /// The number of push contributions on this day.
  let count: Int
}

/// The available sort orders for the repository list.
enum RepoSortOrder: String, CaseIterable, Sendable {

  /// Sort by most recently pushed, descending.
  case lastActive = "Last Active"

  /// Sort by star count, descending.
  case stars = "Stars"

  /// Sort alphabetically by name, ascending.
  case name = "Name"

  /// Sort by contribution count, descending.
  case commits = "Commits"
}

// MARK: - ReposViewModel

/// Aggregates SwiftData model data into display-ready formats for the Repos view.
///
/// The view model receives raw model arrays from `@Query` results via its `update` method
/// and exposes computed language breakdowns, filtered/sorted repo lists, and repo detail data.
/// All properties are safe to access with empty data, returning sensible defaults.
@Observable
@MainActor
final class ReposViewModel {

  // MARK: - Input Properties

  /// All tracked repositories from SwiftData, typically from a `@Query`.
  var repositories: [Repository] = []

  /// All contribution events from SwiftData.
  var contributions: [Contribution] = []

  // MARK: - State Properties

  /// The current search text used to filter the repository list.
  var searchText: String = ""

  /// The current sort order for the repository list.
  var sortOrder: RepoSortOrder = .lastActive

  // MARK: - Update

  /// Sets all input properties from view-level `@Query` results.
  ///
  /// Call this from `.task` and `.onChange` modifiers in the Repos view
  /// to keep the view model in sync with SwiftData.
  ///
  /// - Parameters:
  ///   - repositories: The latest repository list.
  ///   - contributions: The latest contribution events.
  func update(repositories: [Repository], contributions: [Contribution]) {
    self.repositories = repositories
    self.contributions = contributions
  }

  // MARK: - Computed Stats

  /// The total number of tracked repositories.
  var repoCount: Int {
    repositories.count
  }

  /// The total bytes of code across all repositories and languages.
  var totalBytes: Int {
    let aggregated = aggregatedLanguageBytes()
    return aggregated.values.reduce(0) { $0 + $1.bytes }
  }

  /// A human-readable formatted string for the total byte count.
  ///
  /// Returns "X.XM" for millions, "XK" for thousands, or the raw number for smaller values.
  var formattedLineCount: String {
    let n = totalBytes
    if n >= 1_000_000 {
      let millions = Double(n) / 1_000_000.0
      return String(format: "%.1fM", millions)
    } else if n >= 1_000 {
      let thousands = n / 1_000
      return "\(thousands)K"
    } else {
      return "\(n)"
    }
  }

  /// The top-level language distribution across all repositories, capped at 5 languages
  /// with remaining languages grouped as "Other".
  ///
  /// Returns an empty array if no language data is available.
  var languageSlices: [LanguageSlice] {
    let aggregated = aggregatedLanguageBytes()
    guard !aggregated.isEmpty else { return [] }

    let total = aggregated.values.reduce(0) { $0 + $1.bytes }
    guard total > 0 else { return [] }

    let sorted = aggregated.sorted { $0.value.bytes > $1.value.bytes }
    let top5 = sorted.prefix(5)
    let rest = sorted.dropFirst(5)

    var slices: [LanguageSlice] = top5.map { entry in
      let percentage = (Double(entry.value.bytes) / Double(total)) * 100.0
      return LanguageSlice(
        id: entry.key,
        name: entry.key,
        bytes: entry.value.bytes,
        percentage: percentage,
        color: Color(hex: entry.value.color)
      )
    }

    if !rest.isEmpty {
      let otherBytes = rest.reduce(0) { $0 + $1.value.bytes }
      let otherPercentage = (Double(otherBytes) / Double(total)) * 100.0
      slices.append(
        LanguageSlice(
          id: "Other",
          name: "Other",
          bytes: otherBytes,
          percentage: otherPercentage,
          color: Color(hex: "808080")
        )
      )
    }

    return slices
  }

  /// The filtered and sorted list of repositories, formatted for display.
  ///
  /// Applies `searchText` filtering (by name, fullName, or language) and
  /// sorts according to the current `sortOrder`.
  var filteredRepos: [RepoDisplayItem] {
    let items = repositories.map { repo in
      buildRepoDisplayItem(for: repo)
    }

    let filtered: [RepoDisplayItem]
    if searchText.isEmpty {
      filtered = items
    } else {
      filtered = items.filter { item in
        item.name.localizedCaseInsensitiveContains(searchText)
          || item.fullName.localizedCaseInsensitiveContains(searchText)
          || (item.language?.localizedCaseInsensitiveContains(searchText) ?? false)
      }
    }

    switch sortOrder {
    case .lastActive:
      return filtered.sorted { lhs, rhs in
        switch (lhs.lastPushDate, rhs.lastPushDate) {
        case (.some(let l), .some(let r)):
          return l > r
        case (.some, .none):
          return true
        case (.none, .some):
          return false
        case (.none, .none):
          return false
        }
      }
    case .stars:
      return filtered.sorted { $0.starCount > $1.starCount }
    case .name:
      return filtered.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
    case .commits:
      return filtered.sorted { $0.commitCount > $1.commitCount }
    }
  }

  // MARK: - Builder Methods

  /// Builds detailed data for a single repository, suitable for the drill-in detail sheet.
  ///
  /// - Parameter repoId: The GitHub repository ID to look up.
  /// - Returns: A `RepoDetailData` instance, or `nil` if the repository is not found.
  func buildRepoDetail(for repoId: Int) -> RepoDetailData? {
    guard let repo = repositories.first(where: { $0.id == repoId }) else { return nil }

    let repoContributions = contributionsForRepo(repo)

    // Per-repo language breakdown (all languages, no "Other" grouping)
    let repoTotal = repo.languages.reduce(0) { $0 + $1.bytes }
    let languageBreakdown: [LanguageSlice] = repo.languages
      .sorted { $0.bytes > $1.bytes }
      .map { stat in
        let percentage = repoTotal > 0 ? (Double(stat.bytes) / Double(repoTotal)) * 100.0 : 0.0
        return LanguageSlice(
          id: stat.name,
          name: stat.name,
          bytes: stat.bytes,
          percentage: percentage,
          color: Color(hex: stat.color)
        )
      }

    // Recent commits (push events, sorted by date desc, top 5)
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated

    let recentCommits: [RecentCommitItem] =
      repoContributions
      .filter { $0.type == .push }
      .sorted { $0.date > $1.date }
      .prefix(5)
      .map { contribution in
        RecentCommitItem(
          id: contribution.id,
          message: contribution.message ?? "No message",
          shortHash: String(contribution.id.prefix(7)),
          relativeTime: formatter.localizedString(for: contribution.date, relativeTo: .now)
        )
      }

    // Daily commit counts for the last 30 days
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let dailyCommitCounts: [DayCommitCount] = (0..<30).reversed().compactMap { daysAgo in
      guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
        return nil
      }
      let count = repoContributions.count { contribution in
        contribution.type == .push && calendar.isDate(contribution.date, inSameDayAs: day)
      }
      return DayCommitCount(id: day, count: count)
    }

    return RepoDetailData(
      id: repo.id,
      name: repo.name,
      fullName: repo.fullName,
      descriptionText: repo.descriptionText,
      starCount: repo.starCount,
      forkCount: repo.forkCount,
      languageBreakdown: languageBreakdown,
      recentCommits: recentCommits,
      dailyCommitCounts: dailyCommitCounts
    )
  }

  // MARK: - Private Helpers

  /// Extracts the owner component from a repository's full name.
  ///
  /// - Parameter repo: The repository to inspect.
  /// - Returns: The owner portion of the `fullName` (before the `/`), or the entire `fullName`
  ///   if no separator is found.
  private func repoOwner(for repo: Repository) -> String {
    let components = repo.fullName.split(separator: "/", maxSplits: 1)
    return components.first.map(String.init) ?? repo.fullName
  }

  /// Filters contributions to only those belonging to the specified repository.
  ///
  /// Matches on both `repositoryName` and `repositoryOwner` to avoid false positives
  /// from identically named repos under different owners.
  ///
  /// - Parameter repo: The repository to filter contributions for.
  /// - Returns: An array of contributions belonging to this repository.
  private func contributionsForRepo(_ repo: Repository) -> [Contribution] {
    let owner = repoOwner(for: repo)
    return contributions.filter { contribution in
      contribution.repositoryName == repo.name && contribution.repositoryOwner == owner
    }
  }

  /// Aggregates language bytes and colors across all tracked repositories.
  ///
  /// For each language, sums byte counts and retains the most recently encountered hex color.
  ///
  /// - Returns: A dictionary mapping language name to a tuple of total bytes and hex color.
  private func aggregatedLanguageBytes() -> [String: (bytes: Int, color: String)] {
    var aggregated: [String: (bytes: Int, color: String)] = [:]
    for repo in repositories {
      for stat in repo.languages {
        let existing = aggregated[stat.name]
        let newBytes = (existing?.bytes ?? 0) + stat.bytes
        aggregated[stat.name] = (bytes: newBytes, color: stat.color)
      }
    }
    return aggregated
  }

  /// Builds a `RepoDisplayItem` for a single repository.
  ///
  /// - Parameter repo: The repository to transform.
  /// - Returns: A display-ready representation of the repository.
  private func buildRepoDisplayItem(for repo: Repository) -> RepoDisplayItem {
    let repoContributions = contributionsForRepo(repo)
    let commitCount = repoContributions.count

    let languageColor: Color
    if let primaryLanguage = repo.language,
      let stat = repo.languages.first(where: { $0.name == primaryLanguage })
    {
      languageColor = Color(hex: stat.color)
    } else {
      languageColor = .gpTextSecondary
    }

    let sparkline = buildSparkline(for: repo)

    return RepoDisplayItem(
      id: repo.id,
      name: repo.name,
      fullName: repo.fullName,
      descriptionText: repo.descriptionText,
      language: repo.language,
      languageColor: languageColor,
      starCount: repo.starCount,
      forkCount: repo.forkCount,
      isPrivate: repo.isPrivate,
      lastPushDate: repo.lastPushDate,
      commitCount: commitCount,
      recentActivitySparkline: sparkline
    )
  }

  /// Builds a 7-value sparkline of daily push contribution counts for a repository.
  ///
  /// - Parameter repo: The repository to generate the sparkline for.
  /// - Returns: An array of exactly 7 `Double` values, oldest first.
  private func buildSparkline(for repo: Repository) -> [Double] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let repoContributions = contributionsForRepo(repo)

    return (0..<7).reversed().map { daysAgo in
      guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
        return 0.0
      }
      let count = repoContributions.count { contribution in
        contribution.type == .push && calendar.isDate(contribution.date, inSameDayAs: day)
      }
      return Double(count)
    }
  }
}
