//  TrendArrow.swift
//  GitPulse

import SwiftUI

// MARK: - Trend Direction

/// Represents the direction of a metric trend.
///
/// Used by ``TrendArrow`` to display the appropriate SF Symbol and color
/// indicating whether a metric is increasing, decreasing, or unchanged.
enum TrendDirection: String, Sendable {
  case up
  case down
  case flat

  /// The SF Symbol name for this trend direction.
  var symbolName: String {
    switch self {
    case .up: "arrow.up.right"
    case .down: "arrow.down.right"
    case .flat: "arrow.right"
    }
  }

  /// The semantic color associated with this trend direction.
  var color: Color {
    switch self {
    case .up: .gpGreen
    case .down: .gpOrange
    case .flat: .gpTextSecondary
    }
  }

  /// A human-readable label for VoiceOver.
  var accessibilityDirectionLabel: String {
    switch self {
    case .up: "trending up"
    case .down: "trending down"
    case .flat: "flat"
    }
  }
}

// MARK: - TrendArrow View

/// A compact directional indicator showing whether a metric is trending up, down, or flat.
///
/// Displays an SF Symbol arrow alongside a delta value string (e.g., "+33%").
/// Colors are semantic: green for positive, orange for negative, secondary for flat.
///
/// ```swift
/// TrendArrow(direction: .up, value: "+33%")
/// TrendArrow(direction: .down, value: "-12%")
/// ```
struct TrendArrow: View {
  /// The trend direction to display.
  let direction: TrendDirection

  /// The delta value string (e.g., "+33%", "-5", "0%").
  let value: String

  var body: some View {
    HStack(spacing: DesignTokens.spacingXXS) {
      Image(systemName: direction.symbolName)
        .font(.system(size: 12))
        .foregroundStyle(direction.color)

      Text(value)
        .font(.gpCaption)
        .foregroundStyle(direction.color)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(direction.accessibilityDirectionLabel), \(value)")
  }
}

// MARK: - Previews

#Preview("TrendArrow — Up") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    TrendArrow(direction: .up, value: "+33%")
  }
  .frame(width: 120, height: 60)
}

#Preview("TrendArrow — Down") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    TrendArrow(direction: .down, value: "-12%")
  }
  .frame(width: 120, height: 60)
}

#Preview("TrendArrow — Flat") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    TrendArrow(direction: .flat, value: "0%")
  }
  .frame(width: 120, height: 60)
}

#Preview("TrendArrow — All Directions") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingSM) {
      TrendArrow(direction: .up, value: "+33%")
      TrendArrow(direction: .down, value: "-12%")
      TrendArrow(direction: .flat, value: "0%")
    }
  }
  .frame(width: 150, height: 120)
}
