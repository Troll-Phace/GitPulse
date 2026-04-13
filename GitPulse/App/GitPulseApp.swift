//  GitPulseApp.swift
//  GitPulse
//
//  Created by Anthony Grimaldi on 4/12/26.
//

import SwiftData
import SwiftUI
import os

#if os(iOS)
  import BackgroundTasks
#endif

@main
struct GitPulseApp: App {

  private static let logger = Logger(
    subsystem: "com.gitpulse",
    category: "GitPulseApp"
  )

  /// The shared navigation state for sidebar tab selection and keyboard shortcuts.
  @State private var navigationState = NavigationState()

  /// The sync coordinator for triggering data syncs from commands and views.
  @State private var syncCoordinator = SyncCoordinator()

  /// The persisted GitHub username, used for Keychain lookups during sync.
  @AppStorage("githubUsername") private var githubUsername: String = ""

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Contribution.self,
      Repository.self,
      LanguageStat.self,
      PullRequest.self,
      UserProfile.self,
      SyncMetadata.self,
    ])
    // TODO: Re-enable groupContainer when app group is registered with Apple Developer account
    // groupContainer: .identifier("group.com.gitpulse.shared")
    let modelConfiguration = ModelConfiguration(
      "GitPulse",
      schema: schema,
      isStoredInMemoryOnly: false
    )

    do {
      return try ModelContainer(
        for: schema,
        migrationPlan: GitPulseSchemaMigrationPlan.self,
        configurations: [modelConfiguration]
      )
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  init() {
    registerBackgroundTask()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(navigationState)
        .environment(syncCoordinator)
    }
    .modelContainer(sharedModelContainer)
    .defaultSize(width: 1100, height: 750)
    .commands {
      // MARK: Settings Shortcut (Cmd+,)
      CommandGroup(replacing: .appSettings) {
        Button("Settings...") {
          navigationState.selectTab(.settings)
        }
        .keyboardShortcut(",")
      }

      // MARK: Navigation Shortcuts (Cmd+1 through Cmd+5)
      CommandMenu("Navigation") {
        ForEach(SidebarTab.allCases) { tab in
          Button(tab.title) {
            navigationState.selectTab(tab)
          }
          .keyboardShortcut(tab.keyboardShortcutKey)
        }
      }

      // MARK: Refresh Shortcut (Cmd+R)
      CommandGroup(after: .toolbar) {
        Button("Refresh") {
          Task {
            await syncCoordinator.triggerSync(
              username: githubUsername,
              modelContainer: sharedModelContainer
            )
          }
        }
        .keyboardShortcut("r")
        .disabled(syncCoordinator.isSyncing)
      }
    }
  }

  /// Registers the background app refresh task handler.
  ///
  /// The handler creates a `BackgroundSyncService` on-demand when the system
  /// fires the task. Actual token retrieval and API client construction will
  /// be fully wired in later phases once credential management is integrated.
  ///
  /// - Note: `BGTaskScheduler` / `BGAppRefreshTask` is iOS-only. On macOS, background
  ///   refresh will use `NSBackgroundActivityScheduler` or Timer-based polling.
  private func registerBackgroundTask() {
    #if os(iOS)
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: BackgroundSyncService.taskIdentifier,
        using: nil
      ) { task in
        Self.logger.info("Background task fired: \(BackgroundSyncService.taskIdentifier)")

        // TODO: Wire up full sync service once credential management is integrated.
        // For now, complete the task immediately and log.
        // In later phases, this will:
        //   1. Retrieve the PAT from Keychain
        //   2. Create a GitHubAPIClient with the stored credentials
        //   3. Create a BackgroundDataWriter with the shared ModelContainer
        //   4. Create and run BackgroundSyncService.performSync()
        task.setTaskCompleted(success: true)
      }
      Self.logger.info("Registered background task: \(BackgroundSyncService.taskIdentifier)")
    #else
      // On macOS, BackgroundSyncService.scheduleRefresh() uses
      // NSBackgroundActivityScheduler. It will be called after the user
      // completes onboarding and credentials are available.
      Self.logger.info(
        "macOS: background sync will use NSBackgroundActivityScheduler after onboarding")
    #endif
  }
}
