//  ReposViewModelTests.swift
//  GitPulseTests

import Foundation
import SwiftData
import Testing

@testable import GitPulse

// MARK: - ReposViewModelTests

/// Comprehensive tests for the repos view model's language aggregation,
/// search filtering, sort ordering, sparkline generation, and detail building.
///
/// Tests that involve `Repository`/`LanguageStat` relationships use an in-memory
/// `ModelContainer` so the `@Relationship` property works correctly.
@Suite("ReposViewModel")
@MainActor
struct ReposViewModelTests {

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
    descriptionText: String? = nil,
    language: String? = "Swift",
    starCount: Int = 0,
    forkCount: Int = 0,
    isPrivate: Bool = false,
    lastPushDate: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    languages: [LanguageStat] = []
  ) -> Repository {
    let repo = Repository(
      id: id,
      name: name,
      fullName: fullName,
      descriptionText: descriptionText,
      language: language,
      starCount: starCount,
      forkCount: forkCount,
      isPrivate: isPrivate,
      lastPushDate: lastPushDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
      languages: languages
    )
    context.insert(repo)
    return repo
  }

  /// Returns a `Date` representing the start of today.
  private var startOfToday: Date {
    Calendar.current.startOfDay(for: .now)
  }

  // MARK: - Empty State

  @Test("Empty state repo count is zero")
  func test_repos_emptyState_repoCountIsZero() {
    let vm = ReposViewModel()
    vm.update(repositories: [], contributions: [])

    #expect(vm.repoCount == 0)
  }

  @Test("Empty state language slices is empty")
  func test_repos_emptyState_languageSlicesIsEmpty() {
    let vm = ReposViewModel()
    vm.update(repositories: [], contributions: [])

    #expect(vm.languageSlices.isEmpty)
  }

  @Test("Empty state filtered repos is empty")
  func test_repos_emptyState_filteredReposIsEmpty() {
    let vm = ReposViewModel()
    vm.update(repositories: [], contributions: [])

    #expect(vm.filteredRepos.isEmpty)
  }

  @Test("Empty state formatted line count is zero")
  func test_repos_emptyState_formattedLineCountIsZero() {
    let vm = ReposViewModel()
    vm.update(repositories: [], contributions: [])

    #expect(vm.totalBytes == 0)
    #expect(vm.formattedLineCount == "0")
  }

  // MARK: - Language Aggregation

  @Test("Language slices aggregate bytes across multiple repos for the same language")
  func test_repos_languageSlices_aggregatesAcrossRepos() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let swift1 = LanguageStat(name: "Swift", bytes: 5000, color: "#F05138")
    let repo1 = makeRepository(
      context: context,
      id: 1,
      name: "repo-a",
      fullName: "testuser/repo-a",
      languages: [swift1]
    )

    let swift2 = LanguageStat(name: "Swift", bytes: 3000, color: "#F05138")
    let repo2 = makeRepository(
      context: context,
      id: 2,
      name: "repo-b",
      fullName: "testuser/repo-b",
      languages: [swift2]
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2], contributions: [])

    let slices = vm.languageSlices

    #expect(slices.count == 1)
    #expect(slices[0].name == "Swift")
    #expect(slices[0].bytes == 8000)
    #expect(abs(slices[0].percentage - 100.0) < 0.1)
  }

  @Test("Language slices sorted by bytes descending")
  func test_repos_languageSlices_sortedByBytesDescending() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let python = LanguageStat(name: "Python", bytes: 2000, color: "#3572A5")
    let swift = LanguageStat(name: "Swift", bytes: 8000, color: "#F05138")
    let js = LanguageStat(name: "JavaScript", bytes: 5000, color: "#F1E05A")

    let repo = makeRepository(
      context: context,
      id: 1,
      name: "multi-lang",
      fullName: "testuser/multi-lang",
      languages: [python, swift, js]
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let slices = vm.languageSlices

    #expect(slices.count == 3)
    #expect(slices[0].name == "Swift")
    #expect(slices[1].name == "JavaScript")
    #expect(slices[2].name == "Python")
  }

  @Test("Language slices groups extras as Other when more than 5 languages")
  func test_repos_languageSlices_topFivePlusOther() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let languages = [
      LanguageStat(name: "Swift", bytes: 7000, color: "#F05138"),
      LanguageStat(name: "Python", bytes: 6000, color: "#3572A5"),
      LanguageStat(name: "JavaScript", bytes: 5000, color: "#F1E05A"),
      LanguageStat(name: "TypeScript", bytes: 4000, color: "#2B7489"),
      LanguageStat(name: "Go", bytes: 3000, color: "#00ADD8"),
      LanguageStat(name: "Rust", bytes: 2000, color: "#DEA584"),
      LanguageStat(name: "C", bytes: 1000, color: "#555555"),
    ]

    let repo = makeRepository(
      context: context,
      id: 1,
      name: "polyglot",
      fullName: "testuser/polyglot",
      languages: languages
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let slices = vm.languageSlices

    // 5 named + 1 "Other"
    #expect(slices.count == 6)

    let otherSlice = slices.last
    #expect(otherSlice?.name == "Other")
    // "Other" should combine Rust (2000) + C (1000) = 3000
    #expect(otherSlice?.bytes == 3000)
  }

  @Test("Language slices percentages sum to approximately 100")
  func test_repos_languageSlices_percentagesSumTo100() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let swift = LanguageStat(name: "Swift", bytes: 5000, color: "#F05138")
    let python = LanguageStat(name: "Python", bytes: 3000, color: "#3572A5")
    let js = LanguageStat(name: "JavaScript", bytes: 2000, color: "#F1E05A")

    let repo = makeRepository(
      context: context,
      id: 1,
      name: "mixed",
      fullName: "testuser/mixed",
      languages: [swift, python, js]
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let totalPercentage = vm.languageSlices.reduce(0.0) { $0 + $1.percentage }

    #expect(abs(totalPercentage - 100.0) < 0.01)
  }

  @Test("Language slices are empty when repos have no LanguageStat entries")
  func test_repos_languageSlices_reposWithNoLanguages() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context,
      id: 1,
      name: "no-lang",
      fullName: "testuser/no-lang",
      language: nil,
      languages: []
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    #expect(vm.languageSlices.isEmpty)
  }

  // MARK: - Formatted Line Count

  @Test("Formatted line count shows millions format for 1,500,000 bytes")
  func test_repos_formattedLineCount_millions() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let stat = LanguageStat(name: "Swift", bytes: 1_500_000, color: "#F05138")
    let repo = makeRepository(
      context: context,
      id: 1,
      name: "big-repo",
      fullName: "testuser/big-repo",
      languages: [stat]
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    #expect(vm.formattedLineCount == "1.5M")
  }

  @Test("Formatted line count shows thousands format for 42,000 bytes")
  func test_repos_formattedLineCount_thousands() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let stat = LanguageStat(name: "Swift", bytes: 42_000, color: "#F05138")
    let repo = makeRepository(
      context: context,
      id: 1,
      name: "medium-repo",
      fullName: "testuser/medium-repo",
      languages: [stat]
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    #expect(vm.formattedLineCount == "42K")
  }

  @Test("Formatted line count shows raw number for 500 bytes")
  func test_repos_formattedLineCount_small() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let stat = LanguageStat(name: "Swift", bytes: 500, color: "#F05138")
    let repo = makeRepository(
      context: context,
      id: 1,
      name: "tiny-repo",
      fullName: "testuser/tiny-repo",
      languages: [stat]
    )

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    #expect(vm.formattedLineCount == "500")
  }

  // MARK: - Search Filtering

  @Test("Search with empty query returns all repositories")
  func test_repos_search_emptyQueryReturnsAll() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "GitPulse", fullName: "testuser/GitPulse")
    let repo2 = makeRepository(
      context: context, id: 2, name: "MyApp", fullName: "testuser/MyApp")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2], contributions: [])
    vm.searchText = ""

    #expect(vm.filteredRepos.count == 2)
  }

  @Test("Search filters by repository name")
  func test_repos_search_filtersByName() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "GitPulse", fullName: "testuser/GitPulse")
    let repo2 = makeRepository(
      context: context, id: 2, name: "MyApp", fullName: "testuser/MyApp")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2], contributions: [])
    vm.searchText = "git"

    let results = vm.filteredRepos
    #expect(results.count == 1)
    #expect(results[0].name == "GitPulse")
  }

  @Test("Search filters by language")
  func test_repos_search_filtersByLanguage() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "SwiftApp", fullName: "testuser/SwiftApp",
      language: "Swift")
    let repo2 = makeRepository(
      context: context, id: 2, name: "PyTool", fullName: "testuser/PyTool",
      language: "Python")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2], contributions: [])
    vm.searchText = "swift"

    let results = vm.filteredRepos
    #expect(results.count == 1)
    #expect(results[0].name == "SwiftApp")
  }

  @Test("Search is case insensitive")
  func test_repos_search_caseInsensitive() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "GitPulse", fullName: "testuser/GitPulse")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])
    vm.searchText = "PULSE"

    let results = vm.filteredRepos
    #expect(results.count == 1)
    #expect(results[0].name == "GitPulse")
  }

  // MARK: - Sort Orders

  @Test("Sort by last active puts most recent push first, nil dates last")
  func test_repos_sort_lastActive() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let now = Date.now
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

    let repo1 = makeRepository(
      context: context, id: 1, name: "Old", fullName: "testuser/Old",
      lastPushDate: yesterday)
    let repo2 = makeRepository(
      context: context, id: 2, name: "Recent", fullName: "testuser/Recent",
      lastPushDate: now)
    let repo3 = makeRepository(
      context: context, id: 3, name: "NoPush", fullName: "testuser/NoPush",
      lastPushDate: nil)

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2, repo3], contributions: [])
    vm.sortOrder = .lastActive

    let results = vm.filteredRepos
    #expect(results[0].name == "Recent")
    #expect(results[1].name == "Old")
    #expect(results[2].name == "NoPush")
  }

  @Test("Sort by stars puts highest star count first")
  func test_repos_sort_stars() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "LowStars", fullName: "testuser/LowStars",
      starCount: 5)
    let repo2 = makeRepository(
      context: context, id: 2, name: "HighStars", fullName: "testuser/HighStars",
      starCount: 100)
    let repo3 = makeRepository(
      context: context, id: 3, name: "MidStars", fullName: "testuser/MidStars",
      starCount: 42)

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2, repo3], contributions: [])
    vm.sortOrder = .stars

    let results = vm.filteredRepos
    #expect(results[0].name == "HighStars")
    #expect(results[1].name == "MidStars")
    #expect(results[2].name == "LowStars")
  }

  @Test("Sort by name orders alphabetically, case insensitive")
  func test_repos_sort_name() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "Zeta", fullName: "testuser/Zeta")
    let repo2 = makeRepository(
      context: context, id: 2, name: "alpha", fullName: "testuser/alpha")
    let repo3 = makeRepository(
      context: context, id: 3, name: "Bravo", fullName: "testuser/Bravo")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2, repo3], contributions: [])
    vm.sortOrder = .name

    let results = vm.filteredRepos
    #expect(results[0].name == "alpha")
    #expect(results[1].name == "Bravo")
    #expect(results[2].name == "Zeta")
  }

  @Test("Sort by commits puts highest commit count first")
  func test_repos_sort_commits() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "FewCommits", fullName: "testuser/FewCommits")
    let repo2 = makeRepository(
      context: context, id: 2, name: "ManyCommits", fullName: "testuser/ManyCommits")

    try context.save()

    // 1 contribution for FewCommits, 5 for ManyCommits
    let contributions =
      [
        makeContribution(
          id: "fc-1", repositoryName: "FewCommits", repositoryOwner: "testuser")
      ]
      + (0..<5).map { i in
        makeContribution(
          id: "mc-\(i)", repositoryName: "ManyCommits", repositoryOwner: "testuser")
      }

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2], contributions: contributions)
    vm.sortOrder = .commits

    let results = vm.filteredRepos
    #expect(results[0].name == "ManyCommits")
    #expect(results[0].commitCount == 5)
    #expect(results[1].name == "FewCommits")
    #expect(results[1].commitCount == 1)
  }

  // MARK: - Commit Count Per Repo

  @Test("Commit count matches contributions by name and owner")
  func test_repos_commitCount_matchesByNameAndOwner() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "alice/MyRepo")

    try context.save()

    let contributions = [
      makeContribution(id: "c-1", repositoryName: "MyRepo", repositoryOwner: "alice"),
      makeContribution(id: "c-2", repositoryName: "MyRepo", repositoryOwner: "alice"),
      makeContribution(id: "c-3", repositoryName: "MyRepo", repositoryOwner: "alice"),
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let results = vm.filteredRepos
    #expect(results[0].commitCount == 3)
  }

  @Test("Commit count excludes contributions with different owner")
  func test_repos_commitCount_excludesDifferentOwner() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "alice/MyRepo")

    try context.save()

    let contributions = [
      makeContribution(id: "c-1", repositoryName: "MyRepo", repositoryOwner: "alice"),
      makeContribution(id: "c-2", repositoryName: "MyRepo", repositoryOwner: "bob"),
      makeContribution(id: "c-3", repositoryName: "MyRepo", repositoryOwner: "charlie"),
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let results = vm.filteredRepos
    // Only the alice-owned contribution should count
    #expect(results[0].commitCount == 1)
  }

  @Test("Commit count includes all contribution types not just push")
  func test_repos_commitCount_includesAllTypes() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let contributions = [
      makeContribution(
        id: "c-push", type: .push, repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "c-pr", type: .pullRequest, repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "c-issue", type: .issue, repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "c-review", type: .pullRequestReview, repositoryName: "MyRepo",
        repositoryOwner: "testuser"),
      makeContribution(
        id: "c-create", type: .create, repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "c-fork", type: .fork, repositoryName: "MyRepo", repositoryOwner: "testuser"),
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let results = vm.filteredRepos
    #expect(results[0].commitCount == 6)
  }

  // MARK: - Sparkline

  @Test("Sparkline always has exactly 7 elements")
  func test_repos_sparkline_sevenValues() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let results = vm.filteredRepos
    #expect(results[0].recentActivitySparkline.count == 7)
  }

  @Test("Sparkline counts push contributions on known dates in correct positions")
  func test_repos_sparkline_countsPushContributions() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

    let contributions = [
      // 2 pushes today
      makeContribution(
        id: "s-1", type: .push, date: today.addingTimeInterval(3600),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "s-2", type: .push, date: today.addingTimeInterval(7200),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
      // 1 push two days ago
      makeContribution(
        id: "s-3", type: .push, date: twoDaysAgo.addingTimeInterval(3600),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
      // 1 non-push today (should NOT appear in sparkline)
      makeContribution(
        id: "s-4", type: .pullRequest, date: today.addingTimeInterval(1800),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let sparkline = vm.filteredRepos[0].recentActivitySparkline
    #expect(sparkline.count == 7)
    // Index 6 = today (oldest first): 2 pushes
    #expect(sparkline[6] == 2.0)
    // Index 4 = two days ago: 1 push
    #expect(sparkline[4] == 1.0)
    // Index 0 = six days ago: 0 pushes
    #expect(sparkline[0] == 0.0)
  }

  // MARK: - Detail Builder

  @Test("Build detail returns nil for unknown repository ID")
  func test_repos_buildDetail_returnsNilForUnknownId() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(context: context, id: 42, name: "Known", fullName: "testuser/Known")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let detail = vm.buildRepoDetail(for: 9999)
    #expect(detail == nil)
  }

  @Test("Build detail returns correct name, stars, and forks")
  func test_repos_buildDetail_correctValues() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "GitPulse", fullName: "alice/GitPulse",
      descriptionText: "A GitHub tracker", starCount: 42, forkCount: 7)

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let detail = vm.buildRepoDetail(for: 1)

    #expect(detail != nil)
    #expect(detail?.name == "GitPulse")
    #expect(detail?.fullName == "alice/GitPulse")
    #expect(detail?.descriptionText == "A GitHub tracker")
    #expect(detail?.starCount == 42)
    #expect(detail?.forkCount == 7)
  }

  @Test("Build detail language breakdown includes all languages without Other grouping")
  func test_repos_buildDetail_languageBreakdown() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let languages = [
      LanguageStat(name: "Swift", bytes: 5000, color: "#F05138"),
      LanguageStat(name: "Python", bytes: 3000, color: "#3572A5"),
      LanguageStat(name: "JavaScript", bytes: 2000, color: "#F1E05A"),
      LanguageStat(name: "TypeScript", bytes: 1500, color: "#2B7489"),
      LanguageStat(name: "Go", bytes: 1000, color: "#00ADD8"),
      LanguageStat(name: "Rust", bytes: 500, color: "#DEA584"),
      LanguageStat(name: "C", bytes: 200, color: "#555555"),
    ]

    let repo = makeRepository(
      context: context, id: 1, name: "polyglot", fullName: "testuser/polyglot",
      languages: languages)

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let detail = vm.buildRepoDetail(for: 1)

    // All 7 languages should appear (no "Other" grouping in per-repo breakdown)
    #expect(detail?.languageBreakdown.count == 7)

    // Sorted by bytes descending
    #expect(detail?.languageBreakdown[0].name == "Swift")
    #expect(detail?.languageBreakdown[6].name == "C")

    // No entry named "Other"
    let hasOther = detail?.languageBreakdown.contains { $0.name == "Other" } ?? false
    #expect(!hasOther)
  }

  @Test("Build detail recent commits limited to 5 push contributions sorted by date desc")
  func test_repos_buildDetail_recentCommits_maxFive() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "ActiveRepo", fullName: "testuser/ActiveRepo")

    try context.save()

    let now = Date.now
    // Create 8 push contributions
    let contributions = (0..<8).map { i in
      makeContribution(
        id: "push-\(i)",
        type: .push,
        date: now.addingTimeInterval(TimeInterval(-i * 3600)),
        repositoryName: "ActiveRepo",
        repositoryOwner: "testuser",
        message: "Commit \(i)"
      )
    }

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let detail = vm.buildRepoDetail(for: 1)

    // Only 5 recent commits despite 8 push contributions
    #expect(detail?.recentCommits.count == 5)

    // First commit should be the most recent (push-0)
    #expect(detail?.recentCommits[0].message == "Commit 0")
    // Last commit should be the 5th most recent (push-4)
    #expect(detail?.recentCommits[4].message == "Commit 4")
  }

  @Test("Build detail recent commits excludes non-push contributions")
  func test_repos_buildDetail_recentCommits_excludesNonPush() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MixedRepo", fullName: "testuser/MixedRepo")

    try context.save()

    let now = Date.now
    let contributions = [
      makeContribution(
        id: "push-1", type: .push, date: now,
        repositoryName: "MixedRepo", repositoryOwner: "testuser", message: "Push commit"),
      makeContribution(
        id: "pr-1", type: .pullRequest, date: now.addingTimeInterval(-100),
        repositoryName: "MixedRepo", repositoryOwner: "testuser", message: "PR title"),
      makeContribution(
        id: "issue-1", type: .issue, date: now.addingTimeInterval(-200),
        repositoryName: "MixedRepo", repositoryOwner: "testuser", message: "Issue title"),
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let detail = vm.buildRepoDetail(for: 1)

    #expect(detail?.recentCommits.count == 1)
    #expect(detail?.recentCommits[0].message == "Push commit")
  }

  // MARK: - Daily Commit Counts

  @Test("Daily commit counts has exactly 30 entries")
  func test_repos_dailyCommitCounts_thirtyDays() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])

    let detail = vm.buildRepoDetail(for: 1)

    #expect(detail?.dailyCommitCounts.count == 30)
  }

  @Test("Daily commit counts reflect push contributions on known dates")
  func test_repos_dailyCommitCounts_correctCounts() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)

    let contributions = [
      // 3 pushes today
      makeContribution(
        id: "d-1", type: .push, date: today.addingTimeInterval(3600),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "d-2", type: .push, date: today.addingTimeInterval(7200),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
      makeContribution(
        id: "d-3", type: .push, date: today.addingTimeInterval(10800),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
      // 1 PR today (should NOT count in daily commit counts since it's push-only)
      makeContribution(
        id: "d-4", type: .pullRequest, date: today.addingTimeInterval(1800),
        repositoryName: "MyRepo", repositoryOwner: "testuser"),
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let detail = vm.buildRepoDetail(for: 1)
    let counts = detail?.dailyCommitCounts ?? []

    // Today is the last entry in the array
    let todayEntry = counts.last
    #expect(todayEntry?.count == 3)

    // Yesterday (second to last) should be 0
    let yesterdayEntry = counts.dropLast().last
    #expect(yesterdayEntry?.count == 0)
  }

  // MARK: - Repo Count

  @Test("Repo count reflects the number of repositories")
  func test_repos_repoCount_reflectsRepositoryCount() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(context: context, id: 1, name: "A", fullName: "testuser/A")
    let repo2 = makeRepository(context: context, id: 2, name: "B", fullName: "testuser/B")
    let repo3 = makeRepository(context: context, id: 3, name: "C", fullName: "testuser/C")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2, repo3], contributions: [])

    #expect(vm.repoCount == 3)
  }

  // MARK: - Search Combined with Sort

  @Test("Search and sort interact correctly: filter narrows then sort orders")
  func test_repos_searchAndSort_interactCorrectly() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo1 = makeRepository(
      context: context, id: 1, name: "swift-utils", fullName: "testuser/swift-utils",
      language: "Swift", starCount: 10)
    let repo2 = makeRepository(
      context: context, id: 2, name: "swift-cli", fullName: "testuser/swift-cli",
      language: "Swift", starCount: 50)
    let repo3 = makeRepository(
      context: context, id: 3, name: "python-api", fullName: "testuser/python-api",
      language: "Python", starCount: 100)

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2, repo3], contributions: [])
    vm.searchText = "swift"
    vm.sortOrder = .stars

    let results = vm.filteredRepos

    // Only the 2 swift repos should pass the filter
    #expect(results.count == 2)
    // Sorted by stars descending: swift-cli (50) before swift-utils (10)
    #expect(results[0].name == "swift-cli")
    #expect(results[1].name == "swift-utils")
  }

  // MARK: - Total Bytes

  @Test("Total bytes sums across all repos and languages")
  func test_repos_totalBytes_sumsAcrossAllRepos() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let swift1 = LanguageStat(name: "Swift", bytes: 3000, color: "#F05138")
    let repo1 = makeRepository(
      context: context, id: 1, name: "A", fullName: "testuser/A", languages: [swift1])

    let swift2 = LanguageStat(name: "Swift", bytes: 2000, color: "#F05138")
    let python = LanguageStat(name: "Python", bytes: 5000, color: "#3572A5")
    let repo2 = makeRepository(
      context: context, id: 2, name: "B", fullName: "testuser/B", languages: [swift2, python])

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo1, repo2], contributions: [])

    // Swift: 3000 + 2000 = 5000, Python: 5000, Total: 10000
    #expect(vm.totalBytes == 10_000)
  }

  // MARK: - Edge Cases

  @Test("Search by fullName matches on the owner/repo format")
  func test_repos_search_matchesByFullName() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "special-org/MyRepo")

    try context.save()

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: [])
    vm.searchText = "special-org"

    let results = vm.filteredRepos
    #expect(results.count == 1)
    #expect(results[0].fullName == "special-org/MyRepo")
  }

  @Test("Build detail short hash is first 7 characters of the event ID")
  func test_repos_buildDetail_shortHashFormat() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let contributions = [
      makeContribution(
        id: "abcdefghij1234567890",
        type: .push,
        date: .now,
        repositoryName: "MyRepo",
        repositoryOwner: "testuser",
        message: "Test commit"
      )
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let detail = vm.buildRepoDetail(for: 1)
    #expect(detail?.recentCommits[0].shortHash == "abcdefg")
  }

  @Test("Build detail uses 'No message' for contributions without a message")
  func test_repos_buildDetail_noMessageFallback() throws {
    let container = try TestModelContainer.create()
    let context = container.mainContext

    let repo = makeRepository(
      context: context, id: 1, name: "MyRepo", fullName: "testuser/MyRepo")

    try context.save()

    let contributions = [
      makeContribution(
        id: "no-msg-1",
        type: .push,
        date: .now,
        repositoryName: "MyRepo",
        repositoryOwner: "testuser",
        message: nil
      )
    ]

    let vm = ReposViewModel()
    vm.update(repositories: [repo], contributions: contributions)

    let detail = vm.buildRepoDetail(for: 1)
    #expect(detail?.recentCommits[0].message == "No message")
  }
}
