//  OnboardingViewModelTests.swift
//  GitPulseTests

import Foundation
import Testing

@testable import GitPulse

// MARK: - OnboardingViewModelTests

/// Comprehensive tests for the onboarding view model's token validation,
/// repository fetching/selection, navigation, and completion flows.
///
/// Each test creates an isolated `MockKeychainService` and a
/// `MockGitHubAPIClient` via the factory closure to ensure full determinism.
@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {

  // MARK: - Helpers

  /// Creates a `GitHubUser` DTO with sensible defaults for testing.
  private func makeUser(
    login: String = "testuser",
    id: Int = 12345,
    avatarUrl: String = "https://example.com/avatar.png",
    name: String? = "Test User",
    bio: String? = nil,
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

  /// Creates a `GitHubRepo` DTO with sensible defaults for testing.
  private func makeRepo(
    id: Int,
    name: String = "repo",
    fullName: String = "testuser/repo",
    language: String? = "Swift",
    starCount: Int = 0
  ) -> GitHubRepo {
    GitHubRepo(
      id: id,
      name: name,
      fullName: fullName,
      description: "A test repository",
      language: language,
      stargazersCount: starCount,
      forksCount: 0,
      isPrivate: false,
      pushedAt: nil,
      createdAt: Date(timeIntervalSince1970: 1_690_000_000),
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
  }

  /// Creates an `OnboardingViewModel` wired to the given mock API client and keychain.
  ///
  /// The `apiClientFactory` closure captures `mockClient` so every call to
  /// `validateToken` inside the view model reuses the same mock instance.
  private func makeViewModel(
    mockClient: MockGitHubAPIClient = MockGitHubAPIClient(),
    keychain: MockKeychainService = MockKeychainService()
  ) -> (viewModel: OnboardingViewModel, client: MockGitHubAPIClient, keychain: MockKeychainService)
  {
    let vm = OnboardingViewModel(
      keychainService: keychain,
      apiClientFactory: { _ in mockClient }
    )
    return (vm, mockClient, keychain)
  }

  // MARK: - Token Validation — Success

  @Test("validateToken sets isTokenValid when token is valid")
  func test_validateToken_success_setsIsTokenValid() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResult = .success([])

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken123"

    await vm.validateToken()

    #expect(vm.isTokenValid == true)
    #expect(vm.validatedUser != nil)
  }

  @Test("validateToken stores token in Keychain keyed by username")
  func test_validateToken_success_storesTokenInKeychain() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser(login: "octocat"))
    mock.fetchRepositoriesResult = .success([])

    let keychain = MockKeychainService()
    let (vm, _, _) = makeViewModel(mockClient: mock, keychain: keychain)
    vm.tokenInput = "ghp_mytoken"

    await vm.validateToken()

    #expect(keychain.storage["octocat"] == "ghp_mytoken")
  }

  @Test("validateToken calls fetchUserProfile after successful validation")
  func test_validateToken_success_fetchesUserProfile() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResult = .success([])

    let (vm, client, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    #expect(client.fetchUserProfileCallCount == 1)
  }

  @Test("validateToken advances to repoSelection step on success")
  func test_validateToken_success_advancesToRepoSelection() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResult = .success([])

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    #expect(vm.currentStep == .repoSelection)
  }

  // MARK: - Token Validation — Failure

  @Test("validateToken sets error when token is invalid (returns false)")
  func test_validateToken_invalidToken_setsError() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(false)

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_badtoken"

    await vm.validateToken()

    #expect(vm.tokenValidationError != nil)
    #expect(vm.isTokenValid == false)
  }

  @Test("validateToken sets error message for unauthorized (401)")
  func test_validateToken_unauthorized_setsError() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .failure(.unauthorized)

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_expired"

    await vm.validateToken()

    #expect(vm.tokenValidationError?.contains("Invalid token") == true)
  }

  @Test("validateToken sets error message for network unavailable")
  func test_validateToken_networkError_setsError() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .failure(.networkUnavailable)

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_sometoken"

    await vm.validateToken()

    #expect(vm.tokenValidationError?.lowercased().contains("internet") == true)
  }

  @Test("validateToken sets error message for rate limited")
  func test_validateToken_rateLimited_setsError() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .failure(.rateLimited(resetAt: Date()))

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_sometoken"

    await vm.validateToken()

    #expect(vm.tokenValidationError?.lowercased().contains("rate limit") == true)
  }

  @Test("validateToken sets error for empty token input without calling API")
  func test_validateToken_emptyInput_setsError() async {
    let mock = MockGitHubAPIClient()

    let (vm, client, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = ""

    await vm.validateToken()

    #expect(vm.tokenValidationError != nil)
    #expect(client.validateTokenCallCount == 0)
  }

  @Test("validateToken treats whitespace-only input as empty")
  func test_validateToken_whitespaceOnly_setsError() async {
    let mock = MockGitHubAPIClient()

    let (vm, client, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "   "

    await vm.validateToken()

    #expect(vm.tokenValidationError != nil)
    #expect(client.validateTokenCallCount == 0)
  }

  // MARK: - Repository Fetching

  @Test("fetchRepositories populates the repositories list")
  func test_fetchRepositories_populatesList() async {
    let repos = [
      makeRepo(id: 1, name: "alpha", fullName: "testuser/alpha"),
      makeRepo(id: 2, name: "beta", fullName: "testuser/beta"),
    ]

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    // First page returns repos, second page returns empty (stops pagination).
    mock.fetchRepositoriesResults = [.success(repos), .success([])]

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    #expect(vm.repositories.count == 2)
  }

  @Test("fetchRepositories selects all repos by default")
  func test_fetchRepositories_selectsAllByDefault() async {
    let repos = [
      makeRepo(id: 10, name: "one"),
      makeRepo(id: 20, name: "two"),
      makeRepo(id: 30, name: "three"),
    ]

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResults = [.success(repos), .success([])]

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    #expect(vm.selectedRepoIDs == Set([10, 20, 30]))
  }

  @Test("fetchRepositories paginates until empty page")
  func test_fetchRepositories_paginates() async {
    let page1 = [makeRepo(id: 1, name: "r1"), makeRepo(id: 2, name: "r2")]
    let page2 = [makeRepo(id: 3, name: "r3")]
    let page3: [GitHubRepo] = []

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResults = [.success(page1), .success(page2), .success(page3)]

    let (vm, client, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    #expect(vm.repositories.count == 3)
    // Page 1 + Page 2 + Page 3 (empty, triggers break) = 3 calls
    #expect(client.fetchRepositoriesCallCount == 3)
  }

  @Test("fetchRepositories sets repoLoadError on failure")
  func test_fetchRepositories_error_setsRepoLoadError() async {
    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResult = .failure(.networkUnavailable)

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    #expect(vm.repoLoadError != nil)
    #expect(vm.repositories.isEmpty)
  }

  // MARK: - Repository Selection

  @Test("toggleRepoSelection removes a selected repo from the set")
  func test_toggleRepoSelection_removesFromSet() async {
    let repos = [makeRepo(id: 1), makeRepo(id: 2), makeRepo(id: 3)]

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResults = [.success(repos), .success([])]

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    vm.toggleRepoSelection(2)

    #expect(vm.selectedRepoIDs == Set([1, 3]))
  }

  @Test("toggleRepoSelection re-adds a deselected repo to the set")
  func test_toggleRepoSelection_addsBackToSet() async {
    let repos = [makeRepo(id: 1), makeRepo(id: 2), makeRepo(id: 3)]

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResults = [.success(repos), .success([])]

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    vm.toggleRepoSelection(2)
    vm.toggleRepoSelection(2)

    #expect(vm.selectedRepoIDs == Set([1, 2, 3]))
  }

  @Test("selectAllRepos selects all repositories after partial deselection")
  func test_selectAllRepos_selectsEverything() async {
    let repos = [makeRepo(id: 1), makeRepo(id: 2), makeRepo(id: 3)]

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResults = [.success(repos), .success([])]

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    vm.toggleRepoSelection(1)
    vm.toggleRepoSelection(3)
    #expect(vm.selectedRepoIDs == Set([2]))

    vm.selectAllRepos()

    #expect(vm.selectedRepoIDs == Set([1, 2, 3]))
  }

  @Test("deselectAllRepos empties the selected set")
  func test_deselectAllRepos_emptiesSet() async {
    let repos = [makeRepo(id: 1), makeRepo(id: 2)]

    let mock = MockGitHubAPIClient()
    mock.validateTokenResult = .success(true)
    mock.fetchUserProfileResult = .success(makeUser())
    mock.fetchRepositoriesResults = [.success(repos), .success([])]

    let (vm, _, _) = makeViewModel(mockClient: mock)
    vm.tokenInput = "ghp_validtoken"

    await vm.validateToken()

    vm.deselectAllRepos()

    #expect(vm.selectedRepoIDs.isEmpty)
  }

  // MARK: - Navigation

  @Test("advanceStep progresses from welcome to tokenSetup")
  func test_advanceStep_progressesCorrectly() {
    let (vm, _, _) = makeViewModel()

    #expect(vm.currentStep == .welcome)

    vm.advanceStep()
    #expect(vm.currentStep == .tokenSetup)

    vm.advanceStep()
    #expect(vm.currentStep == .repoSelection)

    vm.advanceStep()
    #expect(vm.currentStep == .completion)
  }

  @Test("goBackStep regresses from tokenSetup to welcome")
  func test_goBackStep_regressesCorrectly() {
    let (vm, _, _) = makeViewModel()

    vm.currentStep = .repoSelection

    vm.goBackStep()
    #expect(vm.currentStep == .tokenSetup)

    vm.goBackStep()
    #expect(vm.currentStep == .welcome)
  }

  @Test("advanceStep does nothing when already at completion")
  func test_advanceStep_doesNothingAtCompletion() {
    let (vm, _, _) = makeViewModel()

    vm.currentStep = .completion

    vm.advanceStep()

    #expect(vm.currentStep == .completion)
  }

  @Test("goBackStep does nothing when already at welcome")
  func test_goBackStep_doesNothingAtWelcome() {
    let (vm, _, _) = makeViewModel()

    #expect(vm.currentStep == .welcome)

    vm.goBackStep()

    #expect(vm.currentStep == .welcome)
  }

  // MARK: - Completion

  @Test("completeOnboarding invokes the onComplete closure with username")
  func test_completeOnboarding_callsOnComplete() {
    let (vm, _, _) = makeViewModel()

    var receivedUsername: String?
    vm.onComplete = { username in receivedUsername = username }

    vm.completeOnboarding()

    #expect(receivedUsername != nil)
  }
}
