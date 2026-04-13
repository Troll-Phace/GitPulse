//  ContentView.swift
//  GitPulse
//
//  Created by Anthony Grimaldi on 4/12/26.
//

import SwiftData
import SwiftUI

/// The root content view that gates the main app behind onboarding.
///
/// On first launch (when `hasCompletedOnboarding` is `false`), the onboarding
/// flow is displayed. Once completed, the main tabbed sidebar view is shown.
/// The sidebar groups the four main navigation tabs into a ``TabSection``
/// separated from Settings, matching the wireframe layout.
struct ContentView: View {
  /// Persisted flag indicating whether the user has completed onboarding.
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

  /// The GitHub username displayed in the sidebar branding area.
  @AppStorage("githubUsername") private var githubUsername: String = ""

  /// The shared navigation state injected from the app scene.
  @Environment(NavigationState.self) private var navigationState

  /// The sync coordinator for triggering data syncs.
  @Environment(SyncCoordinator.self) private var syncCoordinator

  /// The model container for SwiftData persistence.
  @Environment(\.modelContext) private var modelContext

  /// Local selection state bound to the TabView.
  @State private var selectedTab: SidebarTab = .dashboard

  var body: some View {
    if !hasCompletedOnboarding {
      OnboardingFlow { username in
        githubUsername = username
        hasCompletedOnboarding = true
        triggerInitialSync(username: username)
      }
      .frame(
        minWidth: 600, idealWidth: 800,
        minHeight: 500, idealHeight: 650
      )
    } else {
      TabView(selection: $selectedTab) {
        TabSection("Navigation") {
          Tab("Dashboard", systemImage: "chart.bar.fill", value: SidebarTab.dashboard) {
            DashboardView()
          }

          Tab("Streaks", systemImage: "flame.fill", value: SidebarTab.streaks) {
            StreaksView()
          }

          Tab("Repositories", systemImage: "folder.fill", value: SidebarTab.repos) {
            ReposView()
          }

          Tab("Pull Requests", systemImage: "arrow.triangle.pull", value: SidebarTab.pullRequests) {
            PRsView()
          }
        }

        TabSection("Preferences") {
          Tab("Settings", systemImage: "gearshape", value: SidebarTab.settings) {
            SettingsView()
          }
        }
      }
      .tabViewStyle(.sidebarAdaptable)
      .tabViewSidebarHeader {
        SidebarHeaderView(username: githubUsername)
      }
      .tabViewSidebarFooter {
        SidebarFooterView(username: githubUsername)
      }
      .frame(minWidth: DesignTokens.minWindowWidth, minHeight: DesignTokens.minWindowHeight)
      .background(Color.gpBackground.ignoresSafeArea())
      .onChange(of: selectedTab) { _, newValue in
        navigationState.selectedTab = newValue
      }
      .onChange(of: navigationState.selectedTab) { _, newValue in
        if selectedTab != newValue {
          selectedTab = newValue
        }
      }
    }
  }

  // MARK: - Private Helpers

  /// Triggers the initial data sync after onboarding completes.
  ///
  /// Runs the sync asynchronously so it does not block the UI transition
  /// from the onboarding flow to the main app shell.
  private func triggerInitialSync(username: String) {
    let container = modelContext.container
    Task {
      await syncCoordinator.triggerSync(
        username: username,
        modelContainer: container
      )
    }
  }
}

// MARK: - Sidebar Header View

/// Displays the app branding at the top of the sidebar.
///
/// Shows a blue git-branch icon circle alongside the app name and the
/// authenticated GitHub username, matching the wireframe layout.
private struct SidebarHeaderView: View {
  let username: String

  var body: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      ZStack {
        Circle()
          .fill(Color.gpBlue.opacity(0.15))
          .frame(width: 28, height: 28)

        Image(systemName: "arrow.triangle.branch")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Color.gpBlue)
          .symbolRenderingMode(.hierarchical)
      }

      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS / 2) {
        Text("GitPulse")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.gpTextPrimary)

        if !username.isEmpty {
          Text("@\(username)")
            .font(.gpMicro)
            .foregroundStyle(Color.gpTextSecondary)
        }
      }

      Spacer()
    }
    .padding(.horizontal, DesignTokens.spacingXS)
    .padding(.vertical, DesignTokens.spacingXS)
  }
}

// MARK: - Sidebar Footer View

/// Displays user connection status at the bottom of the sidebar.
///
/// Shows an avatar circle with the user's initials, their display name,
/// and a green "Connected" indicator dot, matching the wireframe layout.
private struct SidebarFooterView: View {
  let username: String

  /// Derives up to two uppercase initials from the username.
  private var initials: String {
    let cleaned = username.replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: "_", with: " ")
    let components = cleaned.split(separator: " ")
    if components.count >= 2 {
      return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
    }
    return String(username.prefix(2)).uppercased()
  }

  var body: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      ZStack {
        Circle()
          .fill(Color.gpGlassFill)
          .overlay(
            Circle()
              .stroke(Color.gpGlassBorder, lineWidth: 0.5)
          )
          .frame(width: 28, height: 28)

        Text(initials)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Color.gpTextSecondary)
      }

      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS / 2) {
        Text(username.isEmpty ? "Not Connected" : username)
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.gpTextPrimary)
          .lineLimit(1)

        HStack(spacing: DesignTokens.spacingXXS) {
          Circle()
            .fill(username.isEmpty ? Color.gpOrange : Color.gpGreen)
            .frame(width: 6, height: 6)

          Text(username.isEmpty ? "Disconnected" : "Connected")
            .font(.gpMicro)
            .foregroundStyle(Color.gpTextSecondary)
        }
      }

      Spacer()
    }
    .padding(.horizontal, DesignTokens.spacingXS)
    .padding(.vertical, DesignTokens.spacingXS)
  }
}

// MARK: - Previews

#Preview("Authenticated") {
  ContentView()
    .environment(NavigationState())
    .environment(SyncCoordinator())
}

#Preview("Sidebar Header") {
  SidebarHeaderView(username: "anthonygrimaldi")
    .frame(width: 220)
    .background(Color.gpBackground)
}

#Preview("Sidebar Footer - Connected") {
  SidebarFooterView(username: "anthonygrimaldi")
    .frame(width: 220)
    .background(Color.gpBackground)
}

#Preview("Sidebar Footer - Disconnected") {
  SidebarFooterView(username: "")
    .frame(width: 220)
    .background(Color.gpBackground)
}
