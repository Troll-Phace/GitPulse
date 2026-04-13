//  GitHubAPIClient.swift
//  GitPulse

import Foundation
import SwiftData
import os

// MARK: - GitHubError

/// Errors that can occur during GitHub API operations.
nonisolated enum GitHubError: Error, LocalizedError, Equatable {
  /// The provided token is invalid or has been revoked (HTTP 401).
  case unauthorized
  /// The API rate limit has been exceeded (HTTP 403 with X-RateLimit-Remaining: 0).
  case rateLimited(resetAt: Date)
  /// The requested resource was not found (HTTP 404).
  case notFound
  /// The network is unavailable and the request could not be sent.
  case networkUnavailable
  /// The server returned an unexpected error status code (5xx).
  case serverError(Int)
  /// The response body could not be decoded from JSON.
  case decodingFailed(underlying: Error)
  /// An unexpected error occurred.
  case unknown(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .unauthorized:
      "GitHub token is invalid or has been revoked."
    case .rateLimited(let resetAt):
      "GitHub API rate limit exceeded. Resets at \(resetAt.formatted())."
    case .notFound:
      "The requested GitHub resource was not found."
    case .networkUnavailable:
      "Network is unavailable. Please check your internet connection."
    case .serverError(let code):
      "GitHub server error (HTTP \(code))."
    case .decodingFailed(let underlying):
      "Failed to decode GitHub API response: \(underlying.localizedDescription)"
    case .unknown(let underlying):
      "An unexpected error occurred: \(underlying.localizedDescription)"
    }
  }

  static func == (lhs: GitHubError, rhs: GitHubError) -> Bool {
    switch (lhs, rhs) {
    case (.unauthorized, .unauthorized):
      true
    case (.rateLimited(let lDate), .rateLimited(let rDate)):
      lDate == rDate
    case (.notFound, .notFound):
      true
    case (.networkUnavailable, .networkUnavailable):
      true
    case (.serverError(let lCode), .serverError(let rCode)):
      lCode == rCode
    case (.decodingFailed(let lErr), .decodingFailed(let rErr)):
      lErr.localizedDescription == rErr.localizedDescription
    case (.unknown(let lErr), .unknown(let rErr)):
      lErr.localizedDescription == rErr.localizedDescription
    default:
      false
    }
  }
}

// MARK: - RateLimitState

/// Tracks the current GitHub API rate limit status parsed from response headers.
nonisolated struct RateLimitState: Sendable, Equatable {
  /// The maximum number of requests allowed per hour (typically 5,000 for authenticated users).
  let limit: Int
  /// The number of requests remaining in the current rate limit window.
  let remaining: Int
  /// The date when the current rate limit window resets.
  let resetDate: Date
}

// MARK: - GitHub API DTOs

/// A GitHub user profile returned from the `/user` endpoint.
nonisolated struct GitHubUser: Codable, Sendable {
  /// The user's login username.
  let login: String
  /// The unique GitHub user ID.
  let id: Int
  /// The URL of the user's avatar image.
  let avatarUrl: String
  /// The user's display name, if set.
  let name: String?
  /// The user's bio, if set.
  let bio: String?
  /// The number of public repositories owned by the user.
  let publicRepos: Int
  /// The number of followers the user has.
  let followers: Int
}

/// A single event from the GitHub Events API (`/users/{user}/events`).
nonisolated struct GitHubEvent: Codable, Sendable {
  /// The unique event ID.
  let id: String
  /// The event type string (e.g., "PushEvent", "PullRequestEvent").
  let type: String
  /// The UTC timestamp when the event was created.
  let createdAt: Date
  /// The repository where the event occurred.
  let repo: EventRepo
  /// The event-specific payload, if available.
  let payload: EventPayload?
}

/// The repository reference within a GitHub event.
nonisolated struct EventRepo: Codable, Sendable {
  /// The full repository name in `owner/name` format.
  let name: String
}

/// The payload of a GitHub event, containing action-specific data.
nonisolated struct EventPayload: Codable, Sendable {
  /// The commits included in a push event.
  let commits: [EventCommit]?
  /// The number of commits in a push event (present even when `commits` is omitted).
  let size: Int?
  /// The HEAD commit SHA of a push event.
  let head: String?
  /// The ref that was pushed to (e.g., "refs/heads/main").
  let ref: String?
  /// The action performed (e.g., "opened", "closed", "merged").
  let action: String?
  /// The pull request associated with this event.
  let pullRequest: EventPR?
}

