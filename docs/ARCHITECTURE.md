# GitPulse — Technical Architecture

## 1. Project Philosophy

GitPulse is a personal GitHub activity tracker for macOS, built as a learning vehicle for the Apple development stack. Every architectural decision optimizes for three goals:

1. **Learn Apple frameworks deeply** — Use SwiftUI, SwiftData, Swift Charts, WidgetKit, App Intents, Keychain Services, and BackgroundTasks in anger, not toy examples.
2. **Ship a polished product** — Liquid Glass design language, smooth animations, accessible UI, and reliable background sync make this feel like a first-party Apple app.
3. **Stay free-tier compatible** — No paid Apple Developer Program features (no CloudKit, no push notifications, no TestFlight distribution). Everything runs locally with a GitHub Personal Access Token.

### Design Constraints

- **macOS 26+ only** — Target the latest macOS release. No iOS, no cross-platform.
- **Single-user, local-first** — All data lives in a local SwiftData store. No server, no cloud sync.
- **GitHub REST API v3** — Authenticated via PAT stored in Keychain. 5,000 requests/hour budget.
- **Offline-resilient** — The app must work with stale data when the network is unavailable. Show last-synced timestamps prominently.
- **Dark theme only** — Background #0D0D0F, all surfaces use Liquid Glass effects.

---

## 2. Complete Feature Set

### MVP Features (Phases 1–12)

| Feature | Module | Description |
|---------|--------|-------------|
| PAT onboarding | Onboarding | 4-step guided setup: welcome, token entry with validation, repo selection, completion |
| Secure token storage | KeychainService | Store/retrieve/delete PAT via Keychain Services — never UserDefaults |
| GitHub API client | GitHubAPIClient | Async/await networking layer with rate-limit tracking, pagination, and error handling |
| Contribution heatmap | Dashboard | 16-week grid (RectangleMark) with GitHub's green color scale, tooltip on hover |
| Daily/weekly commit counts | Dashboard | Stat cards showing today's commits, this week's total, and trend arrows |
| Streak tracking | StreakEngine | Current streak, longest streak, active days — all timezone-aware |
| Streak history | Streaks view | Timeline of past streaks with start/end dates and lengths |
| Repository list | Repos view | All user repos with language breakdown, stars, last push date, sparkline |
| Language breakdown | Repos view | Donut chart (SectorMark) of language distribution across all repos |
| Pull request tracker | PRs view | Open/merged/closed counts, list with status badges, line diffs, file counts |
| Time-to-merge metric | PRs view | Average merge time with trend indicator |
| Weekly activity chart | Dashboard | Line chart (LineMark + AreaMark) showing 7-day commit distribution |
| Settings panel | Settings | Profile card, token management, refresh interval, notification toggles, accent color |
| macOS widgets | WidgetKit | Small (streak, today stats, top language) and medium (weekly grid, active repos) |
| Background refresh | BGAppRefreshTask | Periodic sync every 30 min (configurable) when app is not in foreground |
| Local notifications | UNUserNotification | Streak-at-risk alerts, daily summary, milestone celebrations |

### Post-MVP Features (Phases 13+)

| Feature | Module | Description |
|---------|--------|-------------|
| Siri shortcuts | App Intents | "What's my streak?" / "Show today's commits" voice queries |
| Menu bar extra | NSMenuBarExtra | Persistent menu bar icon with quick stats dropdown |
| Repo detail drill-in | Repos view | Per-repo commit history, contributor breakdown, branch activity |
| PR detail sheet | PRs view | Full PR detail with review timeline, comments, CI status |
| Export/share | Export | Generate shareable streak images or CSV data exports |
| Keyboard shortcuts | Key equivalents | Cmd+1–5 tab switching, Cmd+R manual refresh, Cmd+, settings |
| Spotlight integration | CoreSpotlight | Index repos and PRs for system-wide search |
| Accessibility audit | All views | Full VoiceOver support, Dynamic Type, reduced motion, high contrast |

