# GitPulse — Liquid Glass Design System

This document is the single source of truth for all visual design decisions. Every SwiftUI view must conform to these specifications. Subagents reference this document via the `design-system` rule.

---

## 1. Color System

### 1.1 Base Palette

GitPulse uses a **dark-only** theme. There is no light mode.

| Token | Hex / Value | Usage |
|-------|-------------|-------|
| `background` | `#0D0D0F` | App background behind all glass surfaces |
| `glassFill` | `Color.white.opacity(0.06)` | Default glass card background |
| `glassBorder` | `Color.white.opacity(0.10)` | Glass card stroke / divider |
| `glassHighlight` | `Color.white.opacity(0.15)` | Hover state, elevated glass |
| `textPrimary` | `Color.white.opacity(0.92)` | Headings, primary labels, values |
| `textSecondary` | `Color.white.opacity(0.55)` | Captions, timestamps, subtitles |
| `textTertiary` | `Color.white.opacity(0.35)` | Disabled text, hints |

### 1.2 Accent Colors

Each accent color has a semantic meaning. Never use an accent color for a purpose other than its assigned meaning.

| Token | Hex | Semantic Usage |
|-------|-----|----------------|
| `accentGreen` | `#39D353` | Contributions, streaks, positive metrics, active states |
| `accentBlue` | `#58A6FF` | Links, interactive elements, PR open state, navigation highlights |
| `accentPurple` | `#BC8CFF` | PR merged state, language accent (secondary) |
| `accentOrange` | `#F78166` | PR closed state, warnings, streak-at-risk |
| `accentGold` | `#FFD700` | Milestones, achievements, star counts |

### 1.3 Heatmap Color Scale

| Level | Hex | Contribution Count |
|-------|-----|--------------------|
| 0 | `#161B22` | No contributions |
| 1 | `#0E4429` | Low (1–3) |
| 2 | `#006D32` | Medium (4–7) |
| 3 | `#26A641` | High (8–12) |
| 4 | `#39D353` | Very high (13+) |

Thresholds are dynamic — recalculated from the user's own activity percentiles (see ARCHITECTURE.md §4.4).

### 1.4 Chart Colors

For multi-series charts and language breakdowns, use the accent colors in this priority order:
1. `#39D353` (green)
2. `#58A6FF` (blue)
3. `#BC8CFF` (purple)
4. `#F78166` (orange)
5. `#FFD700` (gold)

For language-specific colors, use the official GitHub language colors (available via the `/repos/{owner}/{repo}/languages` API and `github/linguist` repository).

### 1.5 Swift Color Definitions

