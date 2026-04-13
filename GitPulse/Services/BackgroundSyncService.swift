//  BackgroundSyncService.swift
//  GitPulse

import Foundation
import SwiftData
import os

#if os(iOS)
  import BackgroundTasks
#endif

// MARK: - SyncError

/// Errors that can occur during the background sync process.
enum SyncError: Error, LocalizedError {
  /// The GitHub API returned an error during sync.
  case apiError(GitHubError)
  /// A SwiftData persistence operation failed.
  case persistenceError(Error)
  /// The sync was cancelled before completion (e.g., system expiration).
  case cancelled

  var errorDescription: String? {
    switch self {
    case .apiError(let gitHubError):
      "Sync failed due to API error: \(gitHubError.localizedDescription)"
    case .persistenceError(let error):
      "Sync failed due to persistence error: \(error.localizedDescription)"
    case .cancelled:
      "Sync was cancelled before completing."
    }
  }
}

// MARK: - BackgroundDataWriter

/// A model actor that performs thread-safe SwiftData writes off the main actor.
///
/// All bulk import and update operations run within this actor's serial executor,
/// ensuring that SwiftData `ModelContext` access is never concurrent.
/// The `@ModelActor` macro synthesizes `init(modelContainer:)`.
@ModelActor
actor BackgroundDataWriter {

  private static let logger = Logger(
    subsystem: "com.gitpulse",
    category: "BackgroundDataWriter"
  )

  // MARK: - Event Type Mapping

  /// Maps a GitHub event type string to the corresponding `ContributionType`.
  ///
  /// - Parameter eventType: The raw event type string from the GitHub Events API.
  /// - Returns: The corresponding `ContributionType`, or `nil` for unrecognized types.
  private func mapContributionType(_ eventType: String) -> Contribution.ContributionType? {
    switch eventType {
    case "PushEvent":
      .push
    case "PullRequestEvent":
      .pullRequest
    case "PullRequestReviewEvent":
      .pullRequestReview
    case "IssuesEvent":
      .issue
    case "CreateEvent":
      .create
    case "ForkEvent":
      .fork
    default:
      nil
    }
  }

  // MARK: - Import Contributions

  /// Imports GitHub events as `Contribution` records into SwiftData.
  ///
  /// Events with unrecognized types are silently skipped. Existing records with
  /// the same `id` are upserted via SwiftData's `@Attribute(.unique)` behavior.
  ///
  /// - Parameter events: The GitHub events to import.
  /// - Returns: The number of events that were imported (excluding skipped types).
  func importContributions(_ events: [GitHubEvent]) throws -> Int {
    var importedCount = 0

    for event in events {
      guard let contributionType = mapContributionType(event.type) else {
        Self.logger.debug("Skipping unrecognized event type: \(event.type)")
        continue
      }

      let repoParts = event.repo.name.split(separator: "/", maxSplits: 1)
      let owner = repoParts.count > 0 ? String(repoParts[0]) : ""
      let name = repoParts.count > 1 ? String(repoParts[1]) : event.repo.name

      var message: String?
      var commitCount = 0
      var additions = 0
      var deletions = 0

      switch contributionType {
      case .push:
        commitCount = event.payload?.commits?.count ?? 0
        message = event.payload?.commits?.first?.message
      case .pullRequest:
        message = event.payload?.pullRequest?.title
        additions = event.payload?.pullRequest?.additions ?? 0
        deletions = event.payload?.pullRequest?.deletions ?? 0
      default:
        break
      }

      let contribution = Contribution(
        id: event.id,
        type: contributionType,
        date: event.createdAt,
        repositoryName: name,
        repositoryOwner: owner,
        message: message,
        additions: additions,
        deletions: deletions,
        commitCount: commitCount
      )

      modelContext.insert(contribution)
      importedCount += 1
    }

    try modelContext.save()
    Self.logger.info("Imported \(importedCount) contributions from \(events.count) events")
    return importedCount
  }

  // MARK: - Import Repositories

  /// Imports GitHub repositories as `Repository` records into SwiftData.
  ///
  /// For existing repositories (matched by unique `id`), updates all fields
  /// in place while preserving the `languages` relationship to avoid
  /// invalidating `LanguageStat` references held by views.
  /// New repositories are inserted with an empty languages array.
  ///
  /// - Parameter repos: The GitHub repositories to import.
  func importRepositories(_ repos: [GitHubRepo]) throws {
    for repo in repos {
      // Look for existing repository to update in place
      let repoId = repo.id
      let predicate = #Predicate<Repository> { $0.id == repoId }
      var descriptor = FetchDescriptor<Repository>(predicate: predicate)
      descriptor.fetchLimit = 1

      if let existing = try modelContext.fetch(descriptor).first {
        // Update fields in place — preserve languages relationship
        existing.name = repo.name
        existing.fullName = repo.fullName
        existing.descriptionText = repo.description
        existing.language = repo.language
        existing.starCount = repo.stargazersCount
        existing.forkCount = repo.forksCount
        existing.isPrivate = repo.isPrivate
        existing.lastPushDate = repo.pushedAt
        existing.createdAt = repo.createdAt
        existing.updatedAt = repo.updatedAt
      } else {
        // New repository — insert fresh
        let repository = Repository(
          id: repo.id,
          name: repo.name,
          fullName: repo.fullName,
          descriptionText: repo.description,
          language: repo.language,
          starCount: repo.stargazersCount,
          forkCount: repo.forksCount,
          isPrivate: repo.isPrivate,
          lastPushDate: repo.pushedAt,
          createdAt: repo.createdAt,
          updatedAt: repo.updatedAt,
          languages: []
        )
        modelContext.insert(repository)
      }
    }

    try modelContext.save()
    Self.logger.info("Imported \(repos.count) repositories")
  }

  // MARK: - Import Pull Requests

  /// Imports GitHub search results as `PullRequest` records into SwiftData.
  ///
  /// The PR state is determined by checking merge status first (`mergedAt != nil`),
  /// then the `state` string. The `repositoryFullName` is extracted from the
  /// `repositoryUrl` field by taking the last two path components.
  ///
  /// - Parameter prs: The GitHub pull request search results to import.
  func importPullRequests(_ prs: [GitHubPR]) throws {
    for pr in prs {
      let state: PullRequest.PRState
      if pr.pullRequest?.mergedAt != nil {
        state = .merged
      } else if pr.state == "closed" {
        state = .closed
      } else {
        state = .open
      }

      // Extract owner/repo from repositoryUrl like "https://api.github.com/repos/owner/name"
      let urlComponents = pr.repositoryUrl.split(separator: "/")
      let repositoryFullName: String
      if urlComponents.count >= 2 {
        let owner = urlComponents[urlComponents.count - 2]
        let name = urlComponents[urlComponents.count - 1]
        repositoryFullName = "\(owner)/\(name)"
      } else {
        repositoryFullName = pr.repositoryUrl
      }

      let pullRequest = PullRequest(
        id: pr.id,
        number: pr.number,
        title: pr.title,
        state: state,
        repositoryFullName: repositoryFullName,
        createdAt: pr.createdAt,
        mergedAt: pr.pullRequest?.mergedAt,
        closedAt: pr.closedAt,
        additions: 0,
        deletions: 0,
        changedFiles: 0,
        isDraft: pr.draft ?? false
      )

      modelContext.insert(pullRequest)
    }

    try modelContext.save()
    Self.logger.info("Imported \(prs.count) pull requests")
  }

  // MARK: - Update User Profile

  /// Creates or updates the `UserProfile` for the given username.
  ///
  /// Profile fields are updated from the GitHub user data, while streak and
  /// contribution statistics come from the `StreakEngine` output.
  ///
  /// - Parameters:
  ///   - username: The GitHub username (unique key).
  ///   - user: The GitHub user profile data.
  ///   - streakInfo: Computed streak statistics from the `StreakEngine`.
  ///   - totalContributions: Total number of contribution events in the store.
  func updateUserProfile(
    username: String,
    from user: GitHubUser,
    streakInfo: StreakInfo,
    totalContributions: Int
  ) throws {
    let profile = UserProfile(
      username: username,
      avatarURL: user.avatarUrl,
      displayName: user.name,
      bio: user.bio,
      publicRepoCount: user.publicRepos,
      followerCount: user.followers,
      currentStreak: streakInfo.current,
      longestStreak: streakInfo.longest,
      activeDays: streakInfo.activeDays,
      totalContributions: totalContributions,
      lastSyncDate: .now
    )

    modelContext.insert(profile)
    try modelContext.save()
    Self.logger.info("Updated user profile for \(username)")
  }

  // MARK: - Update Sync Metadata

  /// Creates or updates the sync metadata record with current sync statistics.
  ///
  /// Uses the key `"lastSync"` as the unique identifier. SwiftData's
  /// `@Attribute(.unique)` on `SyncMetadata.key` handles the upsert.
  ///
  /// - Parameters:
  ///   - eventsProcessed: The number of events processed in this sync cycle.
  ///   - rateLimitRemaining: The remaining API rate limit after sync.
  ///   - rateLimitReset: The date when the rate limit window resets.
  func updateSyncMetadata(
    eventsProcessed: Int,
    rateLimitRemaining: Int,
    rateLimitReset: Date
  ) throws {
    let metadata = SyncMetadata(
      key: "lastSync",
      date: .now,
      eventsProcessed: eventsProcessed,
      rateLimitRemaining: rateLimitRemaining,
      rateLimitReset: rateLimitReset
    )

    modelContext.insert(metadata)
    try modelContext.save()
    Self.logger.info(
      "Updated sync metadata: \(eventsProcessed) events, \(rateLimitRemaining) rate limit remaining"
    )
  }

  // MARK: - Import Language Stats

  /// A static mapping of common GitHub language names to their hex color codes.
  ///
  /// Colors are sourced from GitHub's linguist library. Languages not present
  /// in this mapping default to gray (`"808080"`).
  private static let languageColors: [String: String] = [
    "Swift": "F05138",
    "TypeScript": "3178C6",
    "JavaScript": "F1E05A",
    "Python": "3572A5",
    "Rust": "DEA584",
    "Go": "00ADD8",
    "Ruby": "701516",
    "Java": "B07219",
    "Kotlin": "A97BFF",
    "C": "555555",
    "C++": "F34B7D",
    "C#": "178600",
    "Objective-C": "438EFF",
    "Dart": "00B4AB",
    "PHP": "4F5D95",
    "Shell": "89E051",
    "HTML": "E34C26",
    "CSS": "563D7C",
    "SCSS": "C6538C",
    "Vue": "41B883",
    "Svelte": "FF3E00",
    "Lua": "000080",
    "R": "198CE7",
    "Scala": "C22D40",
    "Elixir": "6E4A7E",
    "Haskell": "5E5086",
    "Zig": "EC915C",
    "Nix": "7E7EFF",
  ]

  /// Imports language statistics for a repository, updating existing entries in place.
  ///
  /// Finds the `Repository` by its GitHub ID, then updates existing `LanguageStat`
  /// records, creates new ones for new languages, and removes stale ones.
  /// Updates in place to avoid invalidating SwiftData references held by views.
  ///
  /// - Parameters:
  ///   - repositoryId: The unique GitHub repository ID.
  ///   - languages: A dictionary mapping language names to byte counts.
  func importLanguageStats(for repositoryId: Int, languages: [String: Int]) throws {
    let predicate = #Predicate<Repository> { $0.id == repositoryId }
    var descriptor = FetchDescriptor<Repository>(predicate: predicate)
    descriptor.fetchLimit = 1
    let results = try modelContext.fetch(descriptor)

    guard let repository = results.first else {
      Self.logger.warning(
        "Repository with id \(repositoryId) not found for language import"
      )
      return
    }

    // Build a lookup of existing stats by language name
    var existingByName: [String: LanguageStat] = [:]
    for stat in repository.languages {
      existingByName[stat.name] = stat
    }

    // Update or create language stats
    var updatedStats: [LanguageStat] = []
    for (name, bytes) in languages {
      let color = Self.languageColors[name] ?? "808080"
      if let existing = existingByName.removeValue(forKey: name) {
        // Update in place
        existing.bytes = bytes
        existing.color = color
        updatedStats.append(existing)
      } else {
        // New language — create
        let stat = LanguageStat(
          name: name,
          bytes: bytes,
          color: color,
          repository: repository
        )
        modelContext.insert(stat)
        updatedStats.append(stat)
      }
    }

    // Remove stale languages no longer present
    for (_, staleStat) in existingByName {
      modelContext.delete(staleStat)
    }

    repository.languages = updatedStats
    try modelContext.save()
    Self.logger.info(
      "Imported \(languages.count) language stats for repository \(repositoryId)"
    )
  }

  // MARK: - Query Helpers

  /// Fetches all contribution dates from the SwiftData store.
  ///
  /// Returns the raw UTC `date` values from all `Contribution` records.
  /// The caller is responsible for timezone conversion (e.g., via `StreakEngine`).
  ///
  /// - Returns: An array of contribution dates in no guaranteed order.
  func fetchAllContributionDates() throws -> [Date] {
    let descriptor = FetchDescriptor<Contribution>()
    let contributions = try modelContext.fetch(descriptor)
    return contributions.map(\.date)
  }

  /// Fetches the date of the most recent successful sync.
  ///
  /// Looks up the `SyncMetadata` record with key `"lastSync"` and returns
  /// its `date` field. Returns `nil` if no sync has been performed yet.
  ///
  /// - Returns: The last sync date, or `nil` if no sync record exists.
  func fetchLastSyncDate() throws -> Date? {
    let predicate = #Predicate<SyncMetadata> { $0.key == "lastSync" }
    var descriptor = FetchDescriptor<SyncMetadata>(predicate: predicate)
    descriptor.fetchLimit = 1
    let results = try modelContext.fetch(descriptor)
    return results.first?.date
  }
}

