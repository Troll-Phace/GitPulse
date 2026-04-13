//  StatCardView.swift
//  GitPulse

import SwiftUI

// MARK: - StatCardsRow

/// Composes four `StatCard` instances into a horizontal row for the Dashboard.
///
/// Displays today's commits (with sparkline), active PRs, current streak
/// (with flame icon), and language count (with mini language bar).
/// Wrapped in a `GlassEffectContainer` so adjacent glass cards blend visually.
struct StatCardsRow: View {
  /// The dashboard view model providing computed stat values.
  let viewModel: DashboardViewModel

  var body: some View {
    GlassEffectContainer {
      HStack(spacing: DesignTokens.spacingSM) {
        // Card 1: Today's Commits
        StatCard(
          title: "Today's Commits",
          value: "\(viewModel.todayCommitCount)",
          accentColor: .gpBlue,
          trendDirection: viewModel.todayCommitTrend,
          trendValue: viewModel.todayCommitTrendValue
        ) {
          SparklineView(data: viewModel.recentCommitSparkline, color: .gpBlue)
        }

        // Card 2: Active PRs
        StatCard(
          title: "Active PRs",
          value: "\(viewModel.activePRCount)",
          accentColor: .gpGreen,
          subtitle: "\(viewModel.inReviewCount) in review"
        )

        // Card 3: Current Streak
        StatCard(
          title: "Current Streak",
          value: "\(viewModel.currentStreak)",
          accentColor: .gpOrange,
          subtitle: "Best: \(viewModel.longestStreak)d"
        ) {
          Image(systemName: "flame.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color.gpOrange.opacity(0.6))
        }

        // Card 4: Languages Used
        StatCard(
          title: "Languages",
          value: "\(viewModel.languageCount)",
          accentColor: .gpPurple,
          subtitle: viewModel.topLanguage.map { "\($0.name) \(Int($0.percentage))%" }
        ) {
          LanguageMiniBar(segments: viewModel.languageBarSegments)
        }
      }
    }
  }
}

// MARK: - LanguageMiniBar

/// A compact horizontal bar showing proportional language segments.
///
/// Each segment is colored according to its language's GitHub color and sized
/// proportionally by byte fraction. The bar has a fixed 80x4pt frame with
/// rounded corners.
struct LanguageMiniBar: View {
  /// The language segments with name, fraction (0.0-1.0), and color.
  let segments: [(name: String, fraction: Double, color: Color)]

  /// Fixed width of the mini bar.
  private static let barWidth: CGFloat = 80

  /// Fixed height of the mini bar.
  private static let barHeight: CGFloat = 4

  var body: some View {
    if segments.isEmpty {
      RoundedRectangle(cornerRadius: Self.barHeight / 2)
        .fill(Color.gpGlassFill)
        .frame(width: Self.barWidth, height: Self.barHeight)
    } else {
      GeometryReader { _ in
        HStack(spacing: 0) {
          ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
            Rectangle()
              .fill(segment.color)
              .frame(width: max(Self.barWidth * segment.fraction, 1))
          }
        }
        .clipShape(Capsule())
      }
      .frame(width: Self.barWidth, height: Self.barHeight)
      .accessibilityHidden(true)
    }
  }
}

// MARK: - Previews

#Preview("StatCardsRow") {
  let viewModel = DashboardViewModel()

  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StatCardsRow(viewModel: viewModel)
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 1000, height: 160)
}

#Preview("LanguageMiniBar") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingSM) {
      LanguageMiniBar(segments: [
        (name: "Swift", fraction: 0.6, color: Color(hex: "F05138")),
        (name: "Python", fraction: 0.25, color: Color(hex: "3572A5")),
        (name: "JavaScript", fraction: 0.15, color: Color(hex: "F1E05A")),
      ])

      LanguageMiniBar(segments: [])
    }
    .padding(DesignTokens.spacingLG)
  }
  .frame(width: 200, height: 80)
}