```swift
extension Color {
    // Base
    static let gpBackground = Color(hex: "0D0D0F")
    static let gpGlassFill = Color.white.opacity(0.06)
    static let gpGlassBorder = Color.white.opacity(0.10)
    static let gpGlassHighlight = Color.white.opacity(0.15)

    // Text
    static let gpTextPrimary = Color.white.opacity(0.92)
    static let gpTextSecondary = Color.white.opacity(0.55)
    static let gpTextTertiary = Color.white.opacity(0.35)

    // Accents
    static let gpGreen = Color(hex: "39D353")
    static let gpBlue = Color(hex: "58A6FF")
    static let gpPurple = Color(hex: "BC8CFF")
    static let gpOrange = Color(hex: "F78166")
    static let gpGold = Color(hex: "FFD700")

    // Heatmap
    static let heatmap0 = Color(hex: "161B22")
    static let heatmap1 = Color(hex: "0E4429")
    static let heatmap2 = Color(hex: "006D32")
    static let heatmap3 = Color(hex: "26A641")
    static let heatmap4 = Color(hex: "39D353")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

---

## 2. Typography

GitPulse uses the SF Pro family exclusively, which is the system font on macOS. Never specify a custom font.

### 2.1 Type Scale

| Role | Font | Size | Weight | Line Height | Usage |
|------|------|------|--------|-------------|-------|
| Hero Number | SF Pro Display | 48pt | Bold | 1.0 | Streak count in ring, large dashboard metrics |
| Page Title | SF Pro Display | 34pt | Bold | 1.1 | "Dashboard", "Streaks", view titles |
| Section Header | SF Pro Display | 22pt | Semibold | 1.2 | Card group titles, "This Week", "Recent Activity" |
| Card Title | SF Pro Text | 17pt | Semibold | 1.3 | Stat card labels, repo names, PR titles |
| Body | SF Pro Text | 15pt | Regular | 1.4 | Descriptions, activity feed text, form labels |
| Caption | SF Pro Text | 13pt | Regular | 1.3 | Timestamps, secondary metadata, badge labels |
| Micro | SF Pro Text | 11pt | Medium | 1.2 | Chart axis labels, heatmap day labels, widget small text |
| Code | SF Mono | 13pt | Regular | 1.4 | Commit hashes, branch names, code snippets |

### 2.2 SwiftUI Font Mappings

```swift
extension Font {
    static let gpHeroNumber = Font.system(size: 48, weight: .bold, design: .default)
    static let gpPageTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let gpSectionHeader = Font.system(size: 22, weight: .semibold, design: .default)
    static let gpCardTitle = Font.system(size: 17, weight: .semibold, design: .default)
    static let gpBody = Font.system(size: 15, weight: .regular, design: .default)
    static let gpCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let gpMicro = Font.system(size: 11, weight: .medium, design: .default)
    static let gpCode = Font.system(size: 13, weight: .regular, design: .monospaced)
}
```

### 2.3 Typography Rules

- Headings use `textPrimary` color
- Body text uses `textPrimary` color
- Captions and timestamps use `textSecondary` color
- Disabled or hint text uses `textTertiary` color
- Numeric values in stat cards use `gpHeroNumber` or `gpSectionHeader` depending on card size
- Units and labels are always smaller and lighter than the value they describe

---

## 3. Spacing & Layout

### 3.1 Spacing Scale

All spacing is based on a 4pt grid. Use only these values:

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 4pt | Inline icon-to-text gap, tight grouping |
| `xs` | 8pt | Between related elements (label and value), chip internal padding |
| `sm` | 12pt | Between cards in a grid, section internal padding |
| `md` | 16pt | Screen edge padding, between unrelated elements |
| `lg` | 20pt | Between major sections |
| `xl` | 24pt | Page top/bottom padding |
| `xxl` | 32pt | Between view regions (e.g., header to content) |

### 3.2 Corner Radius Scale

| Token | Value | Usage |
|-------|-------|-------|
| `radiusCard` | 20pt | Glass cards, main content panels |
| `radiusStat` | 18pt | Stat cards, smaller content cards |
| `radiusButton` | 16pt | Buttons, input fields |
| `radiusBadge` | .infinity (pill) | Status badges, filter chips, tags |
| `radiusHeatmap` | 3pt | Heatmap cells |
| `radiusMini` | 8pt | Small UI elements, tooltips |

### 3.3 Layout Constants

```swift
enum DesignTokens {
    // Spacing
    static let spacingXXS: CGFloat = 4
    static let spacingXS: CGFloat = 8
    static let spacingSM: CGFloat = 12
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 20
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // Radius
    static let radiusCard: CGFloat = 20
    static let radiusStat: CGFloat = 18
    static let radiusButton: CGFloat = 16
    static let radiusBadge: CGFloat = .infinity
    static let radiusHeatmap: CGFloat = 3
    static let radiusMini: CGFloat = 8

    // Sizes
    static let sidebarWidth: CGFloat = 220
    static let minWindowWidth: CGFloat = 900
    static let minWindowHeight: CGFloat = 600
    static let statCardHeight: CGFloat = 90
    static let repoCardHeight: CGFloat = 80
    static let prCardHeight: CGFloat = 72
    static let heatmapCellSize: CGFloat = 14
    static let heatmapCellGap: CGFloat = 3
    static let streakRingSize: CGFloat = 200
    static let streakRingLineWidth: CGFloat = 12
    static let widgetSmallSize: CGFloat = 170
    static let widgetMediumWidth: CGFloat = 364
    static let widgetMediumHeight: CGFloat = 170
}
```

---

## 4. Liquid Glass

### 4.1 Core Principles

Apple's Liquid Glass design language (macOS 26+) creates depth through translucent, softly blurred surfaces. GitPulse uses glass everywhere as its primary visual identity.

Rules:
- The app background is always solid `#0D0D0F`. Glass floats above it.
- Glass surfaces use `.glassEffect()` modifier — never manually recreate glass with blur + opacity.
- Use `GlassEffectContainer` to wrap related glass elements that should share a single glass backdrop.
- Use `.glassEffect(.interactive)` for buttons and tappable elements so they respond to interaction.
- Glass surfaces should not be nested more than 2 levels deep.
- Do not put glass on top of glass on top of glass — it becomes visually muddy.