/// A single commit reference within a push event payload.
nonisolated struct EventCommit: Codable, Sendable {
  /// The commit SHA hash.
  let sha: String
  /// The commit message.
  let message: String
}

/// A pull request reference within an event payload.
nonisolated struct EventPR: Codable, Sendable {
  /// The pull request number within its repository.
  let number: Int?
  /// The pull request title.
  let title: String?
  /// The number of lines added, if available.
  let additions: Int?
  /// The number of lines deleted, if available.
  let deletions: Int?
  /// The number of files changed, if available.
  let changedFiles: Int?
}

/// A GitHub repository returned from the `/user/repos` endpoint.
nonisolated struct GitHubRepo: Codable, Sendable {
  /// The unique GitHub repository ID.
  let id: Int
  /// The short repository name.
  let name: String
  /// The full repository name in `owner/repo` format.
  let fullName: String
  /// The repository description, if set.
  let description: String?
  /// The primary programming language, if detected.
  let language: String?
  /// The number of stars on the repository.
  let stargazersCount: Int
  /// The number of forks.
  let forksCount: Int
  /// Whether the repository is private.
  let isPrivate: Bool
  /// The UTC timestamp of the most recent push.
  let pushedAt: Date?
  /// The UTC timestamp when the repository was created.
  let createdAt: Date
  /// The UTC timestamp when the repository was last updated.
  let updatedAt: Date

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case fullName
    case description
    case language
    case stargazersCount
    case forksCount
    case isPrivate = "private"
    case pushedAt
    case createdAt
    case updatedAt
  }
}

/// A pull request item returned from the GitHub Search API (`/search/issues`).
nonisolated struct GitHubPR: Codable, Sendable {
  /// The unique GitHub issue/PR ID.
  let id: Int
  /// The pull request number within its repository.
  let number: Int
  /// The pull request title.
  let title: String
  /// The state string (e.g., "open", "closed").
  let state: String
  /// The repository API URL (used to extract the full repo name).
  let repositoryUrl: String
  /// The UTC timestamp when the pull request was created.
  let createdAt: Date
  /// The UTC timestamp when the pull request was closed, if applicable.
  let closedAt: Date?
  /// Whether the pull request is a draft.
  let draft: Bool?
  /// Nested pull request links containing merge information.
  let pullRequest: PRLinks?
}

/// Nested pull request link data within a search result item.
nonisolated struct PRLinks: Codable, Sendable {
  /// The UTC timestamp when the pull request was merged, if applicable.
  let mergedAt: Date?
}

/// A generic wrapper for GitHub Search API responses.
nonisolated struct SearchResponse<T: Decodable & Sendable>: Codable, Sendable where T: Encodable {
  /// The total number of results matching the search query.
  let totalCount: Int
  /// The items returned on this page.
  let items: [T]
}

// MARK: - GitHubAPIProviding

/// A protocol defining the interface for GitHub API operations.
///
/// All methods use typed throws with `GitHubError` for precise error handling.
/// Implementations must be `Sendable` to support concurrent usage across actors.
nonisolated protocol GitHubAPIProviding: Sendable {
  /// Fetches the authenticated user's profile.
  ///
  /// - Returns: The user profile data.
  func fetchUserProfile() async throws(GitHubError) -> GitHubUser

  /// Fetches contribution events since the specified date.
  ///
  /// Paginates through the events API, stopping when events older than `since`
  /// are encountered or the maximum page limit is reached.
  /// - Parameter since: The earliest date for which to return events.
  /// - Returns: An array of events created on or after `since`.
  func fetchContributions(since: Date) async throws(GitHubError) -> [GitHubEvent]

  /// Fetches the authenticated user's repositories for a given page.
  ///
  /// - Parameter page: The 1-based page number to fetch.
  /// - Returns: An array of repositories for the requested page.
  func fetchRepositories(page: Int) async throws(GitHubError) -> [GitHubRepo]

  /// Fetches pull requests authored by the user with the specified state.
  ///
  /// Uses the GitHub Search API to find pull requests across all repositories.
  /// - Parameters:
  ///   - state: The PR state to filter by (open, merged, or closed).
  ///   - page: The 1-based page number to fetch.
  /// - Returns: An array of pull requests matching the criteria.
  func fetchPullRequests(state: PullRequest.PRState, page: Int) async throws(GitHubError)
    -> [GitHubPR]

  /// Validates whether a GitHub Personal Access Token is valid.
  ///
  /// Makes a test request to `/user` using the provided token.
  /// - Parameter token: The PAT to validate.
  /// - Returns: `true` if the token is valid (HTTP 200), `false` if unauthorized (HTTP 401).
  func validateToken(_ token: String) async throws(GitHubError) -> Bool

  /// Fetches the language breakdown for a specific repository.
  ///
  /// Calls the GitHub Languages API (`/repos/{owner}/{repo}/languages`) which
  /// returns a dictionary mapping language names to byte counts. No pagination
  /// is needed for this endpoint.
  ///
  /// - Parameters:
  ///   - owner: The repository owner (user or organization).
  ///   - repo: The repository name.
  /// - Returns: A dictionary mapping language names to byte counts.
  func fetchLanguages(owner: String, repo: String) async throws(GitHubError) -> [String: Int]

  /// The current rate limit state, if available from a previous API response.
  var currentRateLimit: RateLimitState? { get }
}

