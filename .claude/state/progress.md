# Project Progress

## Current Phase
Phase: 7
Title: Background Sync Service
Status: NOT STARTED
Started: —

## Completed Phases
### Phase 6: Streak Calculation Engine — COMPLETED 2026-04-12
- [x] 6.1 Date+Extensions.swift: startOfDay(in:) and adding(days:in:) utility methods
- [x] 6.2 StreakEngine.swift: StreakPeriod, StreakInfo types + StreakEngine struct with timezone-aware calculate() method (3 private helpers: uniqueLocalDays, calculateCurrentStreak, buildStreakPeriods)
- [x] 6.3 StreakEngineTests.swift: 22 test cases (18 individual + 4 parameterized) covering empty input, basic streaks, grace period, deduplication, UTC→local timezone boundaries, streak history, future dates, unsorted input
- Verification: 107 total tests pass (0 failures), build clean

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
- [ ] 7.1 Implement BackgroundDataWriter as @ModelActor
- [ ] 7.2 Implement BackgroundSyncService actor (register BGTask, schedule refresh, perform sync)
- [ ] 7.3 Wire BGAppRefreshTask registration in GitPulseApp.swift
- [ ] 7.4 Write sync flow tests (mock API → SwiftData → streak recalculation)

## Success Criteria
- [ ] performSync() fetches from all endpoints and persists to SwiftData
- [ ] Duplicate events (same ID) are upserted, not duplicated
- [ ] SyncMetadata is updated with last sync date and rate-limit info
- [ ] Streak is recalculated after new contributions are persisted
- [ ] All sync tests pass

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
- 2026-04-12 11:47: Session ended
- 2026-04-12 17:15: Session ended