### 4.2 Glass Card Component

The `GlassCard` is the foundational container for all content panels:

```swift
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(DesignTokens.spacingMD)
            .glassEffect()
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusCard))
    }
}
```

### 4.3 Glass Variants

| Variant | Modifier | Usage |
|---------|----------|-------|
| Standard | `.glassEffect()` | Default cards, panels, sections |
| Interactive | `.glassEffect(.interactive)` | Buttons, tappable cards, filter chips |
| Tinted (green) | `.glassEffect()` with green overlay at 0.08 opacity | Streak cards, positive metrics |
| Tinted (alert) | `.glassEffect()` with orange overlay at 0.08 opacity | Warning cards, streak-at-risk |

### 4.4 Glass Container Usage

Wrap groups of related glass elements in `GlassEffectContainer`:

```swift
GlassEffectContainer {
    VStack(spacing: DesignTokens.spacingSM) {
        StatCard(title: "Today", value: "12")
        StatCard(title: "This Week", value: "64")
        StatCard(title: "PRs Open", value: "3")
    }
}
```

### 4.5 Widget Glass Workaround

WidgetKit does not support `.glassEffect()` in widget views. For widgets, approximate the glass look with:

```swift
RoundedRectangle(cornerRadius: DesignTokens.radiusStat)
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.radiusStat)
            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
    )
```

---

## 5. Component Specifications

### 5.1 Stat Card

Displays a single metric with a label.

| Property | Value |
|----------|-------|
| Height | 90pt |
| Padding | 16pt all sides |
| Corner radius | 18pt |
| Value font | gpSectionHeader (22pt semibold) |
| Label font | gpCaption (13pt regular) |
| Value color | textPrimary |
| Label color | textSecondary |
| Glass | `.glassEffect()` |

Layout: Value on top (left-aligned), label below. Optional trend arrow (TrendArrow component) right-aligned.

### 5.2 Repo Card

Displays a repository summary in a list.

| Property | Value |
|----------|-------|
| Height | 80pt |
| Padding | 16pt horizontal, 12pt vertical |
| Corner radius | 18pt |
| Repo name font | gpCardTitle (17pt semibold) |
| Metadata font | gpCaption (13pt regular) |
| Glass | `.glassEffect()` |

Layout: HStack with VStack (name + metadata) on the left, sparkline on the right. Language badge as colored dot + name inline with metadata.

### 5.3 PR Card

Displays a pull request summary.

| Property | Value |
|----------|-------|
| Height | 72pt |
| Padding | 16pt horizontal, 10pt vertical |
| Corner radius | 18pt |
| Title font | gpCardTitle (17pt semibold) |
| Metadata font | gpCaption (13pt regular) |
| Glass | `.glassEffect()` |

Layout: HStack with StatusBadge on the left, VStack (title + repo + metadata) center, +/- counts on the right.

### 5.4 Status Badge

Pill-shaped badge for PR state.

| State | Background | Text Color | Text |
|-------|-----------|------------|------|
| Open | `gpGreen.opacity(0.15)` | `gpGreen` | "Open" |
| Merged | `gpPurple.opacity(0.15)` | `gpPurple` | "Merged" |
| Closed | `gpOrange.opacity(0.15)` | `gpOrange` | "Closed" |

Font: gpCaption (13pt regular). Corner radius: pill (`.infinity`). Horizontal padding: 10pt. Vertical padding: 4pt.

### 5.5 Filter Chip

Toggleable pill for filtering lists.

