//  Repository.swift
//  GitPulse

import Foundation
import SwiftData

/// A GitHub repository owned by or accessible to the authenticated user.
///
/// Repositories are fetched from the GitHub API (`/user/repos`) and stored
/// locally. Each repository maintains a cascade relationship to its
/// `LanguageStat` entries, so deleting a repository also removes its
/// language breakdown data.
@Model
final class Repository {

  /// Unique GitHub repository ID.
  @Attribute(.unique) var id: Int

  /// The short name of the repository (e.g., "GitPulse").
  var name: String

  /// The full name in `owner/repo` format (e.g., "octocat/GitPulse").
  var fullName: String

  /// An optional description of the repository.
  var descriptionText: String?

  /// The primary programming language of the repository, if detected.
  var language: String?

  /// The number of stars (stargazers) on the repository.
  var starCount: Int

  /// The number of forks of the repository.
  var forkCount: Int

  /// Whether the repository is private.
  var isPrivate: Bool

  /// The UTC timestamp of the most recent push to the repository.
  var lastPushDate: Date?

  /// The UTC timestamp when the repository was created on GitHub.
  var createdAt: Date

  /// The UTC timestamp when the repository was last updated on GitHub.
  var updatedAt: Date

  /// The language breakdown statistics for this repository.
  /// Deleting the repository cascades to delete all associated language stats.
  @Relationship(deleteRule: .cascade) var languages: [LanguageStat]

  /// Creates a new repository record.
  /// - Parameters:
  ///   - id: Unique GitHub repository ID.
  ///   - name: Short repository name.
  ///   - fullName: Full `owner/repo` name.
  ///   - descriptionText: Optional description.
  ///   - language: Primary language, if any.
  ///   - starCount: Star count (defaults to 0).
  ///   - forkCount: Fork count (defaults to 0).
  ///   - isPrivate: Privacy status (defaults to false).
  ///   - lastPushDate: Last push timestamp (defaults to nil).
  ///   - createdAt: Creation timestamp.
  ///   - updatedAt: Last update timestamp.
  ///   - languages: Language stats (defaults to empty).
  init(
    id: Int,
    name: String,
    fullName: String,
    descriptionText: String? = nil,
    language: String? = nil,
    starCount: Int = 0,
    forkCount: Int = 0,
    isPrivate: Bool = false,
    lastPushDate: Date? = nil,
    createdAt: Date,
    updatedAt: Date,
    languages: [LanguageStat] = []
  ) {
    self.id = id
    self.name = name
    self.fullName = fullName
    self.descriptionText = descriptionText
    self.language = language
    self.starCount = starCount
    self.forkCount = forkCount
    self.isPrivate = isPrivate
    self.lastPushDate = lastPushDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.languages = languages
  }
}
