---
paths:
  - "GitPulse/**/*.swift"
  - "GitPulseWidget/**/*.swift"
---

# Code Standards — GitPulse

## Swift Standards
- swift-format: applied on save (enforced by PostToolUse hook)
- SwiftLint: clean, no warnings — run `swiftlint` before commits
- Error handling: use Swift's typed throws where possible, always handle errors with do/catch — no force-try (`try!`) or force-unwrap (`!`) except in previews
- Naming: camelCase for variables/functions, PascalCase for types/protocols, SCREAMING_SNAKE for constants
- Module organization: group by feature (Views/, Models/, Services/, Components/) not by type
- All public functions and types must have doc comments using `///` syntax
- Async patterns: use async/await with structured concurrency (TaskGroup, async let) — never use completion handlers for new code

## SwiftUI Standards
- Use @Observable macro (Observation framework) for view models — not ObservableObject/Published
- Prefer @State for view-local state, @Environment for dependency injection
- Extract reusable views into Components/ directory
- Every view must support Dynamic Type (no hardcoded font sizes)
- Use system SF Symbols for icons — prefer `Image(systemName:)` over custom assets
- Liquid Glass: use `.glassEffect()` modifier from docs/DESIGN_SYSTEM.md — never simulate glass with custom blur/opacity stacks

## SwiftData Standards
- All model classes annotated with @Model macro
- Use @Query in views for reactive data fetching
- Migrations handled explicitly via VersionedSchema and SchemaMigrationPlan
- Never perform blocking SwiftData operations on the main actor

## Import Organization
1. Foundation / system frameworks (Foundation, SwiftUI, SwiftData)
2. Apple frameworks (Charts, WidgetKit, AppIntents)
3. Local modules (alphabetical)
- Blank line between each group

## Prohibited Patterns
- Force unwrapping (`!`) outside of #Preview blocks
- Force try (`try!`) in production code
- Implicitly unwrapped optionals in model/service layers
- Raw string URLs — always use URL(string:) with guard/nil check
- Storing secrets in UserDefaults — use Keychain Services exclusively
- Hardcoded colors or spacing values — use design tokens from DESIGN_SYSTEM.md
- Using DispatchQueue for concurrency — use Swift concurrency (async/await, actors)