---

## 3. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        GitPulse.app                         │
│                                                             │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │   Views      │  │  ViewModels  │  │     Services      │  │
│  │             │  │  (@Observable)│  │   (protocols)     │  │
│  │ Dashboard   │──│ DashboardVM  │──│ GitHubAPIClient   │  │
│  │ Streaks     │  │ StreaksVM    │  │ KeychainService   │  │
│  │ Repos       │  │ ReposVM      │  │ StreakEngine      │  │
│  │ PRs         │  │ PRsVM        │  │ NotificationSvc   │  │
│  │ Settings    │  │ SettingsVM   │  │ BackgroundSyncSvc │  │
│  │ Onboarding  │  │ OnboardingVM │  │ WidgetDataProvider│  │
│  └─────────────┘  └──────┬───────┘  └────────┬──────────┘  │
│                          │                    │             │
│                   ┌──────┴────────────────────┴──────┐      │
│                   │         SwiftData Layer          │      │
│                   │                                  │      │
│                   │  @Model Contribution             │      │
│                   │  @Model Repository               │      │
│                   │  @Model PullRequest              │      │
│                   │  @Model LanguageStat             │      │
│                   │  @Model UserProfile              │      │
│                   │  @Model SyncMetadata             │      │
│                   └──────────────┬───────────────────┘      │
│                                  │                          │
│                          ModelContainer                     │
│                     (shared with WidgetKit)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │    External Services    │
              │                        │
              │  GitHub REST API v3    │
              │  (PAT auth, 5k/hr)    │
              │                        │
              │  macOS Keychain        │
              │  (SecItem API)         │
              │                        │
              │  UNUserNotification    │
              │  (local only)          │
              └────────────────────────┘
```

### Data Flow: Sync Cycle

```
BGAppRefreshTask fires
        │
        ▼
BackgroundSyncService.performSync()
        │
        ├── GitHubAPIClient.fetchContributions(since: lastSync)
        │       │
        │       ▼
        │   GET /users/{user}/events (paginated)
        │   GET /search/issues?q=author:{user}+type:pr
        │   GET /user/repos (paginated)
        │       │
        │       ▼
        │   Parse JSON → domain models
        │
        ├── SwiftData ModelContext.insert/update
        │       │
        │       ▼
        │   Contribution, Repository, PullRequest, LanguageStat
        │
        ├── StreakEngine.recalculate(from: contributions)
        │       │
        │       ▼
        │   Update UserProfile.currentStreak, .longestStreak, .activeDays
        │
        ├── WidgetCenter.shared.reloadAllTimelines()
        │
        ├── NotificationService.evaluateAlerts(streak:, milestones:)
        │
        └── SyncMetadata.lastSyncDate = .now