| State | Background | Text Color | Border |
|-------|-----------|------------|--------|
| Active | `gpBlue.opacity(0.2)` | `gpBlue` | `gpBlue.opacity(0.4)` |
| Inactive | `.glassEffect(.interactive)` | `textSecondary` | none |

Font: gpCaption (13pt medium). Corner radius: pill. Horizontal padding: 14pt. Vertical padding: 6pt.

### 5.6 Primary Button (CTA)

Green gradient button for primary actions.

| Property | Value |
|----------|-------|
| Height | 48pt |
| Corner radius | 16pt |
| Background | Linear gradient from `gpGreen` to `gpGreen.opacity(0.8)` |
| Text color | `.black` (for contrast on green) |
| Font | gpCardTitle (17pt semibold) |
| Press effect | Scale to 0.97, opacity to 0.9 |

### 5.7 Secondary Button

Glass-styled button for secondary actions.

| Property | Value |
|----------|-------|
| Height | 40pt |
| Corner radius | 16pt |
| Background | `.glassEffect(.interactive)` |
| Text color | `textPrimary` |
| Font | gpBody (15pt regular) |

### 5.8 Destructive Button

For disconnect, delete, and other destructive actions.

| Property | Value |
|----------|-------|
| Height | 40pt |
| Corner radius | 16pt |
| Background | `gpOrange.opacity(0.15)` |
| Text color | `gpOrange` |
| Font | gpBody (15pt regular) |
| Border | `gpOrange.opacity(0.3)` 1pt stroke |

### 5.9 Trend Arrow

Small directional indicator for metric trends.

| Direction | Symbol | Color |
|-----------|--------|-------|
| Up (positive) | `arrow.up.right` | `gpGreen` |
| Down (negative) | `arrow.down.right` | `gpOrange` |
| Flat | `arrow.right` | `textSecondary` |

Size: 12pt. Accompanied by a percentage or delta value in gpCaption font.

### 5.10 Sparkline

Miniature line chart for repo activity.

| Property | Value |
|----------|-------|
| Width | 60pt |
| Height | 24pt |
| Stroke width | 1.5pt |
| Color | `gpGreen` (or repo's primary language color) |
| Data points | Last 14 days of commits |

Uses a simple SwiftUI `Path` or Swift Charts `LineMark` with all chrome removed.

---

## 6. Animation

### 6.1 Timing Defaults

| Type | Duration | Easing |
|------|----------|--------|
| State transition | 0.25s | `.easeInOut` |
| Data load | 0.4s | `.spring(response: 0.5, dampingFraction: 0.8)` |
| Chart draw | 0.6s | `.easeOut` |
| Streak ring fill | 0.8s | `.spring(response: 0.8, dampingFraction: 0.7)` |
| Tab transition | 0.2s | `.easeInOut` |
| Press feedback | 0.1s | `.easeOut` |
| Hover highlight | 0.15s | `.easeInOut` |

### 6.2 Animation Patterns

**Count-up**: Stat card values animate from 0 to final value using a timer or `withAnimation`. Duration: 0.4s.

**Fade + slide**: New content slides in from the bottom by 8pt with opacity from 0→1. Duration: 0.3s with 0.05s stagger between items.

**Ring draw**: Streak ring arc animates `trim(from:to:)` from 0 to the target fraction. Duration: 0.8s.

**Chart reveal**: Chart marks fade in with a slight y-offset. Stagger each data point by 0.02s.

### 6.3 Reduced Motion

When `@Environment(\.accessibilityReduceMotion)` is `true`:
- Replace all animations with instant state changes (`.animation(.none)`)
- Disable count-up animations — show final value immediately
- Disable chart draw animations — render in final state
- Keep opacity transitions but remove positional movement

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

private var animation: Animation? {
    reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.8)
}
```

---

## 7. Accessibility

### 7.1 Color Contrast Requirements

All text must meet WCAG AA contrast ratios against the glass surface composite (glass on `#0D0D0F`):

