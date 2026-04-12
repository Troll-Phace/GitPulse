//  GitHubAPIClientTests.swift
//  GitPulseTests

import Foundation
import Testing

@testable import GitPulse

// MARK: - Fixture Data

/// Static JSON strings matching the structure of the fixture files, used directly
/// in tests to avoid bundle-resource discovery issues with Swift Testing structs.
private enum FixtureData {

  static let userProfile = """
    {
      "login": "octocat",
      "id": 1,
      "avatar_url": "https://avatars.githubusercontent.com/u/1?v=4",
      "name": "The Octocat",
      "bio": "GitHub mascot and code enthusiast",
      "public_repos": 8,
      "followers": 12000
    }
    """.data(using: .utf8)!

  static let events = """
    [
      {
        "id": "40001",
        "type": "PushEvent",
        "created_at": "2024-01-15T10:30:00Z",
        "repo": { "name": "octocat/hello-world" },
        "payload": {
          "commits": [
            { "sha": "abc123def456", "message": "Fix off-by-one error in pagination" },
            { "sha": "789ghi012jkl", "message": "Add unit tests for pagination helper" }
          ]
        }
      },
      {
        "id": "40002",
        "type": "PullRequestEvent",
        "created_at": "2024-01-14T16:45:00Z",
        "repo": { "name": "octocat/spoon-knife" },
        "payload": {
          "action": "opened",
          "pull_request": {
            "number": 42,
            "title": "Add dark mode support",
            "additions": 120,
            "deletions": 30,
            "changed_files": 8
          }
        }
      },
      {
        "id": "40003",
        "type": "CreateEvent",
        "created_at": "2024-01-13T09:00:00Z",
        "repo": { "name": "octocat/new-repo" },
        "payload": {}
      }
    ]
    """.data(using: .utf8)!

  static let repositories = """
    [
      {
        "id": 100001,
        "name": "hello-world",
        "full_name": "octocat/hello-world",
        "description": "A sample repository for testing",
        "language": "Swift",
        "stargazers_count": 42,
        "forks_count": 10,
        "private": false,
        "pushed_at": "2024-01-15T10:30:00Z",
        "created_at": "2023-06-01T12:00:00Z",
        "updated_at": "2024-01-15T10:30:00Z"
      },
      {
        "id": 100002,
        "name": "private-project",
        "full_name": "octocat/private-project",
        "description": null,
        "language": null,
        "stargazers_count": 0,
        "forks_count": 0,
        "private": true,
        "pushed_at": null,
        "created_at": "2024-01-10T08:00:00Z",
        "updated_at": "2024-01-12T14:30:00Z"
      }
    ]
    """.data(using: .utf8)!

  static let pullRequests = """
    {
      "total_count": 2,
      "items": [
        {
          "id": 200001,
          "number": 42,
          "title": "Add dark mode support",
          "state": "open",
          "repository_url": "https://api.github.com/repos/octocat/hello-world",
          "created_at": "2024-01-10T09:00:00Z",
          "closed_at": null,
          "draft": false,
          "pull_request": { "merged_at": null }
        },
        {
          "id": 200002,
          "number": 38,
          "title": "Fix login flow regression",
          "state": "closed",
          "repository_url": "https://api.github.com/repos/octocat/spoon-knife",
          "created_at": "2024-01-05T14:00:00Z",
          "closed_at": "2024-01-08T11:30:00Z",
          "draft": false,
          "pull_request": { "merged_at": "2024-01-08T11:30:00Z" }
        }
      ]
    }
    """.data(using: .utf8)!

  static let malformedJSON = """
    { "not_a_valid_user": true }
    """.data(using: .utf8)!

  static let emptyArray = "[]".data(using: .utf8)!
}

// MARK: - GitHubAPIClientTests

/// Tests for `GitHubAPIClient` covering request authentication, response decoding,
/// HTTP error mapping, rate-limit header parsing, and Link-header pagination.
@Suite("GitHubAPIClient", .serialized)
struct GitHubAPIClientTests {

  // MARK: - Helpers

