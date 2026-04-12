//  StreakHeroWidget.swift
//  GitPulseWidget

import SwiftUI
import WidgetKit

struct StreakHeroWidget: Widget {
  let kind: String = "StreakHeroWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StreakHeroProvider()) { entry in
      Text("Streak")
    }
    .configurationDisplayName("Streak Hero")
    .description("Your current streak")
    .supportedFamilies([.systemSmall])
  }
}

struct StreakHeroProvider: TimelineProvider {
  func placeholder(in context: Context) -> StreakHeroEntry {
    StreakHeroEntry(date: .now)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (StreakHeroEntry) -> Void
  ) {
    completion(StreakHeroEntry(date: .now))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<StreakHeroEntry>) -> Void
  ) {
    let entry = StreakHeroEntry(date: .now)
    let timeline = Timeline(
      entries: [entry],
      policy: .after(.now.addingTimeInterval(1800))
    )
    completion(timeline)
  }
}

struct StreakHeroEntry: TimelineEntry {
  let date: Date
}
