# GitPulse — Phased Build Plan

Each phase has 3–5 tasks, assigned subagents, and verifiable success criteria. Complete phases in order. Do not skip ahead.

> **Wireframe Requirement**: ALL frontend tasks (assigned to `frontend-dev`) MUST reference the corresponding wireframe from `wireframes/` before implementation. The orchestrator MUST include the wireframe path in every frontend delegation prompt. See the wireframe map in `.claude/rules/wireframe-required.md`.

---

## Phase 1: Xcode Project Scaffold

**Objective**: Create the Xcode project structure with all directories, targets, and base configuration.
**Prerequisites**: None

### Tasks
1. **[backend-dev]** Create the Xcode project with three targets: `GitPulse` (macOS app), `GitPulseWidget` (WidgetKit extension), `GitPulseTests` (unit test bundle). Set deployment target to macOS 26. Enable Swift 6 strict concurrency.
2. **[backend-dev]** Create the full directory structure as specified in ARCHITECTURE.md §7.7. Add empty placeholder `.swift` files so the structure compiles.
3. **[backend-dev]** Configure `Info.plist` with `BGTaskSchedulerPermittedIdentifiers` (`com.gitpulse.refresh`) and app group identifier (`group.com.gitpulse.shared`).
4. **[backend-dev]** Create `GitPulseApp.swift` with `@main`, a basic `WindowGroup` scene, and a `ModelContainer` configured with the app group for SwiftData sharing with the widget.

### Success Criteria
- [ ] Project builds with `xcodebuild build -scheme GitPulse -destination 'platform=macOS'`
- [ ] All three targets exist and are configured
- [ ] Directory structure matches ARCHITECTURE.md §7.7
- [ ] `Info.plist` contains BGTask identifier and app group

---

## Phase 2: SwiftData Models

**Objective**: Define all persistent data models with proper relationships and schema versioning.
**Prerequisites**: Phase 1

### Tasks
1. **[backend-dev]** Implement `Contribution`, `Repository`, `LanguageStat`, `PullRequest`, `UserProfile`, and `SyncMetadata` as `@Model` classes following ARCHITECTURE.md §5.1.
2. **[backend-dev]** Implement `SchemaV1` as a `VersionedSchema` wrapping all models.
3. **[backend-dev]** Create `SchemaMigrationPlan` conforming to `SchemaMigrationPlan` protocol with `SchemaV1` as the only current stage.
4. **[test-engineer]** Write tests: model creation, relationship cascades (deleting Repository deletes LanguageStats), unique constraint enforcement, `PullRequest.timeToMerge` computed property.

### Success Criteria
- [ ] All 6 models compile with correct `@Model`, `@Attribute`, and `@Relationship` annotations
- [ ] `VersionedSchema` declared for v1
- [ ] All model tests pass
- [ ] In-memory ModelContainer can be created with all models

---

## Phase 3: Keychain Service

**Objective**: Build a secure token storage layer using Keychain Services.
**Prerequisites**: Phase 1

### Tasks
1. **[backend-dev]** Implement `KeychainService` conforming to `KeychainProviding` protocol (ARCHITECTURE.md §4.7). Use `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`.
2. **[backend-dev]** Define `KeychainError` typed error enum: `duplicateItem`, `itemNotFound`, `unexpectedData`, `unhandled(OSStatus)`.
3. **[test-engineer]** Write tests for save/retrieve/delete/update flows, duplicate handling, and error cases. Use a unique test service name to avoid polluting the real Keychain.

### Success Criteria
- [ ] Token save → retrieve round-trip works
- [ ] Deleting a non-existent token returns `.itemNotFound`
- [ ] All Keychain tests pass
- [ ] No token values appear in logs or print statements

---

## Phase 4: GitHub API Client — Core

**Objective**: Build the async networking layer with authentication, error handling, and rate-limit tracking.
**Prerequisites**: Phase 3

