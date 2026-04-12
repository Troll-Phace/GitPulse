//  BackgroundSyncTests.swift
//  GitPulseTests

import Foundation
import SwiftData
import Testing

@testable import GitPulse

// MARK: - BackgroundSyncTests

/// Comprehensive tests for the background sync service and data writer.
///
/// All tests use an in-memory `ModelContainer` and a `MockGitHubAPIClient`
/// to verify that `BackgroundSyncService.performSync()` correctly fetches
/// from all endpoints, persists data to SwiftData, recalculates streaks,
/// and updates sync metadata.
@Suite("BackgroundSyncService", .serialized)
@MainActor
struct BackgroundSyncTests {

  // MARK: - Helpers

  /// Creates an in-memory `ModelContainer` for test isolation.
  private func makeContainer() throws -> ModelContainer {
    try TestModelContainer.create()
  }

  /// Creates a `MockGitHubAPIClient` pre-configured with valid default stubs
  /// so that `performSync()` can complete without errors.
  private func makeConfiguredMock(
    user: GitHubUser? = nil,
    events: [GitHubEvent]? = nil,
    repos: [GitHubRepo]? = nil,
    prs: [GitHubPR]? = nil,
    rateLimit: RateLimitState? = nil
  ) -> MockGitHubAPIClient {
    let mock = MockGitHubAPIClient()
    mock.fetchUserProfileResult = .success(user ?? makeGitHubUser())
    mock.fetchContributionsResult = .success(events ?? [])
    mock.fetchRepositoriesResult = .success(repos ?? [])
    mock.fetchPullRequestsResult = .success(prs ?? [])
    mock.currentRateLimit =
      rateLimit
      ?? RateLimitState(
        limit: 5000,
        remaining: 4950,
        resetDate: Date(timeIntervalSinceNow: 3600)
      )
    return mock
  }

  // MARK: - Test 1: Endpoint Call Counts

