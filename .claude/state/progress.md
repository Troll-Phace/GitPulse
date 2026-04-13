# Project Progress

## Current Phase
Phase: 13
Title: Repositories & Languages View
Status: NOT STARTED
Started: —

## Completed Phases
### Phase 12: Streaks View — COMPLETED 2026-04-12
- [x] 12.1 Implemented StreaksViewModel (@Observable @MainActor): domain types (CalendarDay, StreakBar), StreakEngine integration, computed stats (currentStreak, longestStreak, activeDays, goalProgress, averageDailyCommits, trend), calendar builder (monthly grid with placeholders), streak history bar builder (normalized heights, longest/current flags), warning banner logic.
- [x] 12.2 Implemented StreakRingView: custom StreakArc Shape conforming to Animatable, ZStack with track circle + progress arc (AngularGradient orange→red) + flame icon (3-stop gradient + glow) + hero number + subtitle. Spring animation on appear, respects reduceMotion. Accessibility label.
- [x] 12.3 Implemented StreakCalendarView (in WeekBarChart.swift): monthly LazyVGrid with 7 columns, 5 cell states (placeholder/committed/today-at-risk/today-active/future/uncommitted), day headers, legend row. Uses gpGreen/gpRed tokens.
- [x] 12.4 Implemented StreakHistoryTimeline: Swift Charts BarMark chart, bars colored by state (gold=longest/BEST, orange=current/NOW, variable opacity for others), Y-axis labels (0d/15d/30d/50d), dashed grid lines, animated draw-in, empty state.
- [x] 12.5 Implemented StreaksView: ScrollView assembling warning banner (conditional, dismissable), two-column layout (hero ring card left, stat cards + calendar right), full-width history chart. @Query → ViewModel wiring matching DashboardView pattern. Empty state, entry animation.
- [x] 12.6 Added gpRed color token (#FF453A) to Color+Extensions.swift.
- [x] 12.7 35 StreaksViewModel tests: empty state (3), streak values (4), goal progress (3), warning banner (4), calendar grid (4), streak history bars (4), average daily commits (2), trend direction (3), date range (2), edge cases (6).
- Verification: 238 total tests pass (0 failures), build clean

### Phase 11: Dashboard View — COMPLETED 2026-04-12
- [x] 11.1 Implemented DashboardView layout: ScrollView with stat cards row, contribution heatmap, weekly chart + activity feed side-by-side, sync status bar. @Query data binding to DashboardViewModel. Empty state for first launch. Fade+slide entry animation with reduceMotion support.
- [x] 11.2 Implemented ContributionHeatmap using Swift Charts RectangleMark — 16-week grid with heatmap0-4 color scale, day labels (Mon/Wed/Fri), color legend row, total contributions footer, empty state, VoiceOver accessibility label.
- [x] 11.3 Implemented WeeklyActivityChart using LineMark + AreaMark with green gradient, Catmull-Rom interpolation, PointMark at data points, styled axes, empty state.
- [x] 11.4 Implemented reusable components: StatCard (90pt, glass, accent bar, value/label/trend/accessory), TrendArrow (up/down/flat with SF Symbol + color), SparklineView (60x24pt Canvas-based mini chart). GlassCard already existed from Phase 9.
- [x] 11.5 Implemented DashboardViewModel (@Observable @MainActor): domain types (HeatmapCell, DayActivity, ActivityFeedItem), computed stats (todayCommitCount, trends, activePRCount, streaks, languages), heatmap builder (112 cells, dynamic percentile buckets), weekly activity builder (7 days), recent activity feed (last 10), sync status text.
- [x] 11.6 Implemented StatCardsRow composing 4 stat cards: Today's Commits (sparkline + trend), Active PRs (subtitle), Current Streak (flame icon), Languages (mini bar). LanguageMiniBar helper.
- [x] 11.7 Implemented RecentActivityFeed timeline with colored dots, dashed connectors, title/subtitle/timestamp per activity type.
- [x] 11.8 27 DashboardViewModel tests: empty state (4), today commits (2), trends (4), active PRs (1), streak passthrough (1), languages (2), heatmap (2), weekly activity (2), recent feed (3), sync status (2), rate limit (2), sparkline (1), contributions in period (1).
- Verification: 203 total tests pass (0 failures), build clean

### Phase 10: App Shell & Navigation — COMPLETED 2026-04-12
- [x] 10.1 Defined `SidebarTab` enum (String, CaseIterable, Identifiable, Hashable) with 5 cases, computed title/systemImage/keyboardShortcutKey properties
- [x] 10.2 Implemented `@Observable NavigationState` class with `selectedTab: SidebarTab?` and animated `selectTab(_:)` method
- [x] 10.3 Rewrote ContentView with NavigationSplitView: sidebar with app branding, 4 main nav items + separated Settings, detail view switching via `switch` on selectedTab
- [x] 10.4 Used `@Environment(NavigationState.self)` + `@Bindable` for List selection binding, `.tag(Optional(tab))` for correct optional matching
- [x] 10.5 Added `.commands` on WindowGroup: Cmd+1–5 via CommandMenu("Navigation"), Cmd+, via CommandGroup(replacing: .appSettings), Cmd+R refresh placeholder
- [x] 10.6 Applied `.defaultSize(width: 1100, height: 750)`, `.frame(minWidth: 900, minHeight: 600)`, `Color.gpBackground` background, `.listStyle(.sidebar)`, `.scrollContentBackground(.hidden)`
- Verification: Build succeeds, 168 total tests pass (0 failures), no regressions

### Phase 9: Onboarding Flow — COMPLETED 2026-04-12
- [x] 9.1 Implemented OnboardingFlow with custom step-based navigation (switch on Step enum with slide transitions, not TabView) through 4 steps: Welcome, Token Setup, Repo Selection, Completion
- [x] 9.2 Implemented TokenSetupStep: SecureField with glass styling, NSPasteboard paste button, 3 numbered instruction cards (GlassCard), inline error display (gpOrange), ProgressView spinner during validation, "Validate & Continue" CTA
- [x] 9.3 Implemented RepoSelectionStep: scrollable LazyVStack of repo rows with checkboxes, language dots, star counts; Select All/Deselect All buttons; loading/error states with retry
- [x] 9.4 Applied Liquid Glass styling to all onboarding steps: .glassEffect() on cards, PrimaryCTAButtonStyle (green gradient CTA), SecondaryButtonStyle, StepIndicator dots, all using DesignTokens
- [x] 9.5 Implemented OnboardingViewModel (@Observable @MainActor): token validation with error mapping, Keychain storage, repo pagination, selection state, step navigation, completion callback
- [x] 9.6 Implemented design system foundations: Color+Extensions (17 color tokens + hex init), DesignTokens enum (spacing, radius, sizes, animation), Font extensions (8 type scale tokens)
- [x] 9.7 Implemented GlassCard component, PrimaryCTAButtonStyle, SecondaryButtonStyle, DestructiveButtonStyle, StepIndicator
- [x] 9.8 Wired onboarding gate in ContentView via @AppStorage("hasCompletedOnboarding")
- [x] 9.9 23 OnboardingViewModel tests: token validation (success, invalid, unauthorized, network, rate limit, empty, whitespace), keychain storage, profile fetch, repo fetching (pagination, errors), selection (toggle, selectAll, deselectAll), navigation, completion
- Verification: 168 total tests pass (0 failures), build clean

### Phase 8: Notification Service — COMPLETED 2026-04-12
- [x] 8.1 Implemented NotificationService: `GitPulseNotification`, `MilestoneType`, `NotificationError`, `NotificationIdentifier` enums; `NotificationCenterProviding` protocol + `SystemNotificationCenter` wrapper; `NotificationProviding` protocol + `NotificationService` struct
- [x] 8.2 Implemented `evaluateAlerts(streakInfo:totalCommits:totalPRsMerged:todayCommits:todayPRs:)`: streak-at-risk (configurable hour, default 21:00), streak-broken (00:05), daily summary (22:00), milestone dedup via UserDefaults
- [x] 8.3 Integrated into BackgroundSyncService: optional `notificationService` param in init, `evaluateAlerts` called after sync step 9 with `try?` (non-breaking)
- [x] 8.4 MockNotificationCenter + 14 test methods (18 executions with parameterized): auth, streak-at-risk, streak-broken, daily summary, milestone thresholds, dedup, configurable alert hour, cancel all
- Verification: 153 total tests pass (0 failures), build clean

### Phase 7: Background Sync Service — COMPLETED 2026-04-12
- [x] 7.1 Added `currentRateLimit` to `GitHubAPIProviding` protocol and `MockGitHubAPIClient`
- [x] 7.2 Implemented `BackgroundDataWriter` (@ModelActor): importContributions, importRepositories, importPullRequests, updateUserProfile, updateSyncMetadata, fetchAllContributionDates, fetchLastSyncDate
- [x] 7.3 Implemented `BackgroundSyncService` (actor): performSync (9-step sync cycle), scheduleRefresh (NSBackgroundActivityScheduler for macOS), registerBackgroundTask. Used `#if os(iOS)` for BGAppRefreshTask (unavailable on macOS).
- [x] 7.4 Wired BGTask registration in GitPulseApp.swift init()
- [x] 7.5 15 BackgroundSync tests: endpoint calls, contribution/repo/PR persistence, upsert dedup, sync metadata, streak recalculation, since-date from metadata, default 90-day lookback, pagination, user profile, empty data, event type mapping
- [x] 7.6 Marked StreakEngine/StreakPeriod/StreakInfo as nonisolated for cross-actor access (Swift 6 concurrency fix)
- Verification: 122 total tests pass (0 failures), build clean

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
- [ ] 13.1 Implement ReposView with glass search bar, language donut chart, scrollable repo card list
- [ ] 13.2 Implement LanguageDonutChart using SectorMark
- [ ] 13.3 Implement RepoCardView with repo name, language badge, star count, last push date, sparkline
- [ ] 13.4 Implement RepoDetailSheet as .sheet modifier
- [ ] 13.5 Wire ReposViewModel with search filtering and language aggregation

## Success Criteria
- [ ] Donut chart shows language distribution with correct colors
- [ ] Search filters repo list by name
- [ ] Repo cards display all required fields
- [ ] Tapping a repo opens the detail sheet
- [ ] Language percentages sum to 100%

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
- 2026-04-12 17:52: Session ended
- 2026-04-12 18:17: Session ended
- 2026-04-12 18:20: Session ended
- 2026-04-12 18:49: Session ended
- 2026-04-12 19:04: Session ended
- 2026-04-12 19:38: Session ended
- 2026-04-12 19:44: Session ended
- 2026-04-12 19:46: Session ended
- 2026-04-12 19:48: Session ended
- 2026-04-12 19:49: Session ended
- 2026-04-12 19:50: Session ended
- 2026-04-12 19:51: Session ended
- 2026-04-12 19:53: Session ended
- 2026-04-12 20:12: Session ended
- 2026-04-12 20:17: Session ended
- 2026-04-12 20:27: Session ended
- 2026-04-12 20:44: Session ended
- 2026-04-12 20:58: Session ended
- 2026-04-12 21:01: Session ended
- 2026-04-12 21:04: Session ended
- 2026-04-12 21:07: Session ended
- 2026-04-12 21:09: Session ended
- 2026-04-12 21:11: Session ended
- 2026-04-12 21:12: Session ended
- 2026-04-12 21:13: Session ended
- 2026-04-12 21:16: Session ended
- 2026-04-12 21:21: Session ended
- 2026-04-12 21:23: Session ended
- 2026-04-12 21:36: Session ended
- 2026-04-12 21:38: Session ended
- 2026-04-12 21:53: Session ended
- 2026-04-12 21:55: Session ended
- 2026-04-12 22:06: Session ended
- 2026-04-12 22:14: Session ended
- 2026-04-12 22:20: Session ended
- 2026-04-12 22:24: Session ended
- 2026-04-12 22:26: Session ended
- 2026-04-12 22:44: Session ended
- 2026-04-12 22:45: Session ended
- 2026-04-12 22:47: Session ended
- 2026-04-12 22:49: Session ended
- 2026-04-12 22:58: Session ended
- 2026-04-12 23:04: Session ended
- 2026-04-12 23:07: Session ended
- 2026-04-12 23:23: Session ended
- 2026-04-12 23:23: Session ended
- 2026-04-12 23:26: Session ended
- 2026-04-12 23:27: Session ended
- 2026-04-12 23:29: Session ended
- 2026-04-12 23:30: Session ended
- 2026-04-12 23:37: Session ended
- 2026-04-12 23:41: Session ended
- 2026-04-12 23:43: Session ended
- 2026-04-12 23:45: Session ended
- 2026-04-12 23:47: Session ended
- 2026-04-12 23:48: Session ended
- 2026-04-12 23:50: Session ended
- 2026-04-13 00:05: Session ended
- 2026-04-13 00:06: Session ended
- 2026-04-13 00:15: Session ended
- 2026-04-13 00:25: Session ended
- 2026-04-13 00:30: Session ended
- 2026-04-13 00:32: Session ended
