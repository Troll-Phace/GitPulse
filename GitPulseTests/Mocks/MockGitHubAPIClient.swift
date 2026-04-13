//  MockGitHubAPIClient.swift
//  GitPulseTests

import Foundation

@testable import GitPulse

/// In-memory mock of `GitHubAPIProviding` for unit tests.
///
/// Each method returns the value stored in its corresponding `Result` stub,
/// or throws the error contained in that `Result`. Call counts are tracked
/// so tests can verify whether (and how many times) a method was invoked.
final class MockGitHubAPIClient: GitHubAPIProviding, @unchecked Sendable {

  // MARK: - Rate Limit

  /// The current rate limit state exposed for protocol conformance.
  var currentRateLimit: RateLimitState? = nil

  // MARK: - Stubs

  /// The result to return from `fetchUserProfile()`.
  var fetchUserProfileResult: Result<GitHubUser, GitHubError> = .failure(.unauthorized)

  /// An ordered sequence of results for `fetchUserProfile()`. When non-empty,
  /// each call removes and returns the first element. Falls back to
  /// `fetchUserProfileResult` when the sequence is exhausted or nil.
  var fetchUserProfileResults: [Result<GitHubUser, GitHubError>]?

  /// The result to return from `fetchContributions(since:)`.
  var fetchContributionsResult: Result<[GitHubEvent], GitHubError> = .success([])

  /// An ordered sequence of results for `fetchContributions(since:)`. When non-empty,
  /// each call removes and returns the first element. Falls back to
  /// `fetchContributionsResult` when the sequence is exhausted or nil.
  var fetchContributionsResults: [Result<[GitHubEvent], GitHubError>]?

  /// The result to return from `fetchRepositories(page:)`.
  var fetchRepositoriesResult: Result<[GitHubRepo], GitHubError> = .success([])

  /// An ordered sequence of results for `fetchRepositories(page:)`. When non-empty,
  /// each call removes and returns the first element. Falls back to
  /// `fetchRepositoriesResult` when the sequence is exhausted or nil.
  var fetchRepositoriesResults: [Result<[GitHubRepo], GitHubError>]?

  /// The result to return from `fetchPullRequests(state:page:)`.
  var fetchPullRequestsResult: Result<[GitHubPR], GitHubError> = .success([])

  /// An ordered sequence of results for `fetchPullRequests(state:page:)`. When non-empty,
  /// each call removes and returns the first element. Falls back to
  /// `fetchPullRequestsResult` when the sequence is exhausted or nil.
  var fetchPullRequestsResults: [Result<[GitHubPR], GitHubError>]?

  /// The result to return from `validateToken(_:)`.
  var validateTokenResult: Result<Bool, GitHubError> = .success(true)

  /// An ordered sequence of results for `validateToken(_:)`. When non-empty,
  /// each call removes and returns the first element. Falls back to
  /// `validateTokenResult` when the sequence is exhausted or nil.
  var validateTokenResults: [Result<Bool, GitHubError>]?

  // MARK: - Call Tracking

  /// The number of times `fetchUserProfile()` has been called.
  private(set) var fetchUserProfileCallCount = 0

  /// The number of times `fetchContributions(since:)` has been called.
  private(set) var fetchContributionsCallCount = 0

  /// The `since` argument passed to the most recent `fetchContributions(since:)` call.
  private(set) var lastFetchContributionsSince: Date?

  /// The number of times `fetchRepositories(page:)` has been called.
  private(set) var fetchRepositoriesCallCount = 0

  /// The `page` argument passed to the most recent `fetchRepositories(page:)` call.
  private(set) var lastFetchRepositoriesPage: Int?

  /// The number of times `fetchPullRequests(state:page:)` has been called.
  private(set) var fetchPullRequestsCallCount = 0

  /// The `state` argument passed to the most recent `fetchPullRequests(state:page:)` call.
  private(set) var lastFetchPullRequestsState: PullRequest.PRState?

  /// The `page` argument passed to the most recent `fetchPullRequests(state:page:)` call.
  private(set) var lastFetchPullRequestsPage: Int?

  /// The number of times `validateToken(_:)` has been called.
  private(set) var validateTokenCallCount = 0

  /// The token passed to the most recent `validateToken(_:)` call.
  private(set) var lastValidatedToken: String?

  /// The result to return from `fetchLanguages(owner:repo:)`.
  var fetchLanguagesResult: Result<[String: Int], GitHubError> = .success([:])

  /// An ordered sequence of results for `fetchLanguages(owner:repo:)`. When non-empty,
  /// each call removes and returns the first element. Falls back to
  /// `fetchLanguagesResult` when the sequence is exhausted or nil.
  var fetchLanguagesResults: [Result<[String: Int], GitHubError>]?

  /// The number of times `fetchLanguages(owner:repo:)` has been called.
  private(set) var fetchLanguagesCallCount = 0

  /// The `owner` argument passed to the most recent `fetchLanguages(owner:repo:)` call.
  private(set) var lastFetchLanguagesOwner: String?

  /// The `repo` argument passed to the most recent `fetchLanguages(owner:repo:)` call.
  private(set) var lastFetchLanguagesRepo: String?

  // MARK: - Helpers

  /// Returns the next result from an optional sequence, removing it from the array.
  /// Falls back to the single-value result when the sequence is nil or exhausted.
  private func nextResult<T>(
    from sequence: inout [Result<T, GitHubError>]?,
    fallback: Result<T, GitHubError>
  ) -> Result<T, GitHubError> {
    if var results = sequence, !results.isEmpty {
      let next = results.removeFirst()
      sequence = results
      return next
    }
    return fallback
  }

  // MARK: - GitHubAPIProviding

  func fetchUserProfile() async throws(GitHubError) -> GitHubUser {
    fetchUserProfileCallCount += 1
    return try nextResult(from: &fetchUserProfileResults, fallback: fetchUserProfileResult).get()
  }

  func fetchContributions(since: Date) async throws(GitHubError) -> [GitHubEvent] {
    fetchContributionsCallCount += 1
    lastFetchContributionsSince = since
    return try nextResult(from: &fetchContributionsResults, fallback: fetchContributionsResult)
      .get()
  }

  func fetchRepositories(page: Int) async throws(GitHubError) -> [GitHubRepo] {
    fetchRepositoriesCallCount += 1
    lastFetchRepositoriesPage = page
    return try nextResult(from: &fetchRepositoriesResults, fallback: fetchRepositoriesResult).get()
  }

  func fetchPullRequests(state: PullRequest.PRState, page: Int) async throws(GitHubError)
    -> [GitHubPR]
  {
    fetchPullRequestsCallCount += 1
    lastFetchPullRequestsState = state
    lastFetchPullRequestsPage = page
    return try nextResult(
      from: &fetchPullRequestsResults, fallback: fetchPullRequestsResult
    ).get()
  }

  func validateToken(_ token: String) async throws(GitHubError) -> Bool {
    validateTokenCallCount += 1
    lastValidatedToken = token
    return try nextResult(from: &validateTokenResults, fallback: validateTokenResult).get()
  }

  func fetchLanguages(owner: String, repo: String) async throws(GitHubError) -> [String: Int] {
    fetchLanguagesCallCount += 1
    lastFetchLanguagesOwner = owner
    lastFetchLanguagesRepo = repo
    return try nextResult(from: &fetchLanguagesResults, fallback: fetchLanguagesResult).get()
  }
}
