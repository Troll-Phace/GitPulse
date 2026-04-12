---
paths:
  - "GitPulseTests/**/*.swift"
  - "GitPulseUITests/**/*.swift"
  - "**/*Tests.swift"
  - "**/*Test.swift"
---

# Testing Standards

## General Rules
- Write tests for every new function/component/endpoint
- Test happy path, edge cases, and error handling
- Mock all GitHub API calls — never hit real services in tests
- Descriptive test names: `test_{module}_{behavior}_{scenario}` (e.g., `test_streakCalculator_countsConsecutiveDays_withGapOnWeekend`)
- One assertion per test where practical
- Tests must be deterministic (no timing dependencies, no random data without seeds)

## Swift Testing / XCTest Patterns
- Prefer the Swift Testing framework (`import Testing`, `@Test`, `#expect`) for new tests
- Use XCTest only for UI tests and tests requiring XCTestCase lifecycle hooks
- Use `@Suite` to group related tests by feature module
- Use `@Test(arguments:)` for parameterized tests over repeated similar assertions
- Mock URLSession with a custom URLProtocol subclass — register it in test setUp
- Use in-memory ModelContainer for SwiftData tests:
  ```swift
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try ModelContainer(for: Schema(...), configurations: [config])
  ```
- Use `@MainActor` on tests that touch SwiftUI views or @Observable view models

## Mock Patterns
- Create protocol-based abstractions for all external services (GitHubServiceProtocol, KeychainServiceProtocol)
- Provide mock implementations in a shared TestHelpers/ directory
- Mock responses should use realistic GitHub API JSON fixtures stored in TestFixtures/
- Never rely on network availability — all tests must pass in airplane mode

## UI Test Patterns
- Set accessibility identifiers on all interactive elements for UI test targeting
- Use `app.launchArguments` to inject mock data and skip onboarding in UI tests
- Test critical user flows: onboarding, dashboard load, streak display, navigation between tabs

## Coverage Expectations
- New code: aim for 80%+ coverage
- Critical paths (Keychain access, API parsing, streak calculation): 95%+ coverage
- SwiftUI views: test view model logic extensively, use previews for visual verification
