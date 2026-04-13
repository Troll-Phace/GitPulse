//  StreakHistoryTimeline.swift
//  GitPulse

import Charts
import SwiftUI

/// A bar chart showing the user's streak history over the last 12 months.
///
/// Each bar represents a contiguous streak period, with height proportional to the
/// streak length. The longest streak is highlighted in gold with a "BEST" label,
/// and the current active streak is highlighted in stronger orange with a "NOW" label.
/// Normal bars use orange at varying opacities based on their normalized height.
struct StreakHistoryTimeline: View {

  /// The streak bars to display, in chronological order.
  let bars: [StreakBar]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Controls the animated draw-in of bars from zero height.
  @State private var hasAppeared = false

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        headerRow
        if bars.isEmpty {
          emptyState
        } else {
          chart
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityDescription)
  }

  // MARK: - Subviews

  /// Header row with title and time range label.
  private var headerRow: some View {
    HStack {
      Text("Streak History")
        .font(.gpCardTitle)
        .foregroundStyle(Color.gpTextPrimary)

      Spacer()

      Text("Last 12 months")
        .font(.gpMicro)
        .foregroundStyle(Color.gpTextSecondary)
    }
  }

  /// The Swift Charts bar chart with Y-axis day labels and dashed grid lines.
  private var chart: some View {
    Chart {
      ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
        BarMark(
          x: .value("Streak", index),
          y: .value("Days", hasAppeared ? bar.period.length : 0)
        )
        .foregroundStyle(barColor(for: bar))
        .cornerRadius(DesignTokens.spacingXXS)
        .annotation(position: .overlay) {
          barAnnotation(for: bar)
        }
      }

      // Dashed grid lines at key thresholds
      RuleMark(y: .value("", 15))
        .foregroundStyle(Color.gpGlassBorder.opacity(0.3))
        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

      RuleMark(y: .value("", 30))
        .foregroundStyle(Color.gpGlassBorder.opacity(0.3))
        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))

      RuleMark(y: .value("", 50))
        .foregroundStyle(Color.gpGlassBorder.opacity(0.3))
        .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
    }
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(values: [0, 15, 30, 50]) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
          .foregroundStyle(Color.gpGlassBorder.opacity(0.2))

        AxisValueLabel {
          if let intVal = value.as(Int.self) {
            Text("\(intVal)d")
              .font(.gpMicro)
              .foregroundStyle(Color.gpTextTertiary)
          }
        }
      }
    }
    .chartLegend(.hidden)
    .frame(height: 150)
    .task {
      guard !hasAppeared else { return }
      if reduceMotion {
        hasAppeared = true
      } else {
        withAnimation(.easeOut(duration: DesignTokens.animationChartDraw)) {
          hasAppeared = true
        }
      }
    }
  }

  /// Empty state shown when no streak history data exists.
  private var emptyState: some View {
    VStack(spacing: DesignTokens.spacingXS) {
      Image(systemName: "chart.bar")
        .font(.system(size: 24))
        .foregroundStyle(Color.gpTextTertiary)

      Text("No streak history yet")
        .font(.gpCaption)
        .foregroundStyle(Color.gpTextSecondary)
    }
    .frame(maxWidth: .infinity, minHeight: 150)
  }

  // MARK: - Helpers

  /// Returns the fill color for a bar based on its type (longest, current, or normal).
  ///
  /// - Parameter bar: The streak bar to color.
  /// - Returns: A `Color` with appropriate opacity.
  private func barColor(for bar: StreakBar) -> Color {
    if bar.isLongest {
      return Color.gpGold.opacity(0.25)
    } else if bar.isCurrent {
      return Color.gpOrange.opacity(0.4)
    } else {
      // Scale opacity based on normalized height (0.12 to 0.30)
      let opacity = 0.12 + bar.normalizedHeight * 0.18
      return Color.gpOrange.opacity(opacity)
    }
  }

  /// Builds the annotation view centered on a bar, showing the day count and optional label.
  ///
  /// - Parameter bar: The streak bar to annotate.
  /// - Returns: A view with the day count and an optional "BEST" or "NOW" tag.
  @ViewBuilder
  private func barAnnotation(for bar: StreakBar) -> some View {
    VStack(spacing: 2) {
      Text(bar.label)
        .font(.gpMicro)
        .fontWeight(bar.isLongest || bar.isCurrent ? .semibold : .medium)
        .foregroundStyle(bar.isLongest ? Color.gpGold : Color.gpOrange)

      if bar.isLongest {
        Text("BEST")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(Color.gpGold.opacity(0.7))
      } else if bar.isCurrent {
        Text("NOW")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(Color.gpOrange.opacity(0.7))
      }
    }
  }

  /// Builds a VoiceOver description summarizing the streak history chart.
  private var accessibilityDescription: String {
    let longestLabel = bars.first(where: \.isLongest)?.label ?? "none"
    let currentLabel = bars.first(where: \.isCurrent)?.label ?? "none"
    return "Streak history chart showing \(bars.count) streak periods. "
      + "Longest streak: \(longestLabel). Current streak: \(currentLabel)."
  }
}

// MARK: - Previews

#Preview("StreakHistoryTimeline — With Data") {
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: .now)

  let mockPeriods: [(daysAgo: Int, length: Int)] = [
    (300, 8),
    (270, 12),
    (240, 5),
    (220, 3),
    (180, 21),
    (140, 7),
    (100, 47),
    (50, 10),
    (30, 15),
    (14, 14),
  ]

  let maxLength = mockPeriods.map(\.length).max() ?? 1

  let bars: [StreakBar] = mockPeriods.enumerated().map { index, mock in
    let endDate = calendar.date(byAdding: .day, value: -mock.daysAgo, to: today) ?? today
    let startDate = calendar.date(byAdding: .day, value: -(mock.length - 1), to: endDate) ?? endDate
    let period = StreakPeriod(id: UUID(), startDate: startDate, endDate: endDate)
    let isLongest = mock.length == 47
    let isCurrent = index == mockPeriods.count - 1

    return StreakBar(
      id: UUID(),
      period: period,
      normalizedHeight: Double(mock.length) / Double(maxLength),
      isLongest: isLongest,
      isCurrent: isCurrent,
      label: "\(mock.length)d"
    )
  }

  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakHistoryTimeline(bars: bars)
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 900, height: 280)
}

#Preview("StreakHistoryTimeline — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakHistoryTimeline(bars: [])
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 900, height: 280)
}