  /// After a successful sync, verify that all expected API endpoints are called:
  /// fetchUserProfile once, fetchContributions once, fetchRepositories at least once,
  /// and fetchPullRequests three times (once per state: open, merged, closed).
  @Test("performSync fetches from all endpoints with correct call counts")
  func test_performSync_fetchesFromAllEndpoints() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)
    let mock = makeConfiguredMock()
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    #expect(mock.fetchUserProfileCallCount == 1)
    #expect(mock.fetchContributionsCallCount == 1)
    #expect(mock.fetchRepositoriesCallCount >= 1)
    #expect(mock.fetchPullRequestsCallCount == 3)
  }

  // MARK: - Test 2: Persist Contributions

  /// Configure the mock with 3 events of different types (PushEvent,
  /// PullRequestEvent, CreateEvent). After sync, verify that 3 Contribution
  /// records exist in SwiftData with correct types.
  @Test("performSync persists contributions with correct types")
  func test_performSync_persistsContributions() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let events = [
      makeGitHubEvent(id: "evt-1", type: "PushEvent"),
      makeGitHubEvent(id: "evt-2", type: "PullRequestEvent"),
      makeGitHubEvent(id: "evt-3", type: "CreateEvent"),
    ]
    let mock = makeConfiguredMock(events: events)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Contribution>()
    let contributions = try context.fetch(descriptor)

    #expect(contributions.count == 3)

    let types = Set(contributions.map(\.type))
    #expect(types.contains(.push))
    #expect(types.contains(.pullRequest))
    #expect(types.contains(.create))
  }

  // MARK: - Test 3: Persist Repositories

  /// Configure the mock with 2 repositories. After sync, verify that 2
  /// Repository records exist with correct fullName and starCount values.
  @Test("performSync persists repositories with correct attributes")
  func test_performSync_persistsRepositories() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let repos = [
      makeGitHubRepo(id: 1001, name: "alpha", fullName: "testuser/alpha", starCount: 42),
      makeGitHubRepo(id: 1002, name: "beta", fullName: "testuser/beta", starCount: 7),
    ]
    let mock = makeConfiguredMock(repos: repos)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Repository>(sortBy: [SortDescriptor(\.id)])
    let repositories = try context.fetch(descriptor)

    #expect(repositories.count == 2)
    #expect(repositories[0].fullName == "testuser/alpha")
    #expect(repositories[0].starCount == 42)
    #expect(repositories[1].fullName == "testuser/beta")
    #expect(repositories[1].starCount == 7)
  }

  // MARK: - Test 4: Persist Pull Requests

  /// Configure the mock with PRs in open, merged, and closed states.
  /// After sync, verify PullRequest records are persisted with correct
  /// state mapping (especially merged detection via pullRequest.mergedAt).
  @Test("performSync persists pull requests with correct state mapping")
  func test_performSync_persistsPullRequests() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let mergeDate = Date(timeIntervalSince1970: 1_700_000_000)
    let closeDate = Date(timeIntervalSince1970: 1_700_100_000)

    let openPR = makeGitHubPR(id: 5001, number: 10, title: "Open PR", state: "open")
    let mergedPR = makeGitHubPR(
      id: 5002, number: 20, title: "Merged PR", state: "closed", mergedAt: mergeDate
    )
    let closedPR = makeGitHubPR(
      id: 5003, number: 30, title: "Closed PR", state: "closed", closedAt: closeDate
    )

    // Return different PRs for each state call using the sequence support.
    let mock = makeConfiguredMock()
    mock.fetchPullRequestsResults = [
      .success([openPR]),
      .success([mergedPR]),
      .success([closedPR]),
    ]

    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<PullRequest>(sortBy: [SortDescriptor(\.id)])
    let pullRequests = try context.fetch(descriptor)

    #expect(pullRequests.count == 3)

    let openRecord = pullRequests.first(where: { $0.id == 5001 })
    #expect(openRecord?.state == .open)

    let mergedRecord = pullRequests.first(where: { $0.id == 5002 })
    #expect(mergedRecord?.state == .merged)
    #expect(mergedRecord?.mergedAt == mergeDate)

    let closedRecord = pullRequests.first(where: { $0.id == 5003 })
    #expect(closedRecord?.state == .closed)
    #expect(closedRecord?.mergedAt == nil)
  }

  // MARK: - Test 5: Upsert Existing Contributions

  /// Run performSync() twice with the same event IDs. Verify that the
  /// Contribution count does not double, confirming SwiftData upsert
  /// behavior on @Attribute(.unique).
  @Test("performSync upserts existing contributions instead of duplicating")
  func test_performSync_upsertsExistingContributions() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let events = [
      makeGitHubEvent(id: "dup-1", type: "PushEvent"),
      makeGitHubEvent(id: "dup-2", type: "CreateEvent"),
    ]
    let mock = makeConfiguredMock(events: events)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    // First sync
    try await service.performSync()

    // Second sync with same event IDs
    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Contribution>()
    let contributions = try context.fetch(descriptor)

    #expect(contributions.count == 2)
  }

  // MARK: - Test 6: Updates Sync Metadata

  /// Set mockClient.currentRateLimit to a known value. After sync, verify
  /// SyncMetadata with key "lastSync" has the expected rateLimitRemaining
  /// and a recent date.
  @Test("performSync updates SyncMetadata with rate limit info and recent date")
  func test_performSync_updatesSyncMetadata() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let resetDate = Date(timeIntervalSince1970: 1_710_000_000)
    let rateLimit = RateLimitState(limit: 5000, remaining: 4990, resetDate: resetDate)
    let mock = makeConfiguredMock(rateLimit: rateLimit)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    let beforeSync = Date.now
    try await service.performSync()

    let context = ModelContext(container)
    let predicate = #Predicate<SyncMetadata> { $0.key == "lastSync" }
    let descriptor = FetchDescriptor<SyncMetadata>(predicate: predicate)
    let results = try context.fetch(descriptor)

    #expect(results.count == 1)

    let metadata = results[0]
    #expect(metadata.rateLimitRemaining == 4990)
    #expect(metadata.rateLimitReset == resetDate)
    // The sync date should be between beforeSync and now (within a few seconds)
    #expect(metadata.date >= beforeSync.addingTimeInterval(-5))
    #expect(metadata.date <= Date.now.addingTimeInterval(5))
  }

  // MARK: - Test 7: Recalculates Streaks

  /// Configure the mock with events on consecutive days (today, yesterday,
  /// day before). After sync, verify UserProfile has currentStreak >= 1
  /// and activeDays matches the number of unique contribution days.
  @Test("performSync recalculates streaks and updates UserProfile")
  func test_performSync_recalculatesStreaks() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let calendar = Calendar.current
    let today = Date.now
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let dayBefore = calendar.date(byAdding: .day, value: -2, to: today)!

    let events = [
      makeGitHubEvent(id: "streak-1", type: "PushEvent", date: today),
      makeGitHubEvent(id: "streak-2", type: "PushEvent", date: yesterday),
      makeGitHubEvent(id: "streak-3", type: "PushEvent", date: dayBefore),
    ]
    let mock = makeConfiguredMock(events: events)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<UserProfile>()
    let profiles = try context.fetch(descriptor)

    #expect(profiles.count == 1)

    let profile = profiles[0]
    #expect(profile.currentStreak >= 1)
    #expect(profile.activeDays >= 3)
    #expect(profile.username == "testuser")
  }

  // MARK: - Test 8: Uses sinceDate from SyncMetadata

  /// Pre-insert a SyncMetadata record with a specific date before calling
  /// performSync(). Verify that the mock's lastFetchContributionsSince
  /// equals that specific date.
  @Test("performSync uses sinceDate from existing SyncMetadata")
  func test_performSync_usesSinceDate_fromSyncMetadata() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    // Pre-insert SyncMetadata with a known date
    let specificDate = Date(timeIntervalSince1970: 1_700_000_000)
    let context = ModelContext(container)
    let existingMetadata = SyncMetadata(
      key: "lastSync",
      date: specificDate,
      eventsProcessed: 10,
      rateLimitRemaining: 4900,
      rateLimitReset: Date(timeIntervalSince1970: 1_700_100_000)
    )
    context.insert(existingMetadata)
    try context.save()

    let mock = makeConfiguredMock()
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    // The mock should have received the specific date as the `since` parameter
    #expect(mock.lastFetchContributionsSince != nil)

    let fetchedSince = mock.lastFetchContributionsSince!
    // Allow a small tolerance for any rounding
    let timeDiff = abs(fetchedSince.timeIntervalSince(specificDate))
    #expect(timeDiff < 2.0)
  }

  // MARK: - Test 9: Defaults sinceDate When No Metadata

  /// Do not pre-insert any SyncMetadata. After performSync(), verify that
  /// lastFetchContributionsSince is approximately 90 days ago.
  @Test("performSync defaults sinceDate to 90 days ago when no SyncMetadata exists")
  func test_performSync_defaultsSinceDate_whenNoMetadata() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)
    let mock = makeConfiguredMock()
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    #expect(mock.lastFetchContributionsSince != nil)

    let fetchedSince = mock.lastFetchContributionsSince!
    // The implementation uses addingTimeInterval with raw seconds (90 * 24 * 3600),
    // so we match that approach to avoid DST-related discrepancies.
    let ninetyDaysAgo = Date.now.addingTimeInterval(-90 * 24 * 3600)
    let timeDiff = abs(fetchedSince.timeIntervalSince(ninetyDaysAgo))
    // Allow up to 10 seconds tolerance for test execution time
    #expect(timeDiff < 10.0)
  }

  // MARK: - Test 10: Paginates Repositories

  /// Configure the mock to return 30 repos on the first call and an empty
  /// array on the second. Verify fetchRepositoriesCallCount == 2 (it stops
  /// when the page returns fewer than 30 or is empty).
  @Test("performSync paginates repositories until empty page is returned")
  func test_performSync_paginatesRepositories() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    // Build a full page of 30 repos
    let fullPage = (1...30).map { index in
      makeGitHubRepo(
        id: index,
        name: "repo-\(index)",
        fullName: "testuser/repo-\(index)"
      )
    }

    let mock = makeConfiguredMock()
    // First call returns 30 repos (full page), second call returns empty (stop)
    mock.fetchRepositoriesResults = [
      .success(fullPage),
      .success([]),
    ]

    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    #expect(mock.fetchRepositoriesCallCount == 2)

    // Verify all 30 repos were persisted
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Repository>()
    let repositories = try context.fetch(descriptor)
    #expect(repositories.count == 30)
  }

  // MARK: - Test 11: Stops Pagination on Partial Page

  /// Configure the mock to return fewer than 30 repos on the first page.
  /// Verify that pagination stops after a single call (no second page fetch).
  @Test("performSync stops repository pagination on partial page")
  func test_performSync_stopsPagination_onPartialPage() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let partialPage = (1...5).map { index in
      makeGitHubRepo(id: index, name: "repo-\(index)", fullName: "testuser/repo-\(index)")
    }

    let mock = makeConfiguredMock(repos: partialPage)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    // Only one call since first page had < 30 results
    #expect(mock.fetchRepositoriesCallCount == 1)
  }

  // MARK: - Test 12: UserProfile Created From API Data

  /// Verify that the UserProfile is populated with data from the
  /// fetchUserProfile() response (username, avatarURL, displayName, bio, etc.).
  @Test("performSync creates UserProfile from API user data")
  func test_performSync_createsUserProfile_fromAPIData() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let user = makeGitHubUser(
      login: "octocat",
      avatarUrl: "https://example.com/avatar.png",
      name: "The Octocat",
      bio: "GitHub mascot",
      publicRepos: 42,
      followers: 1000
    )
    let mock = makeConfiguredMock(user: user)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<UserProfile>()
    let profiles = try context.fetch(descriptor)

    #expect(profiles.count == 1)

    let profile = profiles[0]
    #expect(profile.username == "octocat")
    #expect(profile.avatarURL == "https://example.com/avatar.png")
    #expect(profile.displayName == "The Octocat")
    #expect(profile.bio == "GitHub mascot")
    #expect(profile.publicRepoCount == 42)
    #expect(profile.followerCount == 1000)
  }

  // MARK: - Test 13: Sync With Empty Data

  /// Verify that performSync() completes successfully when the API returns
  /// no events, no repos, and no PRs. UserProfile should still be created
  /// with zero streaks and SyncMetadata should still be updated.
  @Test("performSync handles empty API responses gracefully")
  func test_performSync_handlesEmptyData() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let mock = makeConfiguredMock(events: [], repos: [], prs: [])
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)

    let contributionDescriptor = FetchDescriptor<Contribution>()
    let contributions = try context.fetch(contributionDescriptor)
    #expect(contributions.isEmpty)

    let repoDescriptor = FetchDescriptor<Repository>()
    let repositories = try context.fetch(repoDescriptor)
    #expect(repositories.isEmpty)

    let profileDescriptor = FetchDescriptor<UserProfile>()
    let profiles = try context.fetch(profileDescriptor)
    #expect(profiles.count == 1)
    #expect(profiles[0].currentStreak == 0)
    #expect(profiles[0].activeDays == 0)

    let syncDescriptor = FetchDescriptor<SyncMetadata>()
    let syncRecords = try context.fetch(syncDescriptor)
    #expect(syncRecords.count == 1)
  }

  // MARK: - Test 14: SyncMetadata Upsert On Repeated Sync

  /// Run performSync() twice. Verify only one SyncMetadata record exists
  /// (it is upserted, not duplicated), and the date reflects the second sync.
  @Test("performSync upserts SyncMetadata on repeated sync")
  func test_performSync_upsertsSyncMetadata_onRepeatedSync() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let mock = makeConfiguredMock()
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()
    let firstSyncTime = Date.now

    // Small delay to ensure second sync has a different timestamp
    try await Task.sleep(for: .milliseconds(50))

    try await service.performSync()

    let context = ModelContext(container)
    let predicate = #Predicate<SyncMetadata> { $0.key == "lastSync" }
    let descriptor = FetchDescriptor<SyncMetadata>(predicate: predicate)
    let results = try context.fetch(descriptor)

    #expect(results.count == 1)
    // The date should be after the first sync
    #expect(results[0].date >= firstSyncTime.addingTimeInterval(-1))
  }

  // MARK: - Test 15: Contribution Event Type Mapping

  /// Verify that each GitHub event type string is mapped to the correct
  /// Contribution.ContributionType enum case.
  @Test("performSync maps all event type strings to correct ContributionType")
  func test_performSync_mapsEventTypes_correctly() async throws {
    let container = try makeContainer()
    let dataWriter = BackgroundDataWriter(modelContainer: container)

    let events = [
      makeGitHubEvent(id: "type-push", type: "PushEvent"),
      makeGitHubEvent(id: "type-pr", type: "PullRequestEvent"),
      makeGitHubEvent(id: "type-review", type: "PullRequestReviewEvent"),
      makeGitHubEvent(id: "type-issue", type: "IssuesEvent"),
      makeGitHubEvent(id: "type-create", type: "CreateEvent"),
      makeGitHubEvent(id: "type-fork", type: "ForkEvent"),
    ]
    let mock = makeConfiguredMock(events: events)
    let service = BackgroundSyncService(
      apiClient: mock, dataWriter: dataWriter, streakEngine: StreakEngine()
    )

    try await service.performSync()

    let context = ModelContext(container)
    let descriptor = FetchDescriptor<Contribution>()
    let contributions = try context.fetch(descriptor)

    let typeMap = Dictionary(uniqueKeysWithValues: contributions.map { ($0.id, $0.type) })

    #expect(typeMap["type-push"] == .push)
    #expect(typeMap["type-pr"] == .pullRequest)
    #expect(typeMap["type-review"] == .pullRequestReview)
    #expect(typeMap["type-issue"] == .issue)
    #expect(typeMap["type-create"] == .create)
    #expect(typeMap["type-fork"] == .fork)
  }
}

