//  SyncCoordinator.swift
//  GitPulse

import Foundation
import SwiftData
import os

/// Coordinates on-demand and post-onboarding data synchronization.
///
/// `SyncCoordinator` is an `@Observable` `@MainActor` class designed to be
/// injected into the SwiftUI environment. Views observe `isSyncing` and
/// `lastSyncError` to display loading and error states. The coordinator
/// retrieves the GitHub PAT from Keychain, constructs the service stack
/// (`GitHubAPIClient` -> `BackgroundDataWriter` -> `BackgroundSyncService`),
/// and runs the sync off the main actor.
@Observable
@MainActor
final class SyncCoordinator {

  // MARK: - Observable State

  /// Whether a sync operation is currently in progress.
  private(set) var isSyncing: Bool = false

  /// The error from the most recent failed sync, or `nil` if the last sync succeeded.
  private(set) var lastSyncError: String?

  /// The date of the most recent successful sync completion.
  private(set) var lastSyncDate: Date?

  // MARK: - Dependencies

  private let keychainService: KeychainProviding

  private static let logger = Logger(
    subsystem: "com.gitpulse",
    category: "SyncCoordinator"
  )

  // MARK: - Initialization

  /// Creates a new sync coordinator.
  ///
  /// - Parameter keychainService: The Keychain service for retrieving the stored PAT.
  ///   Defaults to `KeychainService()`.
  init(keychainService: KeychainProviding = KeychainService()) {
    self.keychainService = keychainService
  }

  // MARK: - Public API

  /// Triggers a full data sync cycle.
  ///
  /// Retrieves the PAT from Keychain for the given username, creates the
  /// API client and data writer, and runs `BackgroundSyncService.performSync()`.
  /// This method is safe to call from the main actor; the actual sync work
  /// runs on the `BackgroundSyncService` actor.
  ///
  /// - Parameters:
  ///   - username: The GitHub username whose PAT is stored in Keychain.
  ///   - modelContainer: The app's `ModelContainer` for SwiftData persistence.
  func triggerSync(username: String, modelContainer: ModelContainer) async {
    guard !isSyncing else {
      Self.logger.info("Sync already in progress, skipping request")
      return
    }
    guard !username.isEmpty else {
      Self.logger.warning("Cannot sync: no username provided")
      lastSyncError = "No GitHub username configured."
      return
    }

    isSyncing = true
    lastSyncError = nil

    defer { isSyncing = false }

    do {
      // 1. Retrieve PAT from Keychain
      guard let token = try keychainService.retrieve(for: username) else {
        Self.logger.warning("No token found in Keychain for \(username)")
        lastSyncError = "GitHub token not found. Please reconnect your account."
        return
      }

      // 2. Build the service stack
      let apiClient = GitHubAPIClient(token: token, username: username)
      let dataWriter = BackgroundDataWriter(modelContainer: modelContainer)
      let syncService = BackgroundSyncService(
        apiClient: apiClient,
        dataWriter: dataWriter,
        streakEngine: StreakEngine()
      )

      // 3. Perform sync (runs on the BackgroundSyncService actor)
      try await syncService.performSync()

      lastSyncDate = .now
      Self.logger.info("Sync completed successfully for \(username)")

    } catch let error as KeychainError {
      Self.logger.error("Keychain error during sync: \(error.localizedDescription)")
      lastSyncError = "Failed to access credentials: \(error.localizedDescription)"
    } catch let error as SyncError {
      Self.logger.error("Sync error: \(error.localizedDescription)")
      lastSyncError = error.localizedDescription
    } catch {
      Self.logger.error("Unexpected sync error: \(error.localizedDescription)")
      lastSyncError = "Sync failed: \(error.localizedDescription)"
    }
  }
}