### Tasks
1. **[backend-dev]** Implement `GitHubAPIClient` conforming to `GitHubAPIProviding` (ARCHITECTURE.md §4.1). Set up `URLSession` with default configuration, `Authorization: Bearer {token}` header, and `Accept: application/vnd.github.v3+json`.
2. **[backend-dev]** Implement `GitHubError` typed error enum with all cases from ARCHITECTURE.md §4.1.
3. **[backend-dev]** Implement rate-limit tracking by parsing `X-RateLimit-*` headers on every response. Expose `RateLimitState` as a published property.
4. **[backend-dev]** Implement `Link` header pagination parser for multi-page responses.
5. **[test-engineer]** Write tests using `URLProtocol` mock: successful responses, 401/403/404/5xx errors, rate-limit header parsing, pagination.

### Success Criteria
- [ ] `fetchUserProfile()` decodes a mock `/user` response correctly
- [ ] 401 response throws `.unauthorized`
- [ ] 403 with rate-limit headers throws `.rateLimited` with correct reset date
- [ ] Pagination fetches all pages until `rel="next"` is absent
- [ ] All API client tests pass

---

## Phase 5: GitHub API Client — Endpoints

**Objective**: Implement all specific API endpoint methods with JSON decoding.
**Prerequisites**: Phase 4

### Tasks
1. **[backend-dev]** Implement `fetchContributions(since:)` — calls `/users/{user}/events`, filters by date, paginates up to 10 pages.
2. **[backend-dev]** Implement `fetchRepositories(page:)` — calls `/user/repos` with pagination.
3. **[backend-dev]** Implement `fetchPullRequests(state:page:)` — calls `/search/issues` with `author:{user}+type:pr` query.
4. **[backend-dev]** Implement `validateToken(_:)` — calls `/user` and returns `true` if 200, `false` if 401.
5. **[test-engineer]** Write tests with JSON fixture files for each endpoint, including edge cases: empty results, malformed JSON, missing optional fields.

### Success Criteria
- [ ] Each endpoint correctly decodes mock JSON fixtures
- [ ] Date filtering in `fetchContributions` excludes events before the `since` parameter
- [ ] `validateToken` returns `false` for 401, `true` for 200
- [ ] All endpoint tests pass with fixture data

---

## Phase 6: Streak Calculation Engine

**Objective**: Build the timezone-aware streak calculation logic.
**Prerequisites**: Phase 2

### Tasks
1. **[backend-dev]** Implement `StreakEngine` with the algorithm from ARCHITECTURE.md §4.3. Accept a `TimeZone` parameter (default: `.autoupdatingCurrent`).
2. **[backend-dev]** Implement `StreakPeriod` history builder that walks the contribution history and identifies contiguous active periods.
3. **[test-engineer]** Write comprehensive tests: basic streak, streak broken, timezone edge cases (commit at 11:30 PM ET = next day UTC), empty history, single-day streak, multi-year streak, today-has-no-contributions grace period.

### Success Criteria
- [ ] Current streak calculated correctly for a known contribution sequence
- [ ] Timezone conversion handles UTC→local day boundary correctly
- [ ] Empty contribution history returns all zeros
- [ ] Streak history contains correct start/end dates for each period
- [ ] All streak tests pass (minimum 10 test cases)

---

## Phase 7: Background Sync Service

**Objective**: Wire up the API client to SwiftData persistence with background refresh support.
**Prerequisites**: Phases 4, 5, 6

### Tasks
1. **[backend-dev]** Implement `BackgroundDataWriter` as a `@ModelActor` for thread-safe SwiftData writes (ARCHITECTURE.md §4.2).
2. **[backend-dev]** Implement `BackgroundSyncService` as an actor (ARCHITECTURE.md §4.8): register BGTask, schedule refresh, perform full sync cycle (fetch → persist → recalculate streaks → update SyncMetadata).
3. **[backend-dev]** Wire `BGAppRefreshTask` registration in `GitPulseApp.swift` at app launch.
4. **[test-engineer]** Write tests for the sync flow using mock API client and in-memory SwiftData container. Verify models are created/updated correctly after a sync.

### Success Criteria
- [ ] `performSync()` fetches from all endpoints and persists to SwiftData
- [ ] Duplicate events (same ID) are upserted, not duplicated
- [ ] `SyncMetadata` is updated with last sync date and rate-limit info
- [ ] Streak is recalculated after new contributions are persisted
- [ ] All sync tests pass

---

## Phase 8: Notification Service

