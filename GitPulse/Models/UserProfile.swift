//  UserProfile.swift
//  GitPulse

import Foundation
import SwiftData

/// The authenticated GitHub user's profile and aggregated statistics.
///
/// A single `UserProfile` instance is maintained locally, updated after each
/// background sync. Streak and contribution stats are computed by the
/// `StreakEngine` and written here for quick access by views and widgets.
@Model
final class UserProfile {

  /// The GitHub username, used as the unique identifier.
  @Attribute(.unique) var username: String

  /// The URL string for the user's GitHub avatar image.
  var avatarURL: String

  /// The user's display name from their GitHub profile, if set.
  var displayName: String?

  /// The user's bio from their GitHub profile, if set.
  var bio: String?

  /// The number of public repositories owned by the user.
  var publicRepoCount: Int

  /// The number of followers on the user's GitHub profile.
  var followerCount: Int

  /// The user's current consecutive-day contribution streak.
  var currentStreak: Int

  /// The user's longest-ever consecutive-day contribution streak.
  var longestStreak: Int

  /// The total number of unique days with at least one contribution.
  var activeDays: Int

  /// The total number of contribution events recorded.
  var totalContributions: Int

  /// The UTC timestamp of the most recent successful data sync.
  var lastSyncDate: Date?

  /// Creates a new user profile.
  /// - Parameters:
  ///   - username: GitHub username (unique).
  ///   - avatarURL: Avatar image URL string.
  ///   - displayName: Optional display name.
  ///   - bio: Optional bio text.
  ///   - publicRepoCount: Public repo count (defaults to 0).
  ///   - followerCount: Follower count (defaults to 0).
  ///   - currentStreak: Current streak in days (defaults to 0).
  ///   - longestStreak: Longest streak in days (defaults to 0).
  ///   - activeDays: Total active days (defaults to 0).
  ///   - totalContributions: Total contribution events (defaults to 0).
  ///   - lastSyncDate: Last sync timestamp (defaults to nil).
  init(
    username: String,
    avatarURL: String,
    displayName: String? = nil,
    bio: String? = nil,
    publicRepoCount: Int = 0,
    followerCount: Int = 0,
    currentStreak: Int = 0,
    longestStreak: Int = 0,
    activeDays: Int = 0,
    totalContributions: Int = 0,
    lastSyncDate: Date? = nil
  ) {
    self.username = username
    self.avatarURL = avatarURL
    self.displayName = displayName
    self.bio = bio
    self.publicRepoCount = publicRepoCount
    self.followerCount = followerCount
    self.currentStreak = currentStreak
    self.longestStreak = longestStreak
    self.activeDays = activeDays
    self.totalContributions = totalContributions
    self.lastSyncDate = lastSyncDate
  }
}
