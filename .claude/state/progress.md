# Project Progress

## Current Phase
Phase: 5
Title: GitHub API Client — Endpoints
Status: NOT STARTED
Started: —

## Completed Phases
### Phase 4: GitHub API Client — Core — COMPLETED 2026-04-12
- [x] 4.1 GitHubAPIClient class with URLSession, Bearer auth header, Accept header, performRequest core method
- [x] 4.2 GitHubError typed error enum with 7 cases (unauthorized, rateLimited, notFound, networkUnavailable, serverError, decodingFailed, unknown) + manual Equatable
- [x] 4.3 Rate-limit tracking via X-RateLimit-* header parsing, RateLimitState struct, OSAllocatedUnfairLock storage
- [x] 4.4 Link header pagination parser (parseNextPageURL static method)
- [x] 4.5 26 tests: MockURLProtocol, MockGitHubAPIClient, 4 JSON fixtures, 21 API client tests + 5 mock fidelity tests
- Extras: All 5 endpoint methods fully implemented (fetchUserProfile, fetchContributions, fetchRepositories, fetchPullRequests, validateToken), 6 DTO types
- Verification: 75 total tests pass (0 failures), build clean

### Phase 3: Keychain Service — COMPLETED 2026-04-12
- [x] 3.1 KeychainError enum + KeychainProviding protocol + KeychainService struct (SecItem API, upsert semantics, injectable service name)
- [x] 3.2 MockKeychainService (dictionary-backed, @unchecked Sendable)
- [x] 3.3 13 tests: 10 real-Keychain integration tests + 3 mock-fidelity tests, all passing
- Verification: 37 total tests pass, no token values in logs, build clean

### Phase 2: SwiftData Models — COMPLETED 2026-04-12
- [x] 2.1 Implemented all 6 @Model classes: Contribution, Repository, LanguageStat, PullRequest, UserProfile, SyncMetadata
- [x] 2.2 SchemaV1 as VersionedSchema with all 6 models
- [x] 2.3 GitPulseSchemaMigrationPlan with SchemaV1 as only stage, GitPulseApp.swift updated with migration plan
- [x] 2.4 23 model tests: creation, relationships, cascade delete, unique upsert, computed properties, schema verification

### Phase 1: Xcode Project Scaffold — COMPLETED 2026-04-12
- [x] 1.1 Created 4 targets: GitPulse, GitPulseWidgetExtension, GitPulseTests, GitPulseUITests. macOS 26, Swift 6, strict concurrency.
- [x] 1.2 Full directory structure matching ARCHITECTURE.md §7.7 with ~50 placeholder .swift files
- [x] 1.3 Info.plist with BGTaskSchedulerPermittedIdentifiers. Entitlements with app group for both app + widget.
- [x] 1.4 GitPulseApp.swift with ModelContainer using groupContainer: .identifier("group.com.gitpulse.shared")

## Current Phase Tasks
- [ ] 5.1 Implement fetchContributions(since:) with date filtering and pagination
- [ ] 5.2 Implement fetchRepositories(page:) with pagination
- [ ] 5.3 Implement fetchPullRequests(state:page:) with search API
- [ ] 5.4 Implement validateToken(_:)
- [ ] 5.5 Write tests with JSON fixture files for each endpoint

## Success Criteria
- [ ] Each endpoint correctly decodes mock JSON fixtures
- [ ] Date filtering in fetchContributions excludes events before the since parameter
- [ ] validateToken returns false for 401, true for 200
- [ ] All endpoint tests pass with fixture data

## Session Log
- 2026-04-12: Phase 1 completed. Build succeeds. All 4 targets configured. Directory structure matches spec.
- 2026-04-12: Phase 2 completed. All 6 SwiftData models, SchemaV1, migration plan, 23 tests passing. Build clean.
- 2026-04-12: Phase 3 completed. KeychainService with SecItem API, MockKeychainService, 13 new tests (37 total). All pass.
- 2026-04-12 10:43: Session ended
- 2026-04-12 10:46: Session ended
- 2026-04-12: Phase 4 completed. GitHubAPIClient (683 lines): GitHubError, RateLimitState, 6 DTOs, protocol, full client. MockURLProtocol, MockGitHubAPIClient, 4 JSON fixtures, 26 new tests (75 total). All pass.
- 2026-04-12 11:11: Session ended
