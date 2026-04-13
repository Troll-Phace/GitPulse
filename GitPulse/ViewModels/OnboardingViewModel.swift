//  OnboardingViewModel.swift
//  GitPulse

import Foundation
import SwiftUI

// MARK: - OnboardingViewModel

/// Manages the state and logic for the 4-step onboarding flow.
///
/// Handles token validation against the GitHub API, repository fetching
/// and selection, and Keychain persistence of the validated token.
/// The view model is `@MainActor` to safely drive SwiftUI state updates.
@Observable
@MainActor
final class OnboardingViewModel {

  // MARK: - Step

  /// The steps in the onboarding flow, presented in order.
  enum Step: Int, CaseIterable, Sendable {
    /// Welcome screen with app introduction.
    case welcome
    /// Token entry and validation.
    case tokenSetup
    /// Repository selection after successful token validation.
    case repoSelection
    /// Onboarding completion confirmation.
    case completion
  }

  // MARK: - Published State

  /// The currently displayed onboarding step.
  var currentStep: Step = .welcome

  /// The raw token string entered by the user.
  var tokenInput: String = ""

  /// Whether a token validation request is currently in flight.
  var isValidatingToken: Bool = false

  /// A user-facing error message if token validation fails.
  var tokenValidationError: String?

  /// Whether the token has been successfully validated.
  var isTokenValid: Bool = false

  /// The GitHub user profile retrieved after successful token validation.
  var validatedUser: GitHubUser?

  /// The list of repositories fetched for the authenticated user.
  var repositories: [GitHubRepo] = []

  /// The set of repository IDs the user has selected to track.
  var selectedRepoIDs: Set<Int> = []

  /// Whether a repository fetch request is currently in flight.
  var isLoadingRepos: Bool = false

  /// A user-facing error message if repository fetching fails.
  var repoLoadError: String?

  // MARK: - Dependencies

  /// The Keychain service used to persist the validated token.
  private let keychainService: KeychainProviding

  /// A factory that creates a GitHub API client for a given token.
  private let apiClientFactory: @Sendable (String) -> any GitHubAPIProviding

  /// The API client created during token validation, reused for repository fetching.
  private var apiClient: (any GitHubAPIProviding)?

  /// A closure called when onboarding completes, passing the validated GitHub username.
  ///
  /// The caller typically uses this to persist the username in `@AppStorage` and
  /// flip the `hasCompletedOnboarding` flag.
  var onComplete: ((String) -> Void)?

  // MARK: - Initialization

  /// Creates a new onboarding view model.
  ///
  /// - Parameters:
  ///   - keychainService: The Keychain service for token storage. Defaults to `KeychainService()`.
  ///   - apiClientFactory: A closure that creates a `GitHubAPIProviding` client for a given token.
  ///     Defaults to creating a `GitHubAPIClient` with an empty username (the username is populated
  ///     after profile fetch).
  init(
    keychainService: KeychainProviding = KeychainService(),
    apiClientFactory: @escaping @Sendable (String) -> any GitHubAPIProviding = { token in
      GitHubAPIClient(token: token, username: "")
    }
  ) {
    self.keychainService = keychainService
    self.apiClientFactory = apiClientFactory
  }

  // MARK: - Token Validation

