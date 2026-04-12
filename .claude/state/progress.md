# Project Progress

## Current Phase
Phase: 6
Title: Streak Calculation Engine
Status: NOT STARTED
Started: —

## Completed Phases
### Phase 5: GitHub API Client — Endpoints (Edge-Case Hardening) — COMPLETED 2026-04-12
- [x] 5.1–5.4 All endpoint methods verified as already implemented during Phase 4 (fetchContributions, fetchRepositories, fetchPullRequests, validateToken)
- [x] 5.5 All original Phase 5 success criteria confirmed passing
- [x] 5.6 Client hardening: expanded URLError catch (timedOut, networkConnectionLost, cannotFindHost, cannotConnectToHost → networkUnavailable)
- [x] 5.7 Client hardening: custom ISO 8601 date decoder with fractional-seconds support
- [x] 5.8 Client hardening: resilient Link header parsing (split on "," + trim whitespace)
- [x] 5.9 Test hardening: 16 new edge-case tests (5xx variants, timeout/network errors, future since date, early pagination termination, empty results, fractional timestamps, null payloads, unicode content, malformed Link headers, minimal PR fields, thread safety, max page limit)
- [x] 5.10 Mock improvements: result sequence support for multi-call scenarios
- Verification: 89 total tests pass (0 failures), build clean

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
- [ ] 6.1 Implement StreakEngine with timezone-aware streak calculation (ARCHITECTURE.md §4.3)
- [ ] 6.2 Implement StreakPeriod history builder
- [ ] 6.3 Write comprehensive streak tests (minimum 10 test cases)

## Success Criteria
- [ ] Current streak calculated correctly for a known contribution sequence
- [ ] Timezone conversion handles UTC→local day boundary correctly
- [ ] Empty contribution history returns all zeros
- [ ] Streak history contains correct start/end dates for each period
- [ ] All streak tests pass (minimum 10 test cases)

## Session Log
- 2026-04-12: Phase 1 completed. Build succeeds. All 4 targets configured. Directory structure matches spec.
- 2026-04-12: Phase 2 completed. All 6 SwiftData models, SchemaV1, migration plan, 23 tests passing. Build clean.
- 2026-04-12: Phase 3 completed. KeychainService with SecItem API, MockKeychainService, 13 new tests (37 total). All pass.
- 2026-04-12 10:43: Session ended
- 2026-04-12 10:46: Session ended
- 2026-04-12: Phase 4 completed. GitHubAPIClient (683 lines): GitHubError, RateLimitState, 6 DTOs, protocol, full client. MockURLProtocol, MockGitHubAPIClient, 4 JSON fixtures, 26 new tests (75 total). All pass.
- 2026-04-12 11:11: Session ended
- 2026-04-12 11:18: Session ended
- 2026-04-12: Phase 5 completed (edge-case hardening). 3 client changes (URLError expansion, fractional-seconds decoder, Link header resilience). 16 new tests + 2 mock improvements. 89 total tests, 0 failures.
- 2026-04-12 11:36: Session ended
- 2026-04-12 11:40: Session ended
- 2026-04-12 11:42: Session ended
- 2026-04-12 11:44: Session ended
- 2026-04-12 11:45: Session ended
- 2026-04-12 11:46: Session ended