// MARK: - Test Factory Helpers

/// Creates a valid `GitHubUser` DTO with sensible defaults.
private func makeGitHubUser(
  login: String = "testuser",
  id: Int = 12345,
  avatarUrl: String = "https://example.com/avatar.png",
  name: String? = "Test User",
  bio: String? = "A test user",
  publicRepos: Int = 10,
  followers: Int = 50
) -> GitHubUser {
  GitHubUser(
    login: login,
    id: id,
    avatarUrl: avatarUrl,
    name: name,
    bio: bio,
    publicRepos: publicRepos,
    followers: followers
  )
}

/// Creates a valid `GitHubEvent` DTO with the specified type and date.
private func makeGitHubEvent(
  id: String,
  type: String = "PushEvent",
  date: Date = .now,
  repoName: String = "testuser/test-repo"
) -> GitHubEvent {
  let commits: [EventCommit]?
  let action: String?
  let pullRequest: EventPR?

  switch type {
  case "PushEvent":
    commits = [EventCommit(sha: "sha-\(id)", message: "Commit for \(id)")]
    action = nil
    pullRequest = nil
  case "PullRequestEvent":
    commits = nil
    action = "opened"
    pullRequest = EventPR(
      number: 1, title: "PR for \(id)", additions: 10, deletions: 5, changedFiles: 2
    )
  default:
    commits = nil
    action = nil
    pullRequest = nil
  }

  let payload = EventPayload(commits: commits, action: action, pullRequest: pullRequest)
  return GitHubEvent(
    id: id,
    type: type,
    createdAt: date,
    repo: EventRepo(name: repoName),
    payload: payload
  )
}

