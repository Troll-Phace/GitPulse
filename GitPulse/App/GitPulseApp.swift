//  GitPulseApp.swift
//  GitPulse
//
//  Created by Anthony Grimaldi on 4/12/26.
//

import SwiftData
import SwiftUI

@main
struct GitPulseApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([])
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
        configurations: [modelConfiguration]
      )
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
