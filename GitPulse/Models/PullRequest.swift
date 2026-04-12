//  PullRequest.swift
//  GitPulse

import Foundation
import SwiftData

/// A GitHub pull request tracked across all monitored repositories.
///
/// Pull requests are fetched via the GitHub Search API and stored locally
/// for display in the PRs view. The `id` is the GitHub-assigned PR ID,
/// ensuring deduplication.
@Model
final class PullRequest {

  /// The lifecycle state of a pull request.
  enum PRState: String, Codable, Sendable {
    /// The pull request is currently open and accepting changes.
    case open
    /// The pull request has been merged into its target branch.
    case merged
    /// The pull request was closed without merging.
    case closed
  }

  /// Unique GitHub pull request ID.
  @Attribute(.unique) var id: Int

  /// The pull request number within its repository (e.g., #42).
  var number: Int

  /// The title of the pull request.
  var title: String

  /// The current lifecycle state of this pull request.
  var state: PRState

  /// The full repository name in `owner/repo` format.
  var repositoryFullName: String

  /// The UTC timestamp when this pull request was created.
  var createdAt: Date

  /// The UTC timestamp when this pull request was merged, if applicable.
  var mergedAt: Date?

  /// The UTC timestamp when this pull request was closed, if applicable.
  var closedAt: Date?

  /// The total number of lines added across all files.
  var additions: Int

  /// The total number of lines removed across all files.
  var deletions: Int

  /// The number of files changed in this pull request.
  var changedFiles: Int

  /// Whether this pull request is currently in draft mode.
  var isDraft: Bool

  /// The elapsed time between creation and merge, or `nil` if not yet merged.
  var timeToMerge: TimeInterval? {
    guard let mergedAt else { return nil }
    return mergedAt.timeIntervalSince(createdAt)
  }

  /// Creates a new pull request record.
  /// - Parameters:
  ///   - id: Unique GitHub PR ID.
  ///   - number: The PR number within its repository.
  ///   - title: The pull request title.
  ///   - state: The lifecycle state.
  ///   - repositoryFullName: Full `owner/repo` name.
  ///   - createdAt: UTC creation timestamp.
  ///   - mergedAt: Optional UTC merge timestamp.
  ///   - closedAt: Optional UTC close timestamp.
  ///   - additions: Lines added (defaults to 0).
  ///   - deletions: Lines removed (defaults to 0).
  ///   - changedFiles: Files changed (defaults to 0).
  ///   - isDraft: Draft status (defaults to false).
  init(
    id: Int,
    number: Int,
    title: String,
    state: PRState,
    repositoryFullName: String,
    createdAt: Date,
    mergedAt: Date? = nil,
    closedAt: Date? = nil,
    additions: Int = 0,
    deletions: Int = 0,
    changedFiles: Int = 0,
    isDraft: Bool = false
  ) {
    self.id = id
    self.number = number
    self.title = title
    self.state = state
    self.repositoryFullName = repositoryFullName
    self.createdAt = createdAt
    self.mergedAt = mergedAt
    self.closedAt = closedAt
    self.additions = additions
    self.deletions = deletions
    self.changedFiles = changedFiles
    self.isDraft = isDraft
  }
}