```

---

## 4. Domain Deep-Dives

### 4.1 GitHub API Client

**Protocol**:
```swift
protocol GitHubAPIProviding: Sendable {
    func fetchUserProfile() async throws(GitHubError) -> GitHubUser
    func fetchContributions(since: Date) async throws(GitHubError) -> [GitHubEvent]
    func fetchRepositories(page: Int) async throws(GitHubError) -> [GitHubRepo]
    func fetchPullRequests(state: PRState, page: Int) async throws(GitHubError) -> [GitHubPR]
    func validateToken(_ token: String) async throws(GitHubError) -> Bool
}
```

**Error type**:
```swift
enum GitHubError: Error, LocalizedError {
    case unauthorized          // 401 — token invalid or revoked
    case rateLimited(resetAt: Date) // 403 with X-RateLimit-Reset
    case notFound              // 404
    case networkUnavailable    // URLError.notConnectedToInternet
    case serverError(Int)      // 5xx
    case decodingFailed(underlying: Error)
    case unknown(underlying: Error)
}
```

**Rate limit tracking**: Every response updates a `@MainActor` published `RateLimitState`:
```swift
struct RateLimitState: Sendable {
    let limit: Int          // X-RateLimit-Limit (5000)
    let remaining: Int      // X-RateLimit-Remaining
    let resetDate: Date     // X-RateLimit-Reset (Unix epoch)
}
```

If `remaining < 100`, the sync service pauses non-essential requests until `resetDate`.

**Pagination**: GitHub paginates with `Link` header. The client parses the `rel="next"` URL and fetches pages sequentially until exhausted or a configurable max page limit (default 10) is reached.

**Key endpoints**:

| Endpoint | Method | Purpose | Pagination |
|----------|--------|---------|------------|
| `/user` | GET | Validate token, get username/avatar | No |
| `/users/{user}/events` | GET | Commit events, PR events, push events | Yes (10 pages max) |
| `/user/repos` | GET | All repos for authenticated user | Yes (all pages) |
| `/search/issues?q=author:{user}+type:pr` | GET | Pull requests across all repos | Yes (10 pages max) |
| `/repos/{owner}/{repo}/languages` | GET | Language byte counts per repo | No |

### 4.2 SwiftData Layer

**ModelContainer configuration**:
```swift
let schema = Schema([
    Contribution.self,
    Repository.self,
    PullRequest.self,
    LanguageStat.self,
    UserProfile.self,
    SyncMetadata.self
])

let config = ModelConfiguration(
    "GitPulse",
    schema: schema,
    isStoredInMemoryOnly: false,
    groupContainer: .identifier("group.com.gitpulse.shared") // shared with widgets
)
```

The `groupContainer` uses an app group so WidgetKit extensions can read the same SwiftData store. Note: App groups work without a paid developer account for local development.

**Migration strategy**: Use `VersionedSchema` from day one. Even v1 should be declared as `SchemaV1` so future migrations have a clean base:
```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Contribution.self, Repository.self, PullRequest.self, ...]
    }
}
```

**Thread safety**: All SwiftData writes from background sync use a `ModelActor`:
```swift
@ModelActor
actor BackgroundDataWriter {
    func importContributions(_ events: [GitHubEvent]) throws { ... }
    func importRepositories(_ repos: [GitHubRepo]) throws { ... }
    func importPullRequests(_ prs: [GitHubPR]) throws { ... }
}
```

Views use `@Query` for reads, which is automatically main-actor-isolated.

### 4.3 Streak Calculation Engine

**Core algorithm**:
```
Input: sorted array of Contribution dates (UTC)
Output: currentStreak, longestStreak, activeDays, streakHistory

1. Convert each UTC date to user's local calendar day
2. Deduplicate to unique days
3. Walk backwards from today:
   - If today has contributions, currentStreak starts at 1
   - If today has none but yesterday does, currentStreak starts at 0 (grace: streak still alive until midnight)
   - Each consecutive previous day with contributions increments currentStreak
   - First gap breaks the streak
