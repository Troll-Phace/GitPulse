//  ContributionHeatmap.swift
//  GitPulse

import Charts
import SwiftUI

// MARK: - ContributionHeatmap

/// A GitHub-style contribution heatmap displaying 16 weeks of activity using Swift Charts.
///
/// Renders a grid of `RectangleMark` cells where each cell represents one calendar day.
/// Intensity is color-coded from empty (#161B22) to very high (#39D353) using the
/// design system's heatmap color scale. Includes day-of-week axis labels, a color
/// legend, and a total contributions footer.
struct ContributionHeatmap: View {
  /// The 112 cells representing 16 weeks of contribution data.
  let cells: [HeatmapCell]

  /// The total number of contributions within the 16-week window.
  let totalContributions: Int

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        headerRow
        if cells.isEmpty || cells.allSatisfy({ $0.level == 0 }) {
          emptyState
        } else {
          chartBody
          legendRow
        }
        footerText
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Contribution heatmap showing 16 weeks of activity. \(totalContributions) total contributions."
    )
  }

  // MARK: - Subviews

  /// Header row with title and subtitle.
  private var headerRow: some View {
    HStack {
      Text("Contribution Activity")
        .font(.gpCardTitle)
        .foregroundStyle(Color.gpTextPrimary)

      Spacer()

      Text("Last 16 weeks")
        .font(.gpCaption)
        .foregroundStyle(Color.gpTextSecondary)
    }
  }

  /// The Swift Charts heatmap grid.
  private var chartBody: some View {
    Chart(cells) { cell in
      RectangleMark(
        xStart: .value("Week", cell.weekIndex),
        xEnd: .value("Week", cell.weekIndex + 1),
        yStart: .value("Day", cell.dayOfWeek),
        yEnd: .value("Day", cell.dayOfWeek + 1)
      )
      .foregroundStyle(heatmapColor(for: cell.level))
      .cornerRadius(DesignTokens.radiusHeatmap)
    }
    .chartXScale(domain: 0...16)
    .chartYScale(domain: 0...7)
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(values: [1, 3, 5]) { value in
        AxisValueLabel {
          if let intValue = value.as(Int.self) {
            Text(dayLabel(for: intValue))
              .font(.gpMicro)
              .foregroundStyle(Color.gpTextTertiary)
          }
        }
      }
    }
    .chartLegend(.hidden)
    .frame(height: 120)
    .animation(
      reduceMotion ? .none : .easeOut(duration: DesignTokens.animationChartDraw),
      value: cells.count
    )
  }

  /// Color legend showing the intensity scale from "Less" to "More".
  private var legendRow: some View {
    HStack(spacing: DesignTokens.spacingXXS) {
      Spacer()

      Text("Less")
        .font(.gpMicro)
        .foregroundStyle(Color.gpTextTertiary)

      ForEach(0..<5, id: \.self) { level in
        RoundedRectangle(cornerRadius: DesignTokens.radiusHeatmap)
          .fill(heatmapColor(for: level))
          .frame(width: 10, height: 10)
      }

      Text("More")
        .font(.gpMicro)
        .foregroundStyle(Color.gpTextTertiary)
    }
  }

  /// Footer showing the total contribution count.
  private var footerText: some View {
    Text("\(totalContributions) contributions in the last 16 weeks")
      .font(.gpCaption)
      .foregroundStyle(Color.gpTextSecondary)
  }

  /// Empty state when no contributions exist.
  private var emptyState: some View {
    Text("No contributions yet")
      .font(.gpBody)
      .foregroundStyle(Color.gpTextSecondary)
      .frame(maxWidth: .infinity, minHeight: 120)
      .multilineTextAlignment(.center)
  }

  // MARK: - Helpers

  /// Maps an intensity level (0-4) to the corresponding heatmap color.
  private func heatmapColor(for level: Int) -> Color {
    switch level {
    case 0: .heatmap0
    case 1: .heatmap1
    case 2: .heatmap2
    case 3: .heatmap3
    default: .heatmap4
    }
  }

  /// Returns an abbreviated day name for the given 0-based day-of-week index.
  private func dayLabel(for dayIndex: Int) -> String {
    switch dayIndex {
    case 1: "Mon"
    case 3: "Wed"
    case 5: "Fri"
    default: ""
    }
  }
}

// MARK: - Previews

#Preview("ContributionHeatmap — With Data") {
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: .now)
  let mockCells: [HeatmapCell] = (0..<112).map { offset in
    let date = calendar.date(byAdding: .day, value: offset - 111, to: today) ?? today
    let weekIndex = offset / 7
    let weekday = calendar.component(.weekday, from: date)
    let dayOfWeek = weekday - 1
    let count = Int.random(in: 0...15)
    let level: Int
    switch count {
    case 0: level = 0
    case 1...3: level = 1
    case 4...7: level = 2
    case 8...12: level = 3
    default: level = 4
    }
    return HeatmapCell(
      id: date,
      weekIndex: weekIndex,
      dayOfWeek: dayOfWeek,
      count: count,
      level: level
    )
  }

  ZStack {
    Color.gpBackground.ignoresSafeArea()

    ContributionHeatmap(cells: mockCells, totalContributions: 342)
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 800, height: 260)
}

#Preview("ContributionHeatmap — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    ContributionHeatmap(cells: [], totalContributions: 0)
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 800, height: 260)
}