| Element | Minimum Ratio | Our Ratio |
|---------|--------------|-----------|
| Body text (textPrimary on background) | 4.5:1 | ~18:1 |
| Caption text (textSecondary on background) | 4.5:1 | ~8.5:1 |
| Large headings (textPrimary on background) | 3:1 | ~18:1 |
| Accent on background (gpGreen on #0D0D0F) | 3:1 | ~5.2:1 |
| Badge text (gpGreen on green-tinted glass) | 4.5:1 | ~7:1 |

### 7.2 Focus Indicators

All interactive elements must show a visible focus ring when navigated via keyboard:

```swift
.focusable()
.onKeyPress(.space) { /* activate */ }
// SwiftUI provides default focus rings on macOS
```

Ensure focus order follows the visual layout: sidebar → main content top to bottom.

### 7.3 VoiceOver

Every view must be navigable by VoiceOver:
- Stat cards: `accessibilityLabel("Commits today: 12")` — combine label and value
- Charts: `accessibilityLabel("Contribution heatmap showing 16 weeks of activity. Most active day: Tuesday with 8 contributions.")`
- Badges: `accessibilityLabel("Status: Merged")`
- Trend arrows: `accessibilityLabel("Trending up, plus 15 percent")`
- Interactive elements: `accessibilityHint("Double-tap to view repository details")`

Group related elements with `accessibilityElement(children: .combine)` to avoid chatty navigation.

### 7.4 Dynamic Type

While macOS has limited Dynamic Type support compared to iOS, use relative font sizing:
- Never hardcode font sizes in `frame(height:)` — use `.fixedSize()` or flexible frames
- Ensure labels can wrap to multiple lines if needed
- Test at the largest system text size in System Settings → Accessibility → Display

---

## 8. macOS-Specific Patterns

### 8.1 Window Management

- Minimum window size: 900 × 600pt
- Default window size: 1100 × 750pt
- Sidebar is collapsible via `NavigationSplitView` — respect the system sidebar toggle
- Support full-screen mode

### 8.2 Navigation

- Use `NavigationSplitView` with a sidebar, not a bottom tab bar (tab bars are iOS)
- Sidebar items use SF Symbols with `.symbolRenderingMode(.hierarchical)`
- The detail area fills the remaining width
- Sheets (`.sheet()`) for drill-in details, not full navigation pushes

### 8.3 Context Menus

- Repo cards: right-click for "Open on GitHub", "Copy URL", "View Details"
- PR cards: right-click for "Open on GitHub", "Copy PR URL"
- Activity feed items: right-click for "Open Commit on GitHub"

### 8.4 Toolbar

- Place a refresh button (arrow.clockwise) in the toolbar
- Show last-synced timestamp in the toolbar subtitle
- Use `.toolbar` modifier, not custom header views

---

## 9. Machine-Readable Token Reference

This section provides all design tokens in a copy-pasteable format for direct use in Swift code.

```swift
// MARK: - Design Tokens

enum DesignTokens {
    // MARK: Spacing
    static let spacingXXS: CGFloat = 4
    static let spacingXS: CGFloat = 8
    static let spacingSM: CGFloat = 12
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 20
    static let spacingXL: CGFloat = 24
    static let spacingXXL: CGFloat = 32

    // MARK: Corner Radius
    static let radiusCard: CGFloat = 20
    static let radiusStat: CGFloat = 18
    static let radiusButton: CGFloat = 16
    static let radiusBadge: CGFloat = .infinity
    static let radiusHeatmap: CGFloat = 3
    static let radiusMini: CGFloat = 8

    // MARK: Sizes
    static let sidebarWidth: CGFloat = 220
    static let minWindowWidth: CGFloat = 900
    static let minWindowHeight: CGFloat = 600
    static let statCardHeight: CGFloat = 90
    static let repoCardHeight: CGFloat = 80
    static let prCardHeight: CGFloat = 72
    static let heatmapCellSize: CGFloat = 14
    static let heatmapCellGap: CGFloat = 3
    static let streakRingSize: CGFloat = 200
    static let streakRingLineWidth: CGFloat = 12

    // MARK: Animation
    static let animationStateTransition: Double = 0.25
    static let animationDataLoad: Double = 0.4
    static let animationChartDraw: Double = 0.6
    static let animationStreakRing: Double = 0.8
    static let animationTabTransition: Double = 0.2
    static let animationPressFeedback: Double = 0.1
    static let animationHoverHighlight: Double = 0.15
}
```
