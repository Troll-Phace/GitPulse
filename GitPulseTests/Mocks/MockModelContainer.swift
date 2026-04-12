//  MockModelContainer.swift
//  GitPulseTests

import Foundation
import SwiftData

@testable import GitPulse

/// Provides an in-memory `ModelContainer` for use in tests.
///
/// Using `isStoredInMemoryOnly: true` ensures each test gets a fresh
/// database that is discarded when the container is deallocated,
/// preventing cross-test contamination.
enum TestModelContainer {

  /// Creates a new in-memory `ModelContainer` configured with all
  /// GitPulse model types.
  /// - Returns: A ready-to-use `ModelContainer` backed by RAM only.
  /// - Throws: If `ModelContainer` initialization fails.
  static func create() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(
      for: Contribution.self, Repository.self, LanguageStat.self,
      PullRequest.self, UserProfile.self, SyncMetadata.self,
      configurations: config
    )
  }
}