**Objective**: Implement local notification scheduling for streak alerts and milestones.
**Prerequisites**: Phase 6

### Tasks
1. **[backend-dev]** Implement `NotificationService` (ARCHITECTURE.md §4.9): request authorization, schedule streak-at-risk at configurable time, daily summary, milestone celebrations.
2. **[backend-dev]** Implement `evaluateAlerts(streak:milestones:)` — called after each sync to determine which notifications to schedule or cancel.
3. **[test-engineer]** Write tests for notification evaluation logic (which notifications fire for which states). Mock `UNUserNotificationCenter`.

### Success Criteria
- [ ] Streak-at-risk notification scheduled when no contributions today and time > 9 PM
- [ ] Milestone notification fires for streak = 7, 30, 50, 100, 365
- [ ] Daily summary includes correct commit/PR counts
- [ ] Authorization request handles denial gracefully
- [ ] All notification tests pass

---

## Phase 9: Onboarding Flow

**Objective**: Build the 4-step onboarding experience for first-time users.
**Prerequisites**: Phases 3, 4

### Tasks
1. **[frontend-dev]** Implement `OnboardingFlow.swift` with `TabView` pagination through 4 steps: Welcome, Token Setup, Repo Selection, Completion.
2. **[frontend-dev]** Implement `TokenSetupStep` with secure text field, paste button, inline validation using `validateToken()`, and 3 numbered instruction cards for creating a PAT on GitHub.
3. **[frontend-dev]** Implement `RepoSelectionStep` that fetches repos after token validation and lets the user select which repos to track (default: all).
4. **[frontend-dev]** Apply Liquid Glass styling to all onboarding steps per DESIGN_SYSTEM.md. Use `.glassEffect()` on cards, glass CTA button with green gradient.
5. **[test-engineer]** Write ViewModel tests for token validation flow, repo selection state, and onboarding completion persistence.

### Success Criteria
- [ ] Onboarding shows on first launch, not on subsequent launches
- [ ] Token validates against GitHub API before proceeding
- [ ] Invalid token shows inline error message
- [ ] Token is stored in Keychain after validation
- [ ] Repo selection fetches and displays user's repos
- [ ] All views use Liquid Glass effects

---

## Phase 10: App Shell & Navigation

**Objective**: Build the main app container with NavigationSplitView sidebar and tab-equivalent navigation.
**Prerequisites**: Phase 1

### Tasks
> **Wireframe**: Read `wireframes/01-activity-dashboard.svg` for navigation structure reference before implementing.

