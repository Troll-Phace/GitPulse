//  Color+Extensions.swift
//  GitPulse

import SwiftUI

// MARK: - Design System Colors

extension Color {
  // MARK: Base

  /// The app background color (#0D0D0F).
  static let gpBackground = Color(hex: "0D0D0F")

  /// The default glass card fill (white at 6% opacity).
  static let gpGlassFill = Color.white.opacity(0.06)

  /// The glass card stroke/border (white at 10% opacity).
  static let gpGlassBorder = Color.white.opacity(0.10)

  /// The glass highlight used on hover or pressed states (white at 15% opacity).
  static let gpGlassHighlight = Color.white.opacity(0.15)

  // MARK: Text

  /// Primary text color for headings and labels (white at 92% opacity).
  static let gpTextPrimary = Color.white.opacity(0.92)

  /// Secondary text color for captions and timestamps (white at 55% opacity).
  static let gpTextSecondary = Color.white.opacity(0.55)

  /// Tertiary text color for disabled or de-emphasized content (white at 35% opacity).
  static let gpTextTertiary = Color.white.opacity(0.35)

  // MARK: Accents

  /// GitHub green accent for contributions, streaks, and positive metrics.
  static let gpGreen = Color(hex: "39D353")

  /// Link blue accent for URLs, interactive elements, and open PR state.
  static let gpBlue = Color(hex: "58A6FF")

  /// Purple accent for merged PR state and language highlights.
  static let gpPurple = Color(hex: "BC8CFF")

  /// Orange accent for closed PR state, warnings, and streak-at-risk alerts.
  static let gpOrange = Color(hex: "F78166")

  /// Gold accent for milestones, achievements, and star counts.
  static let gpGold = Color(hex: "FFD700")

  /// Red accent for destructive actions, streak-at-risk today marker, and urgent warnings.
  static let gpRed = Color(hex: "FF453A")

  // MARK: Heatmap

  /// Heatmap level 0 — no contributions (#161B22).
  static let heatmap0 = Color(hex: "161B22")

  /// Heatmap level 1 — low activity (#0E4429).
  static let heatmap1 = Color(hex: "0E4429")

  /// Heatmap level 2 — moderate activity (#006D32).
  static let heatmap2 = Color(hex: "006D32")

  /// Heatmap level 3 — high activity (#26A641).
  static let heatmap3 = Color(hex: "26A641")

  /// Heatmap level 4 — very high activity (#39D353).
  static let heatmap4 = Color(hex: "39D353")
}

// MARK: - Hex Color Initializer

extension Color {
  /// Creates a `Color` from a hexadecimal string (e.g., `"39D353"` or `"#39D353"`).
  ///
  /// Strips any non-alphanumeric characters (such as `#`) before parsing.
  /// Expects a 6-character RGB hex string.
  ///
  /// - Parameter hex: A hexadecimal color string.
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255.0
    let g = Double((int >> 8) & 0xFF) / 255.0
    let b = Double(int & 0xFF) / 255.0
    self.init(red: r, green: g, blue: b)
  }
}