// MARK: - GitHubAPIClient

/// A concrete GitHub API client that communicates with the GitHub REST API v3.
///
/// Uses `URLSession` with async/await for all network requests. Tracks API rate limits
/// via response headers and supports pagination through `Link` header parsing.
///
/// - Important: The client requires a valid GitHub Personal Access Token for authentication.
///   Tokens are never logged or printed.
nonisolated final class GitHubAPIClient: GitHubAPIProviding, @unchecked Sendable {
  /// The default GitHub API base URL.
  private static let defaultBaseURL: URL = {
    guard let url = URL(string: "https://api.github.com") else {
      fatalError(
        "Invalid GitHub API base URL — this is a compile-time constant and should never fail.")
    }
    return url
  }()

  /// The shared JSON decoder configured for GitHub API responses.
  private static let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let string = try container.decode(String.self)
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      if let date = formatter.date(from: string) { return date }
      formatter.formatOptions = [.withInternetDateTime]
      if let date = formatter.date(from: string) { return date }
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Invalid ISO 8601 date: \(string)")
    }
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  /// The URL session used for all network requests.
  private let session: URLSession

  /// The base URL for all API requests.
  private let baseURL: URL

  /// The GitHub Personal Access Token used for authentication.
  private let token: String

  /// The authenticated user's GitHub username.
  private let username: String

  /// The maximum number of pages to fetch during pagination.
  private let maxPaginationPages: Int

  /// Thread-safe storage for the current rate limit state.
  private let rateLimitLock: OSAllocatedUnfairLock<RateLimitState?>

  /// The current rate limit state, if available from a previous API response.
  var currentRateLimit: RateLimitState? {
    rateLimitLock.withLock { $0 }
  }

  /// Creates a new GitHub API client.
  ///
  /// - Parameters:
  ///   - token: The GitHub Personal Access Token for authentication.
  ///   - username: The authenticated user's GitHub username.
  ///   - session: The URL session to use (defaults to `.shared`).
  ///   - baseURL: The API base URL (defaults to `https://api.github.com`).
  ///   - maxPaginationPages: Maximum pages to fetch during pagination (defaults to 10).
  init(
    token: String,
    username: String,
    session: URLSession = .shared,
    baseURL: URL = GitHubAPIClient.defaultBaseURL,
    maxPaginationPages: Int = 10
  ) {
    self.token = token
    self.username = username
    self.session = session
    self.baseURL = baseURL
    self.maxPaginationPages = maxPaginationPages
    self.rateLimitLock = OSAllocatedUnfairLock(initialState: nil)
  }

  // MARK: - Private Helpers

  /// Performs an authenticated HTTP request and returns the response data.
  ///
  /// Adds authorization and accept headers, parses rate limit headers from the response,
  /// and maps HTTP status codes to typed `GitHubError` values.
  ///
  /// - Parameter request: The URL request to perform.
  /// - Returns: A tuple of the response data and HTTP response.
  private func performRequest(_ request: URLRequest) async throws(GitHubError) -> (
    Data, HTTPURLResponse
  ) {
    var authenticatedRequest = request
    authenticatedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    authenticatedRequest.setValue(
      "application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: authenticatedRequest)
    } catch let urlError as URLError
      where [
        .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost,
        .cannotConnectToHost,
      ].contains(urlError.code)
    {
      throw .networkUnavailable
    } catch {
      throw .unknown(underlying: error)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response."]))
    }

    updateRateLimitState(from: httpResponse)

    let statusCode = httpResponse.statusCode

    switch statusCode {
    case 200...299:
      return (data, httpResponse)
    case 401:
      throw .unauthorized
    case 403:
      let currentState = rateLimitLock.withLock { $0 }
      if let state = currentState, state.remaining == 0 {
        throw .rateLimited(resetAt: state.resetDate)
      }
      throw .unauthorized
    case 404:
      throw .notFound
    case 500...599:
      throw .serverError(statusCode)
    default:
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: statusCode,
          userInfo: [NSLocalizedDescriptionKey: "Unexpected HTTP status code: \(statusCode)."]))
    }
  }

  /// Parses rate limit headers from an HTTP response and updates the stored state.
  ///
  /// - Parameter response: The HTTP response containing rate limit headers.
  private func updateRateLimitState(from response: HTTPURLResponse) {
    guard
      let limitString = response.value(forHTTPHeaderField: "X-RateLimit-Limit"),
      let limit = Int(limitString),
      let remainingString = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
      let remaining = Int(remainingString),
      let resetString = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
      let resetEpoch = TimeInterval(resetString)
    else {
      return
    }

    let state = RateLimitState(
      limit: limit,
      remaining: remaining,
      resetDate: Date(timeIntervalSince1970: resetEpoch)
    )

    rateLimitLock.withLock { $0 = state }
  }

  /// Parses the `Link` header from an HTTP response to find the next page URL.
  ///
  /// The `Link` header format is: `<URL>; rel="next", <URL>; rel="last"`
  ///
  /// - Parameter response: The HTTP response to parse.
  /// - Returns: The URL for the next page, or `nil` if there is no next page.
  static func parseNextPageURL(from response: HTTPURLResponse) -> URL? {
    guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
      return nil
    }

    let parts = linkHeader.components(separatedBy: ",").map {
      $0.trimmingCharacters(in: .whitespaces)
    }

    for part in parts {
      guard part.contains("rel=\"next\"") else {
        continue
      }

      guard let openBracket = part.firstIndex(of: "<"),
        let closeBracket = part.firstIndex(of: ">")
      else {
        continue
      }

      let urlString = String(part[part.index(after: openBracket)..<closeBracket])
      return URL(string: urlString)
    }

    return nil
  }

  /// Decodes a JSON response body into the specified type using the shared decoder.
  ///
  /// - Parameters:
  ///   - type: The type to decode into.
  ///   - data: The raw JSON data.
  /// - Returns: The decoded value.
  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(GitHubError) -> T {
    do {
      return try Self.decoder.decode(type, from: data)
    } catch {
      let logger = Logger(subsystem: "com.gitpulse", category: "GitHubAPIClient")
      logger.error(
        "Decoding \(String(describing: T.self)) failed: \(String(describing: error))")
      throw .decodingFailed(underlying: error)
    }
  }

  // MARK: - GitHubAPIProviding

  /// Fetches the authenticated user's profile from the `/user` endpoint.
  ///
  /// - Returns: The user profile data.
  func fetchUserProfile() async throws(GitHubError) -> GitHubUser {
    let url = baseURL.appendingPathComponent("user")
    let request = URLRequest(url: url)
    let (data, _) = try await performRequest(request)
    return try decode(GitHubUser.self, from: data)
  }

  /// Fetches contribution events since the specified date, paginating through results.
  ///
  /// Stops pagination early if all events on a page are older than `since`,
  /// or when the maximum page limit is reached.
  ///
  /// - Parameter since: The earliest date for which to return events.
  /// - Returns: An array of events created on or after `since`.
  func fetchContributions(since: Date) async throws(GitHubError) -> [GitHubEvent] {
    var allEvents: [GitHubEvent] = []
    var currentPage = 1

    while currentPage <= maxPaginationPages {
      let url = baseURL.appendingPathComponent("users/\(username)/events")
      guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        throw .unknown(
          underlying: NSError(
            domain: "GitHubAPIClient", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to construct events URL."]))
      }

      components.queryItems = [
        URLQueryItem(name: "per_page", value: "100"),
        URLQueryItem(name: "page", value: "\(currentPage)"),
      ]

      guard let requestURL = components.url else {
        throw .unknown(
          underlying: NSError(
            domain: "GitHubAPIClient", code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to construct events URL with query."]))
      }

      let request = URLRequest(url: requestURL)
      let (data, response) = try await performRequest(request)
      let events = try decode([GitHubEvent].self, from: data)

      if events.isEmpty {
        break
      }

      let filteredEvents = events.filter { $0.createdAt >= since }
      allEvents.append(contentsOf: filteredEvents)

      // If all events on this page are before the since date, stop paginating
      if filteredEvents.isEmpty {
        break
      }

      // Check for next page via Link header
      if Self.parseNextPageURL(from: response) == nil {
        break
      }

      currentPage += 1
    }

    return allEvents
  }

  /// Fetches the authenticated user's repositories for a given page.
  ///
  /// Repositories are sorted by most recently updated.
  ///
  /// - Parameter page: The 1-based page number to fetch.
  /// - Returns: An array of repositories for the requested page.
  func fetchRepositories(page: Int) async throws(GitHubError) -> [GitHubRepo] {
    let url = baseURL.appendingPathComponent("user/repos")
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to construct repos URL."]))
    }

    components.queryItems = [
      URLQueryItem(name: "per_page", value: "30"),
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "sort", value: "updated"),
    ]

    guard let requestURL = components.url else {
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to construct repos URL with query."]))
    }

    let request = URLRequest(url: requestURL)
    let (data, _) = try await performRequest(request)
    return try decode([GitHubRepo].self, from: data)
  }

  /// Fetches pull requests authored by the user with the specified state.
  ///
  /// Uses the GitHub Search API to find pull requests across all repositories.
  ///
  /// - Parameters:
  ///   - state: The PR state to filter by.
  ///   - page: The 1-based page number to fetch.
  /// - Returns: An array of pull requests matching the criteria.
  func fetchPullRequests(state: PullRequest.PRState, page: Int) async throws(GitHubError)
    -> [GitHubPR]
  {
    let url = baseURL.appendingPathComponent("search/issues")
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to construct search URL."]))
    }

    let stateQuery = state.rawValue
    components.queryItems = [
      URLQueryItem(name: "q", value: "author:\(username)+type:pr+state:\(stateQuery)"),
      URLQueryItem(name: "per_page", value: "30"),
      URLQueryItem(name: "page", value: "\(page)"),
    ]

    guard let requestURL = components.url else {
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to construct search URL with query."]))
    }

    let request = URLRequest(url: requestURL)
    let (data, _) = try await performRequest(request)
    let searchResponse = try decode(SearchResponse<GitHubPR>.self, from: data)
    return searchResponse.items
  }

  /// Validates whether a GitHub Personal Access Token is valid.
  ///
  /// Makes a test request to `/user` using the provided token (not the client's stored token).
  ///
  /// - Parameter token: The PAT to validate.
  /// - Returns: `true` if the token is valid (HTTP 200), `false` if unauthorized (HTTP 401).
  func validateToken(_ token: String) async throws(GitHubError) -> Bool {
    let url = baseURL.appendingPathComponent("user")
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await session.data(for: request)
    } catch let urlError as URLError
      where [
        .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost,
        .cannotConnectToHost,
      ].contains(urlError.code)
    {
      throw .networkUnavailable
    } catch {
      throw .unknown(underlying: error)
    }

    // Suppress unused variable warning — data is not needed for validation
    _ = data

    guard let httpResponse = response as? HTTPURLResponse else {
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response."]))
    }

    switch httpResponse.statusCode {
    case 200...299:
      return true
    case 401:
      return false
    case 403:
      let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining")
        .flatMap(Int.init)
      if remaining == 0 {
        let resetEpoch =
          httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
          .flatMap(TimeInterval.init)
          ?? Date.now.timeIntervalSince1970
        throw .rateLimited(resetAt: Date(timeIntervalSince1970: resetEpoch))
      }
      return false
    case 404:
      throw .notFound
    case 500...599:
      throw .serverError(httpResponse.statusCode)
    default:
      throw .unknown(
        underlying: NSError(
          domain: "GitHubAPIClient", code: httpResponse.statusCode,
          userInfo: [
            NSLocalizedDescriptionKey:
              "Unexpected HTTP status code: \(httpResponse.statusCode)."
          ]))
    }
  }

  /// Fetches the language breakdown for a specific repository.
  ///
  /// Calls the GitHub Languages API (`/repos/{owner}/{repo}/languages`) which
  /// returns a dictionary mapping language names to byte counts. No pagination
  /// is needed for this endpoint.
  ///
  /// - Parameters:
  ///   - owner: The repository owner (user or organization).
  ///   - repo: The repository name.
  /// - Returns: A dictionary mapping language names to byte counts.
  func fetchLanguages(owner: String, repo: String) async throws(GitHubError) -> [String: Int] {
    let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/languages")
    let request = URLRequest(url: url)
    let (data, _) = try await performRequest(request)
    return try decode([String: Int].self, from: data)
  }
}