  /// Creates a `URLSession` configured to intercept all requests via `MockURLProtocol`.
  private func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
  }

  /// Creates a `GitHubAPIClient` backed by the given (or a fresh mock) session.
  private func makeClient(session: URLSession? = nil) -> GitHubAPIClient {
    GitHubAPIClient(
      token: "test-token",
      username: "octocat",
      session: session ?? makeTestSession()
    )
  }

  /// Builds an `HTTPURLResponse` with the specified status code and optional headers.
  private func makeResponse(
    statusCode: Int,
    headers: [String: String]? = nil,
    url: URL? = nil
  ) -> HTTPURLResponse {
    HTTPURLResponse(
      url: url ?? URL(string: "https://api.github.com")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: headers
    )!
  }

  // MARK: - fetchUserProfile — Success

  @Test("fetchUserProfile decodes valid JSON response")
  func test_fetchUserProfile_decodesValidResponse() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.userProfile)
    }

    let user = try await client.fetchUserProfile()

    #expect(user.login == "octocat")
    #expect(user.id == 1)
    #expect(user.avatarUrl == "https://avatars.githubusercontent.com/u/1?v=4")
    #expect(user.name == "The Octocat")
    #expect(user.bio == "GitHub mascot and code enthusiast")
    #expect(user.publicRepos == 8)
    #expect(user.followers == 12000)
  }

  // MARK: - fetchUserProfile — Error Codes

  @Test("fetchUserProfile throws unauthorized for HTTP 401")
  func test_fetchUserProfile_throwsUnauthorized_for401() async {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 401), Data())
    }

    await #expect(throws: GitHubError.unauthorized) {
      try await client.fetchUserProfile()
    }
  }

  @Test("fetchUserProfile throws rateLimited for HTTP 403 with exhausted rate limit")
  func test_fetchUserProfile_throwsRateLimited_for403WithRateLimit() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    let resetEpoch = Date(timeIntervalSince1970: 1_705_400_000)
    MockURLProtocol.requestHandler = { _ in
      let headers = [
        "X-RateLimit-Limit": "5000",
        "X-RateLimit-Remaining": "0",
        "X-RateLimit-Reset": "1705400000",
      ]
      return (self.makeResponse(statusCode: 403, headers: headers), Data())
    }

    await #expect(throws: GitHubError.rateLimited(resetAt: resetEpoch)) {
      try await client.fetchUserProfile()
    }
  }

  @Test("fetchUserProfile throws notFound for HTTP 404")
  func test_fetchUserProfile_throwsNotFound_for404() async {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 404), Data())
    }

    await #expect(throws: GitHubError.notFound) {
      try await client.fetchUserProfile()
    }
  }

  @Test("fetchUserProfile throws serverError for HTTP 500")
  func test_fetchUserProfile_throwsServerError_for500() async {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 500), Data())
    }

    await #expect(throws: GitHubError.serverError(500)) {
      try await client.fetchUserProfile()
    }
  }

  @Test("fetchUserProfile throws decodingFailed for malformed JSON")
  func test_fetchUserProfile_throwsDecodingFailed_forMalformedJSON() async {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.malformedJSON)
    }

    do {
      _ = try await client.fetchUserProfile()
      #expect(Bool(false), "Expected decodingFailed error but call succeeded")
    } catch {
      guard case .decodingFailed = error else {
        #expect(Bool(false), "Expected decodingFailed but got \(error)")
        return
      }
    }
  }

  // MARK: - Rate Limit State

  @Test("Rate limit state is updated from response headers")
  func test_rateLimitState_updatedFromHeaders() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    let resetEpoch: TimeInterval = 1_705_400_000
    MockURLProtocol.requestHandler = { _ in
      let headers = [
        "X-RateLimit-Limit": "5000",
        "X-RateLimit-Remaining": "4987",
        "X-RateLimit-Reset": "\(Int(resetEpoch))",
      ]
      return (self.makeResponse(statusCode: 200, headers: headers), FixtureData.userProfile)
    }

    _ = try await client.fetchUserProfile()

    let rateLimit = client.currentRateLimit
    #expect(rateLimit != nil)
    #expect(rateLimit?.limit == 5000)
    #expect(rateLimit?.remaining == 4987)
    #expect(rateLimit?.resetDate == Date(timeIntervalSince1970: resetEpoch))
  }

  @Test("Rate limit state remains nil when headers are absent")
  func test_rateLimitState_remainsNil_whenHeadersAbsent() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.userProfile)
    }

    _ = try await client.fetchUserProfile()

    #expect(client.currentRateLimit == nil)
  }

  // MARK: - Link Header Pagination

  @Test("parseNextPageURL extracts rel=next URL from Link header")
  func test_parseNextPageURL_extractsNextURL() {
    let nextURL = "https://api.github.com/user/repos?page=2&per_page=30"
    let lastURL = "https://api.github.com/user/repos?page=5&per_page=30"
    let linkHeader = "<\(nextURL)>; rel=\"next\", <\(lastURL)>; rel=\"last\""

    let response = HTTPURLResponse(
      url: URL(string: "https://api.github.com/user/repos")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Link": linkHeader]
    )!

    let parsed = GitHubAPIClient.parseNextPageURL(from: response)
    #expect(parsed == URL(string: nextURL))
  }

  @Test("parseNextPageURL returns nil when only rel=last is present")
  func test_parseNextPageURL_returnsNil_whenNoNextLink() {
    let lastURL = "https://api.github.com/user/repos?page=5&per_page=30"
    let linkHeader = "<\(lastURL)>; rel=\"last\""

    let response = HTTPURLResponse(
      url: URL(string: "https://api.github.com/user/repos")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Link": linkHeader]
    )!

    let parsed = GitHubAPIClient.parseNextPageURL(from: response)
    #expect(parsed == nil)
  }

  @Test("parseNextPageURL returns nil when Link header is absent")
  func test_parseNextPageURL_returnsNil_whenNoLinkHeader() {
    let response = HTTPURLResponse(
      url: URL(string: "https://api.github.com/user/repos")!,
      statusCode: 200,
      httpVersion: nil,
      headerFields: nil
    )!

    let parsed = GitHubAPIClient.parseNextPageURL(from: response)
    #expect(parsed == nil)
  }

  // MARK: - validateToken

  @Test("validateToken returns true for HTTP 200")
  func test_validateToken_returnsTrue_for200() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.userProfile)
    }

    let isValid = try await client.validateToken("ghp_valid_token")
    #expect(isValid == true)
  }

  @Test("validateToken returns false for HTTP 401")
  func test_validateToken_returnsFalse_for401() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 401), Data())
    }

    let isValid = try await client.validateToken("ghp_invalid_token")
    #expect(isValid == false)
  }

  // MARK: - Request Authentication

  @Test("Requests include correct Authorization and Accept headers")
  func test_request_includesCorrectAuthHeaders() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    var capturedRequest: URLRequest?
    MockURLProtocol.requestHandler = { request in
      capturedRequest = request
      return (self.makeResponse(statusCode: 200), FixtureData.userProfile)
    }

    _ = try await client.fetchUserProfile()

    #expect(capturedRequest != nil)
    #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    #expect(
      capturedRequest?.value(forHTTPHeaderField: "Accept") == "application/vnd.github.v3+json")
  }

  // MARK: - fetchRepositories

  @Test("fetchRepositories decodes valid JSON response")
  func test_fetchRepositories_decodesValidResponse() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.repositories)
    }

    let repos = try await client.fetchRepositories(page: 1)

    #expect(repos.count == 2)

    let first = repos[0]
    #expect(first.id == 100001)
    #expect(first.name == "hello-world")
    #expect(first.fullName == "octocat/hello-world")
    #expect(first.description == "A sample repository for testing")
    #expect(first.language == "Swift")
    #expect(first.stargazersCount == 42)
    #expect(first.forksCount == 10)
    #expect(first.isPrivate == false)

    let second = repos[1]
    #expect(second.id == 100002)
    #expect(second.isPrivate == true)
    #expect(second.language == nil)
    #expect(second.pushedAt == nil)
  }

  // MARK: - fetchPullRequests

  @Test("fetchPullRequests decodes search response wrapper")
  func test_fetchPullRequests_decodesSearchResponse() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.pullRequests)
    }

    let prs = try await client.fetchPullRequests(state: .open, page: 1)

    #expect(prs.count == 2)

    let openPR = prs[0]
    #expect(openPR.id == 200001)
    #expect(openPR.number == 42)
    #expect(openPR.title == "Add dark mode support")
    #expect(openPR.state == "open")
    #expect(openPR.pullRequest?.mergedAt == nil)

    let mergedPR = prs[1]
    #expect(mergedPR.id == 200002)
    #expect(mergedPR.state == "closed")
    #expect(mergedPR.pullRequest?.mergedAt != nil)
  }

  // MARK: - fetchContributions

  @Test("fetchContributions decodes events and filters by date")
  func test_fetchContributions_decodesAndFiltersByDate() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      // No Link header -> single page
      (self.makeResponse(statusCode: 200), FixtureData.events)
    }

    // Use a since date that includes the first two events but excludes the third
    let sinceDate = ISO8601DateFormatter().date(from: "2024-01-14T00:00:00Z")!
    let events = try await client.fetchContributions(since: sinceDate)

    // Only events on or after Jan 14 should be returned (ids 40001, 40002)
    #expect(events.count == 2)
    #expect(events[0].id == "40001")
    #expect(events[0].type == "PushEvent")
    #expect(events[0].repo.name == "octocat/hello-world")
    #expect(events[1].id == "40002")
    #expect(events[1].type == "PullRequestEvent")
  }

  @Test("fetchContributions returns empty array for empty response")
  func test_fetchContributions_returnsEmpty_forEmptyResponse() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 200), FixtureData.emptyArray)
    }

    let events = try await client.fetchContributions(since: Date.distantPast)
    #expect(events.isEmpty)
  }

  // MARK: - HTTP 403 without rate limit (unauthorized)

  @Test("HTTP 403 without rate limit headers throws unauthorized")
  func test_fetchUserProfile_throwsUnauthorized_for403WithoutRateLimit() async {
    let session = makeTestSession()
    let client = makeClient(session: session)

    MockURLProtocol.requestHandler = { _ in
      (self.makeResponse(statusCode: 403), Data())
    }

    await #expect(throws: GitHubError.unauthorized) {
      try await client.fetchUserProfile()
    }
  }

  // MARK: - fetchRepositories includes pagination query params

  @Test("fetchRepositories URL contains page and per_page parameters")
  func test_fetchRepositories_includesPaginationParams() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    var capturedURL: URL?
    MockURLProtocol.requestHandler = { request in
      capturedURL = request.url
      return (self.makeResponse(statusCode: 200), FixtureData.repositories)
    }

    _ = try await client.fetchRepositories(page: 3)

    let urlString = capturedURL?.absoluteString ?? ""
    #expect(urlString.contains("page=3"))
    #expect(urlString.contains("per_page=30"))
    #expect(urlString.contains("sort=updated"))
  }

  // MARK: - validateToken uses the provided token, not the client token

  @Test("validateToken sends the provided token, not the client's stored token")
  func test_validateToken_usesProvidedToken() async throws {
    let session = makeTestSession()
    let client = makeClient(session: session)

    var capturedAuthHeader: String?
    MockURLProtocol.requestHandler = { request in
      capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
      return (self.makeResponse(statusCode: 200), FixtureData.userProfile)
    }

    _ = try await client.validateToken("ghp_custom_token_123")

    #expect(capturedAuthHeader == "Bearer ghp_custom_token_123")
  }
}

