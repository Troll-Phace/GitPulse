//  AppState.swift
//  GitPulse

import SwiftUI

// MARK: - Sidebar Tab

/// Represents each navigable section in the app's sidebar.
///
/// Each case maps to a top-level view, an SF Symbol icon, a display title,
/// and a keyboard shortcut key for Cmd+N navigation.
enum SidebarTab: String, CaseIterable, Identifiable, Hashable {
  case dashboard
  case streaks
  case repos
  case pullRequests
  case settings

  var id: String { rawValue }

  /// The human-readable title shown in the sidebar.
  var title: String {
    switch self {
    case .dashboard: "Dashboard"
    case .streaks: "Streaks"
    case .repos: "Repositories"
    case .pullRequests: "Pull Requests"
    case .settings: "Settings"
    }
  }

  /// The SF Symbol name for this tab's icon.
  var systemImage: String {
    switch self {
    case .dashboard: "chart.bar.fill"
    case .streaks: "flame.fill"
    case .repos: "folder.fill"
    case .pullRequests: "arrow.triangle.pull"
    case .settings: "gearshape"
    }
  }

  /// The keyboard shortcut key equivalent (Cmd+1 through Cmd+5).
  var keyboardShortcutKey: KeyEquivalent {
    switch self {
    case .dashboard: "1"
    case .streaks: "2"
    case .repos: "3"
    case .pullRequests: "4"
    case .settings: "5"
    }
  }
}

// MARK: - Navigation State

/// Observable navigation state tracking the currently selected sidebar tab.
///
/// Injected into the environment so all views can read (and optionally write)
/// the active tab. Use `selectTab(_:)` for animated transitions.
@Observable
final class NavigationState {
  /// The currently selected sidebar tab.
  var selectedTab: SidebarTab = .dashboard

  /// Selects a tab with an animated transition.
  ///
  /// - Parameter tab: The tab to navigate to.
  func selectTab(_ tab: SidebarTab) {
    withAnimation(.easeInOut(duration: DesignTokens.animationTabTransition)) {
      selectedTab = tab
    }
  }
}