4. Walk entire history forward to find longestStreak and build streakHistory array
5. activeDays = count of unique contributing days
```

**Timezone handling**: This is the trickiest part. GitHub events have UTC timestamps. A commit at 11:30 PM ET on Monday is Tuesday UTC. The streak engine must:
- Accept the user's `TimeZone` (default: `.autoupdatingCurrent`)
- Convert all event timestamps to the user's local `Calendar.DateComponents`
- Compare days using `Calendar.isDate(_:inSameDayAs:)` with the user's calendar

**Edge cases**:
- User changes timezone mid-streak (traveling) — recalculate from raw events
- Multiple commits same day count as 1 active day
- The "today" boundary shifts at local midnight, not UTC midnight
- Empty contribution history: all values are 0, streakHistory is empty

### 4.4 Contribution Heatmap

A 16-week (112-day) grid displayed as a Swift Charts `RectangleMark` visualization.

**Data structure**:
```swift
struct HeatmapCell: Identifiable {
    let id: Date         // the calendar day
    let weekIndex: Int   // 0–15 (column)
    let dayOfWeek: Int   // 0–6 (row, Sunday=0)
    let count: Int       // contribution count
    let level: Int       // 0–4 intensity bucket
}
```

**Intensity buckets** (GitHub's scale):
| Level | Count Range | Color |
|-------|-------------|-------|
| 0 | 0 | #161B22 (empty) |
| 1 | 1–3 | #0E4429 |
| 2 | 4–7 | #006D32 |
| 3 | 8–12 | #26A641 |
| 4 | 13+ | #39D353 |

The thresholds should be dynamic based on the user's activity level. Calculate the 25th, 50th, 75th percentile of non-zero days and use those as boundaries.

**Chart implementation**: Use `Chart` with `RectangleMark` for each cell:
```swift
Chart(cells) { cell in
    RectangleMark(
        xStart: .value("Week", cell.weekIndex),
        xEnd: .value("Week", cell.weekIndex + 1),
        yStart: .value("Day", cell.dayOfWeek),
        yEnd: .value("Day", cell.dayOfWeek + 1)
    )
    .foregroundStyle(heatmapColor(for: cell.level))
    .cornerRadius(2)
}
```

### 4.5 Widget Timeline Provider

**Widget families**: `.systemSmall` and `.systemMedium` only (macOS).

**Timeline strategy**:
```swift
struct GitPulseTimelineProvider: TimelineProvider {
    func getTimeline(in context: Context, completion: @escaping (Timeline<GitPulseEntry>) -> Void) {
        // 1. Read from shared SwiftData container (app group)
        // 2. Build entry with current stats
        // 3. Set next reload to 30 minutes from now
        let entry = GitPulseEntry(date: .now, streak: streak, todayCommits: count, ...)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800)))
        completion(timeline)
    }
}
```

**Widget variants** (5 total):

| Family | Variant | Content |
|--------|---------|---------|
| Small | Streak Hero | Large streak number, ring progress, "days" label |
| Small | Today Stats | 2x2 grid: commits, PRs, streak, repos |
| Small | Top Language | Language name, percentage, color swatch |
| Medium | Weekly Grid | 7-day contribution cells + week summary stats |
| Medium | Active Repos | Top 3 repos with last commit time and sparkline |

**Important**: Widget views cannot use `@Observable` or `@Query`. Read data via `ModelContext` in the `TimelineProvider` and pass it as plain values in the `TimelineEntry` struct.

### 4.6 App Intents (Siri / Shortcuts)

```swift
struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Get My Streak"
    static var description: IntentDescription = "Returns your current GitHub contribution streak"

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let streak = // read from SwiftData
        return .result(value: streak, dialog: "Your current streak is \(streak) days")
    }
}

struct GetTodayCommitsIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Commits"
    static var description: IntentDescription = "Returns how many commits you've made today"

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let count = // read from SwiftData
        return .result(value: count, dialog: "You've made \(count) commits today")
    }
}
```

Register via `AppShortcutsProvider` for automatic Siri phrase suggestions.

### 4.7 Keychain Wrapper

```swift
protocol KeychainProviding: Sendable {
    func save(token: String, for account: String) throws(KeychainError)
    func retrieve(for account: String) throws(KeychainError) -> String?
    func delete(for account: String) throws(KeychainError)
}
```

Uses `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, `SecItemDelete`. The service name is `"com.gitpulse.github-token"`, the account key is the GitHub username.

