//  WeeklyActivityChart.swift
//  GitPulse

import Charts
import SwiftUI

// MARK: - WeeklyActivityChart

/// A line and area chart showing 7 days of commit activity.
///
/// Renders a `LineMark` with Catmull-Rom interpolation over an `AreaMark` with a
/// green gradient fill. Each data point is highlighted with a `PointMark`.
/// Wrapped in a `GlassCard` for Liquid Glass styling.
struct WeeklyActivityChart: View {
  /// The 7 days of activity data, ordered oldest to newest.
  let days: [DayActivity]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Whether all day counts are zero or the data is empty.
  private var isEmpty: Bool {
    days.isEmpty || days.allSatisfy { $0.count == 0 }
  }

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        Text("Weekly Commits")
          .font(.gpCardTitle)
          .foregroundStyle(Color.gpTextPrimary)

        if isEmpty {
          emptyState
        } else {
          chartBody
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Weekly commits chart. \(days.reduce(0) { $0 + $1.count }) total commits over 7 days."
    )
  }

  // MARK: - Subviews

  /// The Swift Charts line + area visualization.
  private var chartBody: some View {
    Chart(days) { day in
      AreaMark(
        x: .value("Day", day.dayName),
        y: .value("Commits", day.count)
      )
      .foregroundStyle(
        .linearGradient(
          colors: [Color.gpGreen.opacity(0.3), Color.gpGreen.opacity(0.0)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .interpolationMethod(.catmullRom)

      LineMark(
        x: .value("Day", day.dayName),
        y: .value("Commits", day.count)
      )
      .foregroundStyle(Color.gpGreen)
      .interpolationMethod(.catmullRom)
      .lineStyle(StrokeStyle(lineWidth: 2))

      PointMark(
        x: .value("Day", day.dayName),
        y: .value("Commits", day.count)
      )
      .foregroundStyle(Color.gpGreen)
      .symbolSize(20)
    }
    .chartXAxis {
      AxisMarks { _ in
        AxisValueLabel()
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextTertiary)
      }
    }
    .chartYAxis {
      AxisMarks { _ in
        AxisGridLine()
          .foregroundStyle(Color.gpGlassBorder)
        AxisValueLabel()
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextTertiary)
      }
    }
    .chartLegend(.hidden)
    .frame(height: 150)
    .animation(
      reduceMotion ? .none : .easeOut(duration: DesignTokens.animationChartDraw),
      value: days.map(\.count)
    )
  }

  /// Empty state displayed when there are no commits this week.
  private var emptyState: some View {
    Text("No commits this week")
      .font(.gpBody)
      .foregroundStyle(Color.gpTextSecondary)
      .frame(maxWidth: .infinity, minHeight: 150)
      .multilineTextAlignment(.center)
  }

  // MARK: - Preview Helpers

  /// Mock data for Xcode previews.
  static var mockDays: [DayActivity] {
    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    let counts = [3, 7, 2, 5, 8, 4, 6]
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: .now)
    return (0..<7).map { index in
      DayActivity(
        id: calendar.date(byAdding: .day, value: index - 6, to: today) ?? today,
        dayName: dayNames[index],
        count: counts[index]
      )
    }
  }
}

// MARK: - Previews

#Preview("WeeklyActivityChart — With Data") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    WeeklyActivityChart(days: WeeklyActivityChart.mockDays)
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 500, height: 280)
}

#Preview("WeeklyActivityChart — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    WeeklyActivityChart(days: [])
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 500, height: 280)
}