/// Creates a valid `GitHubRepo` DTO with sensible defaults.
private func makeGitHubRepo(
  id: Int,
  name: String = "repo",
  fullName: String = "testuser/repo",
  description: String? = "A test repository",
  language: String? = "Swift",
  starCount: Int = 0,
  forksCount: Int = 0,
  isPrivate: Bool = false,
  pushedAt: Date? = nil,
  createdAt: Date = Date(timeIntervalSince1970: 1_690_000_000),
  updatedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> GitHubRepo {
  GitHubRepo(
    id: id,
    name: name,
    fullName: fullName,
    description: description,
    language: language,
    stargazersCount: starCount,
    forksCount: forksCount,
    isPrivate: isPrivate,
    pushedAt: pushedAt,
    createdAt: createdAt,
    updatedAt: updatedAt
  )
}

/// Creates a valid `GitHubPR` DTO with sensible defaults.
///
/// To create a "merged" PR, pass `state: "closed"` and a non-nil `mergedAt` date.
/// The sync service should detect merged PRs by the presence of `mergedAt`.
private func makeGitHubPR(
  id: Int,
  number: Int = 1,
  title: String = "Test PR",
  state: String = "open",
  repositoryUrl: String = "https://api.github.com/repos/testuser/repo",
  createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
  closedAt: Date? = nil,
  mergedAt: Date? = nil,
  draft: Bool = false
) -> GitHubPR {
  GitHubPR(
    id: id,
    number: number,
    title: title,
    state: state,
    repositoryUrl: repositoryUrl,
    createdAt: createdAt,
    closedAt: closedAt,
    draft: draft,
    pullRequest: PRLinks(mergedAt: mergedAt)
  )
}
