//  StatCard.swift
//  GitPulse

import SwiftUI

// MARK: - StatCard

/// A metric display card showing a title, large value, and optional trend indicator and accessory view.
///
/// StatCard is the primary building block for the Dashboard's top stat row. It uses
/// Liquid Glass styling with a colored accent bar at the top-left corner. The generic
/// `Accessory` parameter allows embedding any trailing view such as a ``SparklineView``,
/// an SF Symbol icon, or a mini language bar.
///
/// ```swift
/// StatCard(title: "Today's Commits", value: "12", accentColor: .gpGreen) {
///     SparklineView(data: recentData)
/// }
///
/// StatCard(
///     title: "Current Streak",
///     value: "14d",
///     accentColor: .gpOrange,
///     subtitle: "Best: 47d"
/// ) {
///     Image(systemName: "flame.fill")
///         .foregroundStyle(Color.gpOrange)
/// }
/// ```
struct StatCard<Accessory: View>: View {
  /// The label describing the metric (e.g., "Today's Commits").
  let title: String

  /// The large display value (e.g., "12", "14d").
  let value: String

  /// The color for the top accent bar.
  let accentColor: Color

  /// An optional secondary label below the value (e.g., "Best: 47d").
  var subtitle: String? = nil

  /// The optional trend direction for the trend indicator.
  var trendDirection: TrendDirection? = nil

  /// The optional trend delta value string (e.g., "+33%").
  var trendValue: String? = nil

  /// A custom trailing view (sparkline, icon, mini chart, etc.).
  let accessory: Accessory

  /// Creates a stat card with the given metric data and an accessory view.
  ///
  /// - Parameters:
  ///   - title: The metric label.
  ///   - value: The metric value to display prominently.
  ///   - accentColor: The color for the top accent bar.
  ///   - subtitle: An optional secondary label below the value.
  ///   - trendDirection: The optional trend direction.
  ///   - trendValue: The optional trend delta string.
  ///   - accessory: A view builder producing the trailing accessory.
  init(
    title: String,
    value: String,
    accentColor: Color,
    subtitle: String? = nil,
    trendDirection: TrendDirection? = nil,
    trendValue: String? = nil,
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.title = title
    self.value = value
    self.accentColor = accentColor
    self.subtitle = subtitle
    self.trendDirection = trendDirection
    self.trendValue = trendValue
    self.accessory = accessory()
  }

  // MARK: Constants

  /// Width of the accent bar at the top-left of the card.
  private static var accentBarWidth: CGFloat { 40 }

  /// Height of the accent bar.
  private static var accentBarHeight: CGFloat { 2 }

  /// Vertical offset from the top edge for the accent bar.
  private static var accentBarTopOffset: CGFloat { 0 }

  /// Horizontal offset from the leading edge for the accent bar.
  private static var accentBarLeadingOffset: CGFloat { DesignTokens.spacingMD }

  var body: some View {
    ZStack(alignment: .topLeading) {
      // Content
      HStack(alignment: .center, spacing: DesignTokens.spacingXS) {
        metricContent
        Spacer()
        accessory
      }
      .padding(DesignTokens.spacingMD)

      // Top accent bar
      RoundedRectangle(cornerRadius: 1)
        .fill(accentColor)
        .frame(width: Self.accentBarWidth, height: Self.accentBarHeight)
        .offset(
          x: Self.accentBarLeadingOffset,
          y: Self.accentBarTopOffset
        )
    }
    .frame(height: DesignTokens.statCardHeight)
    .glassEffect(in: .rect(cornerRadius: DesignTokens.radiusStat))
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusStat))
    .accessibilityElement(children: .combine)
  }

  // MARK: - Subviews

  /// The left-aligned metric content stack: title, value, optional subtitle, optional trend.
  private var metricContent: some View {
    VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
      Text(title)
        .font(.gpMicro)
        .foregroundStyle(Color.gpTextSecondary)
        .lineLimit(1)
        .minimumScaleFactor(0.75)

      Text(value)
        .font(.gpStatValue)
        .foregroundStyle(Color.gpTextPrimary)

      if let subtitle {
        Text(subtitle)
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextSecondary)
      }

      if let trendDirection, let trendValue {
        TrendArrow(direction: trendDirection, value: trendValue)
      }
    }
  }
}

// MARK: - Convenience Initializer (No Accessory)

extension StatCard where Accessory == EmptyView {
  /// Creates a stat card without a trailing accessory view.
  ///
  /// - Parameters:
  ///   - title: The metric label.
  ///   - value: The metric value to display prominently.
  ///   - accentColor: The color for the top accent bar.
  ///   - subtitle: An optional secondary label below the value.
  ///   - trendDirection: The optional trend direction.
  ///   - trendValue: The optional trend delta string.
  init(
    title: String,
    value: String,
    accentColor: Color,
    subtitle: String? = nil,
    trendDirection: TrendDirection? = nil,
    trendValue: String? = nil
  ) {
    self.init(
      title: title,
      value: value,
      accentColor: accentColor,
      subtitle: subtitle,
      trendDirection: trendDirection,
      trendValue: trendValue
    ) {
      EmptyView()
    }
  }
}

// MARK: - Previews

#Preview("StatCard — With Trend") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StatCard(
      title: "Today's Commits",
      value: "12",
      accentColor: .gpGreen,
      trendDirection: .up,
      trendValue: "+33%"
    ) {
      SparklineView(data: [3, 5, 2, 8, 6, 7, 4, 9, 5, 6, 8, 3, 7, 10])
    }
    .frame(width: 240)
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 300, height: 160)
}

#Preview("StatCard — With Subtitle") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StatCard(
      title: "Current Streak",
      value: "14d",
      accentColor: .gpOrange,
      subtitle: "Best: 47d"
    ) {
      Image(systemName: "flame.fill")
        .font(.system(size: 24))
        .foregroundStyle(Color.gpOrange)
    }
    .frame(width: 240)
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 300, height: 160)
}

#Preview("StatCard — With Sparkline Accessory") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StatCard(
      title: "Active PRs",
      value: "3",
      accentColor: .gpBlue,
      trendDirection: .down,
      trendValue: "-1"
    ) {
      SparklineView(data: [1, 4, 2, 6, 3, 5, 3], color: .gpBlue)
    }
    .frame(width: 240)
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 300, height: 160)
}

#Preview("StatCard — Minimal") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StatCard(
      title: "Languages Used",
      value: "6",
      accentColor: .gpPurple
    )
    .frame(width: 240)
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 300, height: 160)
}

#Preview("StatCard — Row of Cards") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    GlassEffectContainer {
      HStack(spacing: DesignTokens.spacingSM) {
        StatCard(
          title: "Today's Commits",
          value: "12",
          accentColor: .gpGreen,
          trendDirection: .up,
          trendValue: "+33%"
        ) {
          SparklineView(data: [3, 5, 2, 8, 6, 7, 4, 9, 5, 6])
        }

        StatCard(
          title: "Active PRs",
          value: "3",
          accentColor: .gpBlue
        )

        StatCard(
          title: "Current Streak",
          value: "14d",
          accentColor: .gpOrange,
          subtitle: "Best: 47d"
        ) {
          Image(systemName: "flame.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color.gpOrange)
        }

        StatCard(
          title: "Languages",
          value: "6",
          accentColor: .gpPurple
        )
      }
      .padding(DesignTokens.spacingMD)
    }
  }
  .frame(width: 1000, height: 160)
}