// MARK: - BackgroundSyncService

/// Coordinates periodic data synchronization between the GitHub API and the local SwiftData store.
///
/// This actor orchestrates the full sync cycle: fetching data from all GitHub API endpoints,
/// persisting it via `BackgroundDataWriter`, recalculating streak statistics, and updating
/// user profile and sync metadata. It also manages `BGAppRefreshTask` registration and scheduling.
///
/// - Important: The GitHub Personal Access Token is never logged or retained beyond the
///   lifetime of the API client.
actor BackgroundSyncService {

  private static let logger = Logger(
    subsystem: "com.gitpulse",
    category: "BackgroundSyncService"
  )

  /// The BGTask identifier registered in Info.plist.
  static let taskIdentifier = "com.gitpulse.refresh"

  /// The interval between background refresh requests (30 minutes).
  private static let refreshInterval: TimeInterval = 1800

  /// The default lookback period for first sync (90 days).
  private static let defaultLookbackDays: TimeInterval = 90 * 24 * 3600

  /// The maximum number of pages to fetch for repository pagination.
  private static let maxRepoPages = 10

  /// The page size used by the GitHub repos endpoint.
  private static let repoPageSize = 30

  /// The API client used for all GitHub requests.
  private let apiClient: GitHubAPIProviding

  /// The data writer for thread-safe SwiftData operations.
  private let dataWriter: BackgroundDataWriter

  /// The streak calculation engine.
  private let streakEngine: StreakEngine

  /// The optional notification service for post-sync alerts.
  private let notificationService: NotificationProviding?

  #if os(macOS)
    /// The background activity scheduler for periodic sync on macOS.
    private var activityScheduler: NSBackgroundActivityScheduler?
  #endif

  /// Creates a new background sync service.
  ///
  /// - Parameters:
  ///   - apiClient: The GitHub API client to use for fetching data.
  ///   - dataWriter: The model actor for persisting data to SwiftData.
  ///   - streakEngine: The streak calculator (defaults to a new instance).
  ///   - notificationService: The notification service for post-sync alerts (defaults to `nil`).
  init(
    apiClient: GitHubAPIProviding,
    dataWriter: BackgroundDataWriter,
    streakEngine: StreakEngine = StreakEngine(),
    notificationService: NotificationProviding? = nil
  ) {
    self.apiClient = apiClient
    self.dataWriter = dataWriter
    self.streakEngine = streakEngine
    self.notificationService = notificationService
  }

  // MARK: - BGTask Management

  #if os(iOS)
    /// Registers the background app refresh task with the system.
    ///
    /// Must be called once during app launch, before the end of
    /// `applicationDidFinishLaunching`. The handler bridges from the
    /// BGTaskScheduler's arbitrary queue to this actor's isolation.
    ///
    /// - Note: `BGAppRefreshTask` is available on iOS only. On macOS, background
    ///   refresh is handled via `NSBackgroundActivityScheduler` or Timer-based polling.
    func registerBackgroundTask() {
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: Self.taskIdentifier,
        using: nil
      ) { task in
        guard let refreshTask = task as? BGAppRefreshTask else {
          Self.logger.error("Received unexpected task type for identifier \(Self.taskIdentifier)")
          task.setTaskCompleted(success: false)
          return
        }
        Task { [weak self] in
          await self?.handleRefresh(task: refreshTask)
        }
      }
      Self.logger.info("Registered background task: \(Self.taskIdentifier)")
    }

    /// Schedules the next background app refresh request.
    ///
    /// The request is submitted with a 30-minute earliest begin date.
    /// Failures are logged but do not propagate, as scheduling is best-effort.
    func scheduleRefresh() {
      let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
      request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)

      do {
        try BGTaskScheduler.shared.submit(request)
        Self.logger.info("Scheduled next background refresh in \(Self.refreshInterval)s")
      } catch {
        Self.logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
      }
    }

    /// Handles a background refresh task dispatched by the system.
    ///
    /// Sets up an expiration handler, performs the sync, reports completion,
    /// and schedules the next refresh.
    ///
    /// - Parameter task: The background refresh task to handle.
    private func handleRefresh(task: BGAppRefreshTask) async {
      let syncTask = Task {
        try await performSync()
      }

      task.expirationHandler = {
        syncTask.cancel()
        Self.logger.warning("Background refresh task expired before completion")
      }

      do {
        try await syncTask.value
        task.setTaskCompleted(success: true)
        Self.logger.info("Background refresh completed successfully")
      } catch {
        task.setTaskCompleted(success: false)
        Self.logger.error("Background refresh failed: \(error.localizedDescription)")
      }

      scheduleRefresh()
    }
  #endif

  #if os(macOS)
    // MARK: - macOS Background Scheduling

    /// Schedules periodic background sync using `NSBackgroundActivityScheduler`.
    ///
    /// The scheduler fires approximately every 30 minutes. Each invocation
    /// performs a full sync cycle. If the system indicates the activity should
    /// be deferred, the scheduler automatically reschedules.
    ///
    /// - Note: On macOS, `NSBackgroundActivityScheduler` replaces the iOS-only
    ///   `BGTaskScheduler`. It uses the same identifier for configuration consistency.
    func scheduleRefresh() {
      let scheduler = NSBackgroundActivityScheduler(
        identifier: Self.taskIdentifier
      )
      scheduler.repeats = true
      scheduler.interval = Self.refreshInterval
      scheduler.qualityOfService = .utility

      scheduler.schedule { [weak self] completion in
        guard let self else {
          completion(.finished)
          return
        }

        Task {
          do {
            try await self.performSync()
            Self.logger.info("Scheduled background sync completed successfully")
            completion(.finished)
          } catch {
            Self.logger.error(
              "Scheduled background sync failed: \(error.localizedDescription)"
            )
            completion(.deferred)
          }
        }
      }

      self.activityScheduler = scheduler
      Self.logger.info(
        "Scheduled background refresh every \(Self.refreshInterval)s via NSBackgroundActivityScheduler"
      )
    }

    /// Invalidates the background activity scheduler, stopping periodic sync.
    func stopScheduledRefresh() {
      activityScheduler?.invalidate()
      activityScheduler = nil
      Self.logger.info("Stopped scheduled background refresh")
    }
  #endif

  // MARK: - Sync Cycle

  /// Performs a full data synchronization cycle.
  ///
  /// The sync cycle executes the following steps in order:
  /// 1. Determine the `since` date from the last sync (or 90 days ago for first sync).
  /// 2. Fetch the authenticated user's profile.
  /// 3. Fetch contribution events since the last sync.
  /// 4. Fetch all repositories (paginated).
  /// 5. Fetch pull requests for all states (open, merged, closed).
  /// 6. Persist all fetched data to SwiftData.
  /// 7. Fetch and import language stats for each repository (skipped if rate limit is low).
  /// 8. Recalculate streak statistics from all contribution dates.
  /// 9. Update the user profile with fresh streak data.
  /// 10. Update sync metadata with completion info.
  /// 11. Evaluate notification alerts.
  ///
  /// - Throws: `SyncError.apiError` for GitHub API failures,
  ///   `SyncError.persistenceError` for SwiftData write failures,
  ///   or `SyncError.cancelled` if the task is cancelled.
  func performSync() async throws {
    Self.logger.info("Starting sync cycle")

    // 1. Determine since date
    let sinceDate: Date
    do {
      let lastSync = try await dataWriter.fetchLastSyncDate()
      sinceDate = lastSync ?? Date.now.addingTimeInterval(-Self.defaultLookbackDays)
    } catch {
      throw SyncError.persistenceError(error)
    }

    Self.logger.debug("Syncing since: \(sinceDate.formatted(.iso8601))")

    // 2. Fetch user profile
    let user: GitHubUser
    do {
      user = try await apiClient.fetchUserProfile()
    } catch {
      throw SyncError.apiError(error)
    }

    // 3. Fetch contribution events
    let events: [GitHubEvent]
    do {
      events = try await apiClient.fetchContributions(since: sinceDate)
    } catch {
      throw SyncError.apiError(error)
    }

    // 4. Fetch all repositories (paginated)
    var allRepos: [GitHubRepo] = []
    do {
      for page in 1...Self.maxRepoPages {
        let repos = try await apiClient.fetchRepositories(page: page)
        allRepos.append(contentsOf: repos)
        if repos.count < Self.repoPageSize {
          break
        }
      }
    } catch {
      throw SyncError.apiError(error)
    }

    // 5. Fetch pull requests for all states
    var allPRs: [GitHubPR] = []
    do {
      for state: PullRequest.PRState in [.open, .merged, .closed] {
        let prs = try await apiClient.fetchPullRequests(state: state, page: 1)
        allPRs.append(contentsOf: prs)
      }
    } catch {
      throw SyncError.apiError(error)
    }

    // 6. Persist data
    let eventsImported: Int
    do {
      eventsImported = try await dataWriter.importContributions(events)
      try await dataWriter.importRepositories(allRepos)
      try await dataWriter.importPullRequests(allPRs)
    } catch {
      throw SyncError.persistenceError(error)
    }

    // 7. Fetch and import language stats for each repository
    let currentRemaining = apiClient.currentRateLimit?.remaining ?? Int.max
    let languageCallsNeeded = allRepos.count
    let shouldFetchLanguages = currentRemaining > languageCallsNeeded
    Self.logger.info(
      "Language fetch: shouldFetch=\(shouldFetchLanguages), rateLimit remaining=\(currentRemaining), repos=\(allRepos.count), callsNeeded=\(languageCallsNeeded)"
    )
    if shouldFetchLanguages {
      for repo in allRepos {
        let components = repo.fullName.split(separator: "/", maxSplits: 1)
        guard components.count == 2 else {
          Self.logger.warning("Skipping repo with invalid fullName: \(repo.fullName)")
          continue
        }
        let owner = String(components[0])
        let repoName = String(components[1])

        do {
          let languages = try await apiClient.fetchLanguages(owner: owner, repo: repoName)
          Self.logger.info(
            "Fetched \(languages.count) languages for \(repo.fullName): \(Array(languages.keys).joined(separator: ", "))"
          )
          try await dataWriter.importLanguageStats(for: repo.id, languages: languages)
        } catch {
          // Non-fatal: continue syncing other repos even if one fails
          Self.logger.warning(
            "Failed to fetch languages for \(repo.fullName): \(error)"
          )
          continue
        }
      }
    } else {
      Self.logger.info(
        "Skipping language fetch — rate limit remaining=\(currentRemaining) below threshold"
      )
    }

    // 8. Recalculate streaks
    let allDates: [Date]
    do {
      allDates = try await dataWriter.fetchAllContributionDates()
    } catch {
      throw SyncError.persistenceError(error)
    }

    let streakInfo = streakEngine.calculate(contributionDates: allDates)

    // 9. Update user profile
    do {
      try await dataWriter.updateUserProfile(
        username: user.login,
        from: user,
        streakInfo: streakInfo,
        totalContributions: allDates.count
      )
    } catch {
      throw SyncError.persistenceError(error)
    }

    // 10. Update sync metadata
    do {
      try await dataWriter.updateSyncMetadata(
        eventsProcessed: eventsImported,
        rateLimitRemaining: apiClient.currentRateLimit?.remaining ?? 0,
        rateLimitReset: apiClient.currentRateLimit?.resetDate ?? .distantFuture
      )
    } catch {
      throw SyncError.persistenceError(error)
    }

    // 11. Evaluate notification alerts (failures do not fail the sync)
    if let notificationService {
      let todayCommits = allDates.filter { Calendar.current.isDateInToday($0) }.count
      let todayPRsMerged = allPRs.filter { $0.pullRequest?.mergedAt != nil }.count
      let todayPRs = allPRs.filter { Calendar.current.isDateInToday($0.createdAt) }.count
      do {
        try await notificationService.evaluateAlerts(
          streakInfo: streakInfo,
          totalCommits: allDates.count,
          totalPRsMerged: todayPRsMerged,
          todayCommits: todayCommits,
          todayPRs: todayPRs
        )
      } catch {
        Self.logger.error("Notification evaluation failed: \(error.localizedDescription)")
      }
    }

    Self.logger.info(
      "Sync cycle completed: \(eventsImported) events, \(allRepos.count) repos, \(allPRs.count) PRs"
    )
  }
}
