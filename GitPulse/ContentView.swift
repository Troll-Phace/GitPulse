//  ContentView.swift
//  GitPulse
//
//  Created by Anthony Grimaldi on 4/12/26.
//

import SwiftUI

/// The root content view that gates the main app behind onboarding.
///
/// On first launch (when `hasCompletedOnboarding` is `false`), the onboarding
/// flow is displayed. Once completed, the main navigation split view is shown.
struct ContentView: View {
  /// Persisted flag indicating whether the user has completed onboarding.
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

  var body: some View {
    if !hasCompletedOnboarding {
      OnboardingFlow {
        hasCompletedOnboarding = true
      }
      .frame(
        minWidth: 600, idealWidth: 800,
        minHeight: 500, idealHeight: 650
      )
    } else {
      NavigationSplitView {
        List {
          Text("GitPulse")
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
      } detail: {
        Text("Select an item")
      }
    }
  }
}

#Preview {
  ContentView()
}
