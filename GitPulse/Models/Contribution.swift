//  Contribution.swift
//  GitPulse

import Foundation
import SwiftData

/// A single GitHub contribution event, such as a push, pull request, or issue action.
///
/// Each contribution maps to one event from the GitHub Events API (`/users/{user}/events`).
/// The `id` is the GitHub event ID, ensuring deduplication across syncs.
@Model
final class Contribution {

  /// The type of contribution activity recorded from GitHub.
  enum ContributionType: String, Codable, Sendable {
    /// A push event containing one or more commits.
    case push
    /// A pull request opened, closed, or merged.
    case pullRequest
    /// A pull request review submitted.
    case pullRequestReview
    /// An issue opened, closed, or commented on.
    case issue
    /// A repository, branch, or tag creation event.
    case create
    /// A repository fork event.
    case fork
  }

  /// Unique GitHub event ID, used to prevent duplicate imports.
  @Attribute(.unique) var id: String

  /// The category of this contribution event.
  var type: ContributionType

  /// The UTC timestamp when this event occurred on GitHub.
  var date: Date

  /// The name of the repository where this event occurred.
  var repositoryName: String

  /// The owner (user or organization) of the repository.
  var repositoryOwner: String

  /// An optional commit message or PR/issue title associated with this event.
  var message: String?

  /// The number of lines added in this event (for push and PR events).
  var additions: Int

  /// The number of lines removed in this event (for push and PR events).
  var deletions: Int

  /// The number of commits included in a push event.
  var commitCount: Int

  /// Creates a new contribution record.
  /// - Parameters:
  ///   - id: Unique GitHub event ID.
  ///   - type: The category of contribution.
  ///   - date: UTC timestamp of the event.
  ///   - repositoryName: Repository name.
  ///   - repositoryOwner: Repository owner.
  ///   - message: Optional commit message or title.
  ///   - additions: Lines added (defaults to 0).
  ///   - deletions: Lines removed (defaults to 0).
  ///   - commitCount: Number of commits in the push (defaults to 0).
  init(
    id: String,
    type: ContributionType,
    date: Date,
    repositoryName: String,
    repositoryOwner: String,
    message: String? = nil,
    additions: Int = 0,
    deletions: Int = 0,
    commitCount: Int = 0
  ) {
    self.id = id
    self.type = type
    self.date = date
    self.repositoryName = repositoryName
    self.repositoryOwner = repositoryOwner
    self.message = message
    self.additions = additions
    self.deletions = deletions
    self.commitCount = commitCount
  }
}