// MARK: - MockGitHubAPIClientTests

/// Tests verifying that `MockGitHubAPIClient` faithfully reproduces the
/// contract of `GitHubAPIProviding`, so tests using the mock are trustworthy.
@Suite("MockGitHubAPIClient fidelity")
struct MockGitHubAPIClientTests {

  @Test("fetchUserProfile returns stubbed success value")
  func test_mock_fetchUserProfile_returnsStubbed() async throws {
    let mock = MockGitHubAPIClient()
    let user = GitHubUser(
      login: "testuser",
      id: 99,
      avatarUrl: "https://example.com/avatar.png",
      name: "Test User",
      bio: nil,
      publicRepos: 5,
      followers: 100
    )
    mock.fetchUserProfileResult = .success(user)

    let result = try await mock.fetchUserProfile()

    #expect(result.login == "testuser")
    #expect(mock.fetchUserProfileCallCount == 1)
  }

  @Test("fetchUserProfile throws stubbed error")
  func test_mock_fetchUserProfile_throwsStubbedError() async {
    let mock = MockGitHubAPIClient()
    mock.fetchUserProfileResult = .failure(.unauthorized)

    await #expect(throws: GitHubError.unauthorized) {
      try await mock.fetchUserProfile()
    }
    #expect(mock.fetchUserProfileCallCount == 1)
  }

  @Test("validateToken tracks the provided token argument")
  func test_mock_validateToken_tracksArgument() async throws {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)

    _ = try await mock.validateToken("ghp_test_token")

    #expect(mock.validateTokenCallCount == 1)
    #expect(mock.lastValidatedToken == "ghp_test_token")
  }

  @Test("fetchContributions tracks the since argument")
  func test_mock_fetchContributions_tracksSinceArgument() async throws {
    let mock = MockGitHubAPIClient()
    let sinceDate = Date(timeIntervalSince1970: 1_705_000_000)

    _ = try await mock.fetchContributions(since: sinceDate)

    #expect(mock.fetchContributionsCallCount == 1)
    #expect(mock.lastFetchContributionsSince == sinceDate)
  }

  @Test("fetchPullRequests tracks state and page arguments")
  func test_mock_fetchPullRequests_tracksArguments() async throws {
    let mock = MockGitHubAPIClient()

    _ = try await mock.fetchPullRequests(state: .merged, page: 2)

    #expect(mock.fetchPullRequestsCallCount == 1)
    #expect(mock.lastFetchPullRequestsState == .merged)
    #expect(mock.lastFetchPullRequestsPage == 2)
  }
}
