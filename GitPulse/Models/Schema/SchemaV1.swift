//  SchemaV1.swift
//  GitPulse

import Foundation
import SwiftData

/// The initial versioned schema for the GitPulse SwiftData store.
///
/// Declaring the schema as a `VersionedSchema` from day one ensures
/// that future migrations have a clean baseline to migrate from.
enum SchemaV1: VersionedSchema {

  /// The semantic version identifier for this schema revision.
  static let versionIdentifier = Schema.Version(1, 0, 0)

  /// All persistent model types included in this schema version.
  static var models: [any PersistentModel.Type] {
    [
      Contribution.self,
      Repository.self,
      LanguageStat.self,
      PullRequest.self,
      UserProfile.self,
      SyncMetadata.self,
    ]
  }
}

/// The migration plan for the GitPulse SwiftData store.
///
/// Currently contains only `SchemaV1` with no migration stages.
/// Future schema versions will be appended to `schemas` and their
/// corresponding `MigrationStage` entries added to `stages`.
enum GitPulseSchemaMigrationPlan: SchemaMigrationPlan {

  /// All schema versions in chronological order, oldest first.
  static var schemas: [any VersionedSchema.Type] {
    [SchemaV1.self]
  }

  /// Migration stages between consecutive schema versions.
  /// Empty for v1 since there is no prior version to migrate from.
  static var stages: [MigrationStage] {
    []
  }
}