  /// Validates the entered token against the GitHub API.
  ///
  /// Trims whitespace from the token input, creates an API client via the factory,
  /// calls `validateToken(_:)`, and on success fetches the user profile and persists
  /// the token in the Keychain. Automatically advances to the repo selection step
  /// and begins fetching repositories.
  ///
  /// On failure, sets `tokenValidationError` with a user-friendly message.
  func validateToken() async {
    let trimmedToken = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedToken.isEmpty else {
      tokenValidationError = "Please enter your GitHub Personal Access Token."
      return
    }

    isValidatingToken = true
    tokenValidationError = nil
    defer { isValidatingToken = false }

    let client = apiClientFactory(trimmedToken)

    do {
      let isValid = try await client.validateToken(trimmedToken)

      guard isValid else {
        tokenValidationError = "Invalid token. Please check your token and try again."
        return
      }

      let user = try await client.fetchUserProfile()

      try keychainService.save(token: trimmedToken, for: user.login)

      validatedUser = user
      isTokenValid = true
      apiClient = client

      currentStep = .repoSelection
      await fetchRepositories()
    } catch let error as GitHubError {
      tokenValidationError = userFacingMessage(for: error)
    } catch let error as KeychainError {
      tokenValidationError = "Failed to save token securely: \(error.localizedDescription)"
    } catch {
      tokenValidationError = "Something went wrong. Please try again."
    }
  }

  // MARK: - Repository Fetching

  /// Fetches all repositories for the authenticated user via pagination.
  ///
  /// Paginates through the repositories endpoint starting at page 1 until an empty
  /// page is returned or the maximum page limit (10) is reached. Populates
  /// `repositories` and selects all repos by default.
  ///
  /// On failure, sets `repoLoadError` with a user-friendly message.
  func fetchRepositories() async {
    guard let client = apiClient else { return }

    isLoadingRepos = true
    repoLoadError = nil
    defer { isLoadingRepos = false }

    var allRepos: [GitHubRepo] = []
    let maxPages = 10

    do {
      for page in 1...maxPages {
        let pageRepos = try await client.fetchRepositories(page: page)

        if pageRepos.isEmpty {
          break
        }

        allRepos.append(contentsOf: pageRepos)
      }

      repositories = allRepos
      selectedRepoIDs = Set(allRepos.map(\.id))
    } catch {
      repoLoadError = userFacingMessage(for: error)
    }
  }

  // MARK: - Repository Selection

  /// Toggles the selection state of a repository.
  ///
  /// If the repository ID is currently selected, it will be deselected, and vice versa.
  ///
  /// - Parameter repoID: The GitHub repository ID to toggle.
  func toggleRepoSelection(_ repoID: Int) {
    if selectedRepoIDs.contains(repoID) {
      selectedRepoIDs.remove(repoID)
    } else {
      selectedRepoIDs.insert(repoID)
    }
  }

  /// Selects all fetched repositories.
  func selectAllRepos() {
    selectedRepoIDs = Set(repositories.map(\.id))
  }

  /// Deselects all repositories.
  func deselectAllRepos() {
    selectedRepoIDs.removeAll()
  }

  // MARK: - Navigation

  /// Advances to the next onboarding step, if not already at the final step.
  func advanceStep() {
    guard let nextIndex = Step(rawValue: currentStep.rawValue + 1) else { return }
    currentStep = nextIndex
  }

  /// Returns to the previous onboarding step, if not already at the first step.
  func goBackStep() {
    guard let previousIndex = Step(rawValue: currentStep.rawValue - 1) else { return }
    currentStep = previousIndex
  }

  // MARK: - Completion

  /// Completes the onboarding flow by invoking the `onComplete` closure with the username.
  ///
  /// The closure receives the validated GitHub username so the caller can persist it
  /// alongside flipping the `@AppStorage` onboarding flag.
  func completeOnboarding() {
    let username = validatedUser?.login ?? ""
    onComplete?(username)
  }

  // MARK: - Private Helpers

  /// Maps a `GitHubError` to a user-friendly error message string.
  ///
  /// - Parameter error: The GitHub API error to translate.
  /// - Returns: A localized, user-facing error description.
  private func userFacingMessage(for error: GitHubError) -> String {
    switch error {
    case .unauthorized:
      "Invalid token. Please check your token and try again."
    case .networkUnavailable:
      "No internet connection. Please check your network."
    case .rateLimited:
      "GitHub API rate limit reached. Please try again later."
    default:
      "Something went wrong. Please try again."
    }
  }
}
