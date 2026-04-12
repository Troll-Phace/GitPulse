//  SyncMetadata.swift
//  GitPulse

import Foundation
import SwiftData

/// Metadata tracking the most recent data synchronization with the GitHub API.
///
/// A single `SyncMetadata` record (keyed by `"lastSync"`) is maintained to
/// enable incremental fetches and to monitor API rate limit consumption.
@Model
final class SyncMetadata {

  /// A unique key identifying this metadata record (e.g., `"lastSync"`).
  @Attribute(.unique) var key: String

  /// The UTC timestamp when the sync completed.
  var date: Date

  /// The number of GitHub events processed during the sync.
  var eventsProcessed: Int

  /// The remaining API rate limit after the sync, from `X-RateLimit-Remaining`.
  var rateLimitRemaining: Int

  /// The UTC timestamp when the rate limit window resets, from `X-RateLimit-Reset`.
  var rateLimitReset: Date

  /// Creates a new sync metadata record.
  /// - Parameters:
  ///   - key: Unique identifier for this metadata entry.
  ///   - date: UTC timestamp of sync completion.
  ///   - eventsProcessed: Number of events processed.
  ///   - rateLimitRemaining: Remaining API requests in the current window.
  ///   - rateLimitReset: UTC timestamp when the rate limit resets.
  init(
    key: String,
    date: Date,
    eventsProcessed: Int,
    rateLimitRemaining: Int,
    rateLimitReset: Date
  ) {
    self.key = key
    self.date = date
    self.eventsProcessed = eventsProcessed
    self.rateLimitRemaining = rateLimitRemaining
    self.rateLimitReset = rateLimitReset
  }
}
