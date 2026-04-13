//  LanguageDonutChart.swift
//  GitPulse

import Charts
import SwiftUI

/// A donut chart showing language distribution across all tracked repositories,
/// with an interactive custom legend alongside the chart.
///
/// The chart uses `SectorMark` with an inner radius cutout to create the donut shape.
/// A center overlay displays a summary metric (e.g. total lines of code).
/// The legend lists each language with its color swatch and percentage.
struct LanguageDonutChart: View {

  /// The language slices to display in the donut chart.
  let slices: [LanguageSlice]

  /// The primary text displayed in the center of the donut (e.g. "142K").
  let centerText: String

  /// The secondary text displayed below the center text (e.g. "lines of code").
  let centerSubtext: String

  /// The total number of repositories, shown in the subtitle.
  var repoCount: Int = 0

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hasAppeared = false

  var body: some View {
    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
      // Section header
      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
        Text("Language Distribution")
          .font(.gpSectionHeader)
          .foregroundStyle(Color.gpTextPrimary)

        Text("Across all \(repoCount) repositories")
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
      }

      GlassCard {
        if slices.isEmpty {
          emptyState
        } else {
          chartContent
        }
      }
    }
  }

  // MARK: - Chart Content

  @ViewBuilder
  private var chartContent: some View {
    HStack(alignment: .center, spacing: DesignTokens.spacingLG) {
      // Donut chart
      Chart(slices) { slice in
        SectorMark(
          angle: .value("Bytes", hasAppeared ? slice.bytes : 0),
          innerRadius: .ratio(0.6),
          angularInset: 1.0
        )
        .foregroundStyle(slice.color)
      }
      .chartLegend(.hidden)
      .chartBackground { proxy in
        GeometryReader { geometry in
          let frame = geometry.frame(in: .local)
          VStack(spacing: DesignTokens.spacingXXS) {
            Text(centerText)
              .font(.gpSectionHeader)
              .foregroundStyle(Color.gpTextPrimary)

            Text(centerSubtext)
              .font(.gpCaption)
              .foregroundStyle(Color.gpTextSecondary)
          }
          .position(x: frame.midX, y: frame.midY)
        }
      }
      .frame(width: 160, height: 160)
      .accessibilityLabel("Language distribution chart")
      .accessibilityElement(children: .combine)

      // Custom legend
      VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
        ForEach(slices) { slice in
          HStack(spacing: DesignTokens.spacingXS) {
            Circle()
              .fill(slice.color)
              .frame(width: 10, height: 10)

            Text(slice.name)
              .font(.gpCaption)
              .foregroundStyle(Color.gpTextPrimary)

            Spacer()

            Text(String(format: "%.0f%%", slice.percentage))
              .font(.gpCaption.weight(.semibold))
              .foregroundStyle(Color.gpTextPrimary)
          }
          .accessibilityElement(children: .combine)
        }
      }
      .frame(width: 160)
    }
    .onAppear {
      withAnimation(reduceMotion ? .none : .easeOut(duration: DesignTokens.animationChartDraw)) {
        hasAppeared = true
      }
    }
  }

  // MARK: - Empty State

  @ViewBuilder
  private var emptyState: some View {
    VStack(spacing: DesignTokens.spacingXS) {
      Image(systemName: "chart.pie")
        .font(.system(size: 32))
        .foregroundStyle(Color.gpTextTertiary)

      Text("No language data")
        .font(.gpCaption)
        .foregroundStyle(Color.gpTextTertiary)
    }
    .frame(maxWidth: .infinity, minHeight: 160)
  }
}

// MARK: - Previews

#Preview("LanguageDonutChart — With Data") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    LanguageDonutChart(
      slices: [
        LanguageSlice(
          id: "Swift", name: "Swift", bytes: 62_480, percentage: 44, color: Color(hex: "F05138")),
        LanguageSlice(
          id: "TypeScript", name: "TypeScript", bytes: 31_240, percentage: 22,
          color: Color(hex: "3178C6")),
        LanguageSlice(
          id: "Rust", name: "Rust", bytes: 19_880, percentage: 14, color: Color(hex: "DEA584")),
        LanguageSlice(
          id: "Python", name: "Python", bytes: 11_360, percentage: 8, color: Color(hex: "3572A5")),
        LanguageSlice(
          id: "Go", name: "Go", bytes: 8_520, percentage: 6, color: Color(hex: "00ADD8")),
        LanguageSlice(
          id: "Other", name: "Other", bytes: 8_520, percentage: 6, color: Color(hex: "808080")),
      ],
      centerText: "142K",
      centerSubtext: "lines of code",
      repoCount: 24
    )
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 520, height: 320)
}

#Preview("LanguageDonutChart — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    LanguageDonutChart(
      slices: [],
      centerText: "0",
      centerSubtext: "lines of code",
      repoCount: 0
    )
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 520, height: 320)
}