1. **[frontend-dev]** Implement the main `ContentView` using `NavigationSplitView` with a sidebar containing 5 navigation items: Dashboard, Streaks, Repos, PRs, Settings. Use SF Symbols for icons.
2. **[frontend-dev]** Implement navigation state management with a `@Observable` `NavigationState` class tracking selected tab.
3. **[frontend-dev]** Add keyboard shortcuts: Cmd+1–5 for tab switching, Cmd+R for manual refresh, Cmd+, for settings.
4. **[frontend-dev]** Apply the dark background (#0D0D0F) and Liquid Glass sidebar styling per DESIGN_SYSTEM.md.

### Success Criteria
- [ ] `NavigationSplitView` displays sidebar with 5 items
- [ ] Selecting a sidebar item shows the corresponding view in the detail area
- [ ] Keyboard shortcuts work (Cmd+1 = Dashboard, Cmd+2 = Streaks, etc.)
- [ ] Sidebar uses glass effect, background is #0D0D0F
- [ ] App shell compiles and runs

---

## Phase 11: Dashboard View

**Objective**: Build the main Dashboard with contribution heatmap, stat cards, weekly chart, and activity feed.
**Prerequisites**: Phases 2, 7, 10

### Tasks
> **Wireframe**: Read `wireframes/01-activity-dashboard.svg` before implementing.

1. **[frontend-dev]** Implement `DashboardView` layout: greeting line with username, streak banner card, 3 stat cards row (commits today, PRs open, this week), contribution heatmap, weekly activity chart, recent activity feed.
2. **[frontend-dev]** Implement `ContributionHeatmap` using Swift Charts `RectangleMark` grid (ARCHITECTURE.md §4.4) with dynamic intensity buckets and hover tooltip.
3. **[frontend-dev]** Implement `WeeklyActivityChart` using `LineMark` + `AreaMark` with gradient fill.
4. **[frontend-dev]** Implement reusable `StatCard` and `GlassCard` components per DESIGN_SYSTEM.md.
5. **[frontend-dev]** Wire `DashboardViewModel` with `@Query` for contributions, repos, PRs, and computed stats.

### Success Criteria
- [ ] Dashboard displays all sections: greeting, streak banner, stats, heatmap, chart, feed
- [ ] Heatmap renders 16 weeks of data with correct green color scale
- [ ] Stat cards show correct values from SwiftData
- [ ] Weekly chart displays 7 days of activity
- [ ] All components use Liquid Glass styling
- [ ] Dashboard works with empty data (first launch before sync)

---

## Phase 12: Streaks View

**Objective**: Build the Streaks detail view with ring visualization, week breakdown, and history.
**Prerequisites**: Phases 6, 10

### Tasks
> **Wireframe**: Read `wireframes/02-streak-tracking.svg` before implementing.

1. **[frontend-dev]** Implement `StreaksView` with hero streak ring (progress arc toward best streak), 3 stat cards (current, longest, active days), weekly bar chart, and streak history timeline.
2. **[frontend-dev]** Implement `StreakRingView` using `Canvas` or custom `Shape` — animated arc showing current/longest ratio.
3. **[frontend-dev]** Implement `WeekBarChart` with `BarMark` showing per-day breakdown, today highlighted with accent color.
4. **[frontend-dev]** Implement `StreakHistoryTimeline` — horizontal bars showing each past streak's length with date labels.

### Success Criteria
- [ ] Streak ring shows correct progress ratio (current / longest)
- [ ] Bar chart displays 7 days with today highlighted
- [ ] Streak history shows chronological list of past streak periods
- [ ] All stat cards show correct values
- [ ] Liquid Glass styling applied to all cards and containers

---

## Phase 13: Repositories & Languages View

**Objective**: Build the Repos view with language breakdown chart, repo cards, and detail drill-in.
**Prerequisites**: Phases 2, 5, 10

### Tasks
> **Wireframe**: Read `wireframes/03-repository-breakdown.svg` and `wireframes/04-language-analytics.svg` before implementing.

1. **[frontend-dev]** Implement `ReposView` with glass search bar, language donut chart, and scrollable repo card list.
2. **[frontend-dev]** Implement `LanguageDonutChart` using `SectorMark` with language colors from GitHub and interactive legend.
3. **[frontend-dev]** Implement `RepoCardView` with repo name, language badge, star count, last push date, and sparkline of recent activity.
4. **[frontend-dev]** Implement `RepoDetailSheet` as a `.sheet` modifier with full repo stats, language breakdown bar, and recent commits list.
5. **[frontend-dev]** Wire `ReposViewModel` with search filtering and language aggregation across all repos.

### Success Criteria
- [ ] Donut chart shows language distribution with correct colors
- [ ] Search filters repo list by name
- [ ] Repo cards display all required fields
- [ ] Tapping a repo opens the detail sheet
- [ ] Language percentages sum to 100%

---

## Phase 14: Pull Requests View

**Objective**: Build the PRs view with stats row, filter chips, and PR cards.
**Prerequisites**: Phases 2, 5, 10

### Tasks
> **Wireframe**: Read `wireframes/05-pull-request-tracker.svg` before implementing.

1. **[frontend-dev]** Implement `PRsView` with stats row (open/merged/closed counts), time-to-merge card, filter chips (All/Open/Merged/Closed), and scrollable PR card list.
2. **[frontend-dev]** Implement `PRCardView` with status badge (colored per state), title, repo name, +/- line counts, file count, and time-to-merge.
3. **[frontend-dev]** Implement `StatusBadge` reusable component: green for open, purple for merged, orange for closed.
4. **[frontend-dev]** Implement `FilterChip` component with active/inactive states and `.glassEffect()`.
5. **[frontend-dev]** Wire `PRsViewModel` with filter state management and computed metrics (average time-to-merge, trend).

### Success Criteria
- [ ] Stats row shows correct counts for each state
- [ ] Filter chips toggle and filter the PR list
- [ ] PR cards show correct status badges with semantic colors
- [ ] Time-to-merge card shows average and trend arrow
- [ ] All components use Liquid Glass styling

---

## Phase 15: Settings View

**Objective**: Build the Settings panel with profile card, account management, and preferences.
**Prerequisites**: Phases 3, 8, 10

### Tasks
> **Wireframe**: Read `wireframes/06-settings.svg` before implementing.

1. **[frontend-dev]** Implement `SettingsView` with profile card (avatar, username, "Linked" badge), account section (token management, repo selection, refresh interval picker), notification toggles, appearance (accent color picker), about section, and disconnect button.
2. **[frontend-dev]** Implement `ProfileCardView` with async image loading for GitHub avatar.
3. **[frontend-dev]** Implement the disconnect flow: confirmation alert → delete Keychain token → wipe SwiftData → return to onboarding.
4. **[frontend-dev]** Wire `SettingsViewModel` with UserDefaults-backed preferences and Keychain token status.
5. **[test-engineer]** Write tests for disconnect flow (models cleared, token deleted, app state reset).

### Success Criteria
- [ ] Profile card shows correct avatar and username
- [ ] Refresh interval picker saves to UserDefaults
- [ ] Notification toggles control scheduled notifications
- [ ] Disconnect button shows confirmation and fully resets app
- [ ] Settings uses `Form` or grouped list with Liquid Glass sections

---

## Phase 16: macOS Widgets

**Objective**: Build all 5 widget variants with Liquid Glass styling.
**Prerequisites**: Phases 2, 7

### Tasks
> **Wireframe**: Read `wireframes/07-widget-previews.svg` before implementing.

1. **[frontend-dev]** Implement `GitPulseWidgetBundle` registering all 5 widgets.
2. **[frontend-dev]** Implement `GitPulseTimelineProvider` reading from the shared SwiftData container (app group) per ARCHITECTURE.md §4.5.
3. **[frontend-dev]** Implement all 5 widget views: StreakHero (small), TodayStats (small), TopLanguage (small), WeeklyGrid (medium), ActiveRepos (medium).
4. **[frontend-dev]** Apply widget-specific Liquid Glass styling (widgets have limited view support — no `.glassEffect()` modifier in widgets, use manual glass-like gradients).
5. **[test-engineer]** Write tests for `TimelineProvider`: correct entry generation, handles empty data, respects refresh policy.

### Success Criteria
- [ ] All 5 widgets render in the widget gallery
- [ ] Widgets display correct data from the shared container
- [ ] Small widgets fit the `systemSmall` family constraints
- [ ] Medium widgets fit the `systemMedium` family constraints
- [ ] Timeline refreshes at the specified intervals

---

## Phase 17: App Intents (Siri & Shortcuts)

**Objective**: Enable Siri queries and Shortcuts app integration.
**Prerequisites**: Phases 2, 7

### Tasks
1. **[backend-dev]** Implement `GetStreakIntent` and `GetTodayCommitsIntent` per ARCHITECTURE.md §4.6.
2. **[backend-dev]** Implement `AppShortcutsProvider` registering both intents with phrase suggestions.
3. **[test-engineer]** Write tests for intent `perform()` methods: correct values returned, handles empty data gracefully.

### Success Criteria
- [ ] "What's my streak?" returns the correct current streak value
- [ ] "Today's commits" returns the correct commit count
- [ ] Intents appear in the Shortcuts app
- [ ] Intents handle no-data-yet state without crashing

---

## Phase 18: Component Polish & Reusable Library

**Objective**: Extract and polish all reusable UI components into the Components/ directory.
**Prerequisites**: Phases 11–15

### Tasks
1. **[frontend-dev]** Extract and refine `GlassCard`, `StatCard`, `StatusBadge`, `FilterChip`, `SparklineView`, `TrendArrow` as standalone reusable components in `Components/`.
2. **[frontend-dev]** Add `#Preview` macros with mock data for every component.
3. **[frontend-dev]** Ensure all components support `@Environment(\.colorScheme)` (even though we only use dark) and `@Environment(\.accessibilityReduceMotion)`.
4. **[code-reviewer]** Review all components for design-system compliance, accessibility, and API consistency.

### Success Criteria
- [ ] All 6 components are in `Components/` with clean public APIs
- [ ] Each component has at least one `#Preview`
- [ ] Components respect `accessibilityReduceMotion`
- [ ] Code reviewer approves design-system compliance

---

## Phase 19: Animation & Transitions

**Objective**: Add polished animations throughout the app.
**Prerequisites**: Phases 11–15

### Tasks
1. **[frontend-dev]** Add data-load animations: stat cards count up from 0, charts fade in with spring animation.
2. **[frontend-dev]** Add tab transition animations using `matchedGeometryEffect` or `.transition()`.
3. **[frontend-dev]** Add streak ring fill animation on appear (arc draws from 0 to current value).
4. **[frontend-dev]** Add interaction animations: button press scale, card hover highlight, filter chip toggle.
5. **[frontend-dev]** Implement `@Environment(\.accessibilityReduceMotion)` checks — disable all non-essential animation when enabled.

### Success Criteria
- [ ] Dashboard stat cards animate on data load
- [ ] Charts animate in with smooth easing
- [ ] Streak ring draws animated arc
- [ ] All animations respect reduced motion preference
- [ ] No animation jank or dropped frames

---

## Phase 20: Error States & Empty States

**Objective**: Handle every edge case with appropriate UI feedback.
**Prerequisites**: Phases 11–15

### Tasks
1. **[frontend-dev]** Design and implement empty state views for each tab: no data yet (before first sync), no internet, API rate limited, token expired.
2. **[frontend-dev]** Implement inline error banners for sync failures that don't block the UI.
3. **[frontend-dev]** Implement the rate-limit countdown display when approaching the limit.
4. **[frontend-dev]** Add pull-to-refresh (manual refresh button in toolbar) with loading indicator.
5. **[test-engineer]** Write ViewModel tests: each error state is properly surfaced to the view layer.

### Success Criteria
- [ ] Every tab shows a meaningful empty state before first sync
- [ ] Network errors display a dismissible banner, not a blocking alert
- [ ] Rate-limit warning shows when < 100 requests remaining
- [ ] Token expired error prompts re-authentication
- [ ] Manual refresh triggers a full sync cycle

---

## Phase 21: Comprehensive Test Suite

**Objective**: Achieve 80%+ code coverage on new code, 95%+ on critical paths.
**Prerequisites**: All implementation phases

### Tasks
1. **[test-engineer]** Audit existing test coverage using `xcodebuild test` with code coverage report.
2. **[test-engineer]** Fill coverage gaps in Services: ensure all error paths, edge cases, and boundary conditions are tested.
3. **[test-engineer]** Fill coverage gaps in ViewModels: test state transitions, loading states, error propagation.
4. **[test-engineer]** Add integration tests: full sync cycle (mock API → SwiftData → streak recalculation → ViewModel update).
5. **[test-engineer]** Add UI tests for critical flows: onboarding completion, tab navigation, settings disconnect.

### Success Criteria
- [ ] Code coverage report shows 80%+ on new code
- [ ] StreakEngine, GitHubAPIClient, KeychainService at 95%+ coverage
- [ ] All tests pass: `xcodebuild test -scheme GitPulse -destination 'platform=macOS'`
- [ ] No flaky tests (run suite 3 times consecutively)

---

## Phase 22: Performance Optimization

**Objective**: Meet all performance budgets from ARCHITECTURE.md §6.
**Prerequisites**: Phases 11–16, 21

### Tasks
1. **[backend-dev]** Profile app launch time with Instruments. Optimize `ModelContainer` initialization, defer non-essential work.
2. **[backend-dev]** Profile sync duration. Batch SwiftData writes, minimize redundant API calls using `SyncMetadata.lastSyncDate`.
3. **[frontend-dev]** Profile scroll performance. Add `LazyVStack` where needed, optimize chart rendering for large datasets.
4. **[frontend-dev]** Profile widget timeline generation. Ensure shared `ModelContainer` reads are fast.
5. **[code-reviewer]** Validate all performance budgets from ARCHITECTURE.md §6 using Instruments.

### Success Criteria
- [ ] App launch < 1.0s (time to interactive)
- [ ] Sync < 15s wall clock
- [ ] Memory < 150 MB during active use
- [ ] Heatmap renders < 100ms
- [ ] Widget timeline < 2s
- [ ] Smooth 60fps scrolling in all list views

---

## Phase 23: Accessibility Audit

**Objective**: Full VoiceOver support, Dynamic Type, and reduced motion compliance.
**Prerequisites**: Phases 11–15, 18, 19

### Tasks
1. **[frontend-dev]** Add `accessibilityLabel` and `accessibilityValue` to all interactive elements, stat cards, and chart elements.
2. **[frontend-dev]** Test VoiceOver navigation through every view. Ensure logical reading order.
3. **[frontend-dev]** Verify all text scales with Dynamic Type (even though macOS has limited DT support, use relative sizing).
4. **[frontend-dev]** Ensure all color contrasts meet WCAG AA (4.5:1 for text, 3:1 for large text/UI components).
5. **[code-reviewer]** Run Accessibility Inspector on every screen and file issues for anything flagged.

### Success Criteria
- [ ] VoiceOver can navigate every screen without getting stuck
- [ ] All charts have alternative text descriptions for VoiceOver
- [ ] Color contrast meets WCAG AA on all text elements
- [ ] Reduced motion eliminates all non-essential animations
- [ ] No Accessibility Inspector warnings on any screen

---

## Phase 24: Menu Bar Extra (Post-MVP)

**Objective**: Add a persistent menu bar icon with quick stats dropdown.
**Prerequisites**: Phases 7, 11

### Tasks
1. **[frontend-dev]** Implement `NSMenuBarExtra` in `GitPulseApp.swift` scene builder. Show a small GitHub-style icon.
2. **[frontend-dev]** Build the dropdown panel: current streak, today's commits, last sync time, and a "Refresh Now" button.
3. **[frontend-dev]** Apply Liquid Glass styling to the dropdown (`.glassEffect()` on the panel background).
4. **[test-engineer]** Write tests for menu bar data binding (values update after sync).

### Success Criteria
- [ ] Menu bar icon appears when app is running
- [ ] Dropdown shows correct current stats
- [ ] "Refresh Now" triggers a sync
- [ ] Dropdown uses Liquid Glass styling

---

## Phase 25: Keyboard Shortcuts & Final Polish

**Objective**: Add comprehensive keyboard navigation and final UI polish.
**Prerequisites**: Phases 10–15, 24

### Tasks
1. **[frontend-dev]** Implement all keyboard shortcuts: Cmd+1–5 tabs, Cmd+R refresh, Cmd+, settings, Escape to close sheets.
2. **[frontend-dev]** Add window toolbar items: refresh button, sync status indicator, last-synced timestamp.
3. **[frontend-dev]** Final visual polish pass: consistent spacing, alignment audit, glass effect consistency, hover states on all interactive elements.
4. **[code-reviewer]** Full code review of entire codebase against all rules files (code-style, testing, design-system, git-conventions).

### Success Criteria
- [ ] All keyboard shortcuts work from any view
- [ ] Toolbar shows sync status accurately
- [ ] Visual polish approved by code reviewer
- [ ] No outstanding code review issues
- [ ] App feels cohesive and professional

---

## Phase 26: Distribution & Documentation

**Objective**: Prepare the project for local distribution and future development.
**Prerequisites**: All previous phases

### Tasks
1. **[backend-dev]** Configure release build settings: disable debug logging, optimize for speed, set bundle identifier and version.
2. **[backend-dev]** Create a comprehensive `README.md` with setup instructions, screenshots, architecture overview, and contribution guidelines.
3. **[backend-dev]** Add a `.gitignore` covering: DerivedData, xcuserdata, .DS_Store, .env, .claude/settings.local.json, .claude/state/.
4. **[code-reviewer]** Final review: build in Release mode, run full test suite, verify all features work end-to-end.

### Success Criteria
- [ ] Release build succeeds with no warnings
- [ ] Full test suite passes in Release mode
- [ ] README.md contains setup instructions and architecture summary
- [ ] `.gitignore` is comprehensive
- [ ] App is ready for local use and future development