**Security rules**:
- Never log or print the token value
- Never store in UserDefaults, environment variables, or plist files
- Wipe from memory after use (Swift doesn't guarantee this, but minimize retention)
- On "Disconnect" in settings, delete the Keychain item and wipe all SwiftData models

### 4.8 Background Sync Service

```swift
actor BackgroundSyncService {
    private let apiClient: GitHubAPIProviding
    private let dataWriter: BackgroundDataWriter
    private let streakEngine: StreakEngine

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.gitpulse.refresh",
            using: nil
        ) { task in
            self.handleRefresh(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.gitpulse.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1800) // 30 min
        try? BGTaskScheduler.shared.submit(request)
    }

    func handleRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = { task.setTaskCompleted(success: false) }

        Task {
            do {
                try await performSync()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
            scheduleRefresh() // schedule next
        }
    }
}
```

### 4.9 Notification Service

```swift
enum GitPulseNotification {
    case streakAtRisk(currentStreak: Int, hoursRemaining: Int)
    case dailySummary(commits: Int, prs: Int)
    case milestone(type: MilestoneType, value: Int)
    case streakBroken(wasLength: Int)
}

enum MilestoneType {
    case streak(days: Int)          // 7, 30, 50, 100, 365
    case totalCommits(count: Int)   // 100, 500, 1000, 5000
    case totalPRsMerged(count: Int) // 10, 50, 100
}
```

Notifications are scheduled locally. The "streak at risk" alert fires at 9 PM local time if no contributions have been recorded that day. This time is configurable in settings.

---

## 5. Data Models

### 5.1 SwiftData @Model Definitions

```swift
@Model
final class Contribution {
    @Attribute(.unique) var id: String      // GitHub event ID
    var type: ContributionType              // push, pullRequest, review, issue
    var date: Date                          // event timestamp (UTC)
    var repositoryName: String
    var repositoryOwner: String
    var message: String?                    // commit message or PR title
    var additions: Int
    var deletions: Int
    var commitCount: Int                    // for push events, number of commits

    enum ContributionType: String, Codable {
        case push, pullRequest, pullRequestReview, issue, create, fork
    }
}

@Model
final class Repository {
    @Attribute(.unique) var id: Int         // GitHub repo ID
    var name: String
    var fullName: String                    // owner/name
    var descriptionText: String?
    var language: String?
    var starCount: Int
    var forkCount: Int
    var isPrivate: Bool
    var lastPushDate: Date?
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var languages: [LanguageStat]
}

@Model
final class LanguageStat {
    var name: String
    var bytes: Int
    var color: String                       // hex color from GitHub
    @Relationship(inverse: \Repository.languages) var repository: Repository?
}

@Model
final class PullRequest {
    @Attribute(.unique) var id: Int         // GitHub PR ID
    var number: Int
    var title: String
    var state: PRState                      // open, merged, closed
    var repositoryFullName: String
    var createdAt: Date
    var mergedAt: Date?
    var closedAt: Date?
    var additions: Int
    var deletions: Int
    var changedFiles: Int
    var isDraft: Bool

    enum PRState: String, Codable {
        case open, merged, closed
    }

    var timeToMerge: TimeInterval? {
        guard let mergedAt else { return nil }
        return mergedAt.timeIntervalSince(createdAt)
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var username: String
    var avatarURL: String
    var displayName: String?
    var bio: String?
    var publicRepoCount: Int
    var followerCount: Int
    var currentStreak: Int
    var longestStreak: Int
    var activeDays: Int
    var totalContributions: Int
    var lastSyncDate: Date?
}

@Model
final class SyncMetadata {
    @Attribute(.unique) var key: String     // "lastSync"
    var date: Date
    var eventsProcessed: Int
    var rateLimitRemaining: Int
    var rateLimitReset: Date
}
```

### 5.2 Non-Persisted Domain Types

```swift
struct StreakInfo: Sendable {
    let current: Int
    let longest: Int
    let activeDays: Int
    let history: [StreakPeriod]
    let isActiveToday: Bool
}

struct StreakPeriod: Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    var length: Int { Calendar.current.dateComponents([.day], from: startDate, to: endDate).day! + 1 }
}

struct WeeklyActivity: Identifiable, Sendable {
    let id: Date          // start of week
    let days: [DayActivity]
    var total: Int { days.reduce(0) { $0 + $1.count } }
}

struct DayActivity: Identifiable, Sendable {
    let id: Date          // the day
    let dayName: String   // "Mon", "Tue", etc.
    let count: Int
}

struct LanguageBreakdown: Identifiable, Sendable {
    let id: String        // language name
    let name: String
    let percentage: Double
    let color: Color
    let bytes: Int
}
```

---

## 6. Performance Budgets

| Metric | Target | Measurement |
|--------|--------|-------------|
| App launch to interactive | < 1.0s | Time to first meaningful paint of Dashboard |
| Background sync duration | < 15s | Wall clock for full sync cycle |
| API calls per sync | < 30 | Total HTTP requests across all endpoints |
| SwiftData write batch | < 500ms | Time to persist a full sync's worth of models |
| Widget timeline generation | < 2s | TimelineProvider.getTimeline completion |
| Heatmap render | < 100ms | Chart body evaluation for 112 cells |
| Memory ceiling (idle) | < 80 MB | Instruments allocation tracker |
| Memory ceiling (active) | < 150 MB | During sync + UI interaction |
| SwiftData store size | < 50 MB | After 1 year of daily use |
| Scroll frame rate | 60 fps | Consistent in all list views |

---

## 7. Reference Tables

### 7.1 GitHub Event Types Tracked

| Event Type | API Field | Maps To |
|------------|-----------|---------|
| PushEvent | `type: "PushEvent"` | Contribution (push) |
| PullRequestEvent | `type: "PullRequestEvent"` | Contribution (pullRequest) + PullRequest model |
| PullRequestReviewEvent | `type: "PullRequestReviewEvent"` | Contribution (pullRequestReview) |
| IssuesEvent | `type: "IssuesEvent"` | Contribution (issue) |
| CreateEvent | `type: "CreateEvent"` | Contribution (create) — repo/branch/tag creation |
| ForkEvent | `type: "ForkEvent"` | Contribution (fork) |

### 7.2 Accent Color Palette

| Name | Hex | Usage |
|------|-----|-------|
| GitHub Green | #39D353 | Contributions, streaks, positive metrics |
| Link Blue | #58A6FF | URLs, interactive elements, PR open state |
| Purple | #BC8CFF | PR merged state, language accents |
| Orange | #F78166 | PR closed state, warnings, streak-at-risk |
| Gold | #FFD700 | Milestones, achievements, star counts |
| Glass Surface | rgba(255,255,255,0.06) | Default glass card fill |
| Glass Border | rgba(255,255,255,0.1) | Glass card stroke |
| Text Primary | rgba(255,255,255,0.92) | Headings, primary labels |
| Text Secondary | rgba(255,255,255,0.55) | Captions, timestamps |
| Background | #0D0D0F | App background, behind all glass |

### 7.3 Supported Widget Configurations

| Widget ID | Family | Content | Refresh |
|-----------|--------|---------|---------|
| streak-hero | systemSmall | Streak count + ring | 30 min |
| today-stats | systemSmall | 2x2 stat grid | 30 min |
| top-language | systemSmall | Primary language + % | 6 hours |
| weekly-grid | systemMedium | 7-day heatmap + stats | 30 min |
| active-repos | systemMedium | Top 3 repos list | 1 hour |

### 7.4 Keychain Configuration

| Field | Value |
|-------|-------|
| Service | `com.gitpulse.github-token` |
| Account | GitHub username |
| Access | `kSecAttrAccessibleWhenUnlocked` |
| Sync | `kSecAttrSynchronizableNo` (local only) |

### 7.5 Background Task Configuration

| Field | Value |
|-------|-------|
| Task Identifier | `com.gitpulse.refresh` |
| Minimum Interval | 1800 seconds (30 min) |
| Requires Network | Yes |
| Requires Power | No |
| Info.plist Key | `BGTaskSchedulerPermittedIdentifiers` |

### 7.6 Notification Identifiers

| Identifier | Trigger | Default Time |
|------------|---------|--------------|
| `streak-at-risk` | No contributions today | 9:00 PM local |
| `daily-summary` | End of day | 10:00 PM local |
| `milestone-reached` | Streak/commit milestone hit | Immediate |
| `streak-broken` | Midnight with no contributions | 12:05 AM local |

### 7.7 Project Directory Structure

```
GitPulse/
├── App/
│   ├── GitPulseApp.swift           # @main, ModelContainer setup, scene
│   └── AppState.swift              # Global app state (auth, sync status)
├── Models/
│   ├── Contribution.swift
│   ├── Repository.swift
│   ├── PullRequest.swift
│   ├── LanguageStat.swift
│   ├── UserProfile.swift
│   ├── SyncMetadata.swift
│   └── Schema/
│       └── SchemaV1.swift
├── Services/
│   ├── GitHubAPIClient.swift
│   ├── KeychainService.swift
│   ├── StreakEngine.swift
│   ├── BackgroundSyncService.swift
│   ├── NotificationService.swift
│   └── WidgetDataProvider.swift
├── ViewModels/
│   ├── DashboardViewModel.swift
│   ├── StreaksViewModel.swift
│   ├── ReposViewModel.swift
│   ├── PRsViewModel.swift
│   ├── SettingsViewModel.swift
│   └── OnboardingViewModel.swift
├── Views/
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── ContributionHeatmap.swift
│   │   ├── WeeklyActivityChart.swift
│   │   ├── StatCardView.swift
│   │   └── RecentActivityFeed.swift
│   ├── Streaks/
│   │   ├── StreaksView.swift
│   │   ├── StreakRingView.swift
│   │   ├── WeekBarChart.swift
│   │   └── StreakHistoryTimeline.swift
│   ├── Repos/
│   │   ├── ReposView.swift
│   │   ├── LanguageDonutChart.swift
│   │   ├── RepoCardView.swift
│   │   └── RepoDetailSheet.swift
│   ├── PRs/
│   │   ├── PRsView.swift
│   │   ├── PRCardView.swift
│   │   └── PRStatsRow.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── ProfileCardView.swift
│   └── Onboarding/
│       ├── OnboardingFlow.swift
│       ├── WelcomeStep.swift
│       ├── TokenSetupStep.swift
│       ├── RepoSelectionStep.swift
│       └── CompletionStep.swift
├── Components/
│   ├── GlassCard.swift
│   ├── StatCard.swift
│   ├── StatusBadge.swift
│   ├── FilterChip.swift
│   ├── SparklineView.swift
│   └── TrendArrow.swift
├── Intents/
│   ├── GetStreakIntent.swift
│   ├── GetTodayCommitsIntent.swift
│   └── AppShortcuts.swift
├── Extensions/
│   ├── Date+Extensions.swift
│   ├── Color+Extensions.swift
│   └── View+GlassEffect.swift
├── Resources/
│   └── Assets.xcassets
└── Info.plist

GitPulseWidget/
├── GitPulseWidgetBundle.swift
├── StreakHeroWidget.swift
├── TodayStatsWidget.swift
├── TopLanguageWidget.swift
├── WeeklyGridWidget.swift
├── ActiveReposWidget.swift
├── WidgetEntry.swift
└── SharedViews/
    ├── WidgetGlassCard.swift
    └── WidgetStatView.swift

GitPulseTests/
├── Services/
│   ├── GitHubAPIClientTests.swift
│   ├── StreakEngineTests.swift
│   ├── KeychainServiceTests.swift
│   └── BackgroundSyncTests.swift
├── ViewModels/
│   ├── DashboardViewModelTests.swift
│   └── StreaksViewModelTests.swift
├── Models/
│   └── ModelMigrationTests.swift
├── Fixtures/
│   ├── MockGitHubEvents.json
│   ├── MockRepositories.json
│   └── MockPullRequests.json
└── Mocks/
    ├── MockGitHubAPIClient.swift
    ├── MockKeychainService.swift
    └── MockModelContainer.swift

GitPulseUITests/
├── OnboardingUITests.swift
├── DashboardUITests.swift
└── NavigationUITests.swift
```
