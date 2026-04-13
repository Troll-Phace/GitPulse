//  DesignTokens.swift
//  GitPulse

import SwiftUI

// MARK: - Design Tokens

/// Centralized design token constants for spacing, corner radius, sizing, and animation timing.
///
/// All UI components should reference these tokens rather than using hardcoded values
/// to ensure consistency with the GitPulse design system.
enum DesignTokens {
  // MARK: Spacing

  /// Extra-extra-small spacing (4pt).
  static let spacingXXS: CGFloat = 4

  /// Extra-small spacing (8pt).
  static let spacingXS: CGFloat = 8

  /// Small spacing (12pt).
  static let spacingSM: CGFloat = 12

  /// Medium spacing (16pt).
  static let spacingMD: CGFloat = 16

  /// Large spacing (20pt).
  static let spacingLG: CGFloat = 20

  /// Extra-large spacing (24pt).
  static let spacingXL: CGFloat = 24

  /// Extra-extra-large spacing (32pt).
  static let spacingXXL: CGFloat = 32

  // MARK: Corner Radius

  /// Corner radius for glass cards (20pt).
  static let radiusCard: CGFloat = 20

  /// Corner radius for stat cards (18pt).
  static let radiusStat: CGFloat = 18

  /// Corner radius for buttons (16pt).
  static let radiusButton: CGFloat = 16

  /// Corner radius for badges (fully rounded).
  static let radiusBadge: CGFloat = .infinity

  /// Corner radius for heatmap cells (3pt).
  static let radiusHeatmap: CGFloat = 3

  /// Corner radius for small elements (8pt).
  static let radiusMini: CGFloat = 8

  // MARK: Sizes

  /// The sidebar width in the navigation split view (220pt).
  static let sidebarWidth: CGFloat = 220

  /// Minimum window width (900pt).
  static let minWindowWidth: CGFloat = 900

  /// Minimum window height (600pt).
  static let minWindowHeight: CGFloat = 600

  /// Standard stat card height (90pt).
  static let statCardHeight: CGFloat = 90

  /// Standard repo card height (80pt).
  static let repoCardHeight: CGFloat = 80

  /// Standard PR card height (72pt).
  static let prCardHeight: CGFloat = 72

  /// Individual heatmap cell size (14pt).
  static let heatmapCellSize: CGFloat = 14

  /// Gap between heatmap cells (3pt).
  static let heatmapCellGap: CGFloat = 3

  /// Streak ring outer diameter (200pt).
  static let streakRingSize: CGFloat = 200

  /// Streak ring stroke line width (12pt).
  static let streakRingLineWidth: CGFloat = 12

  // MARK: Animation

  /// Duration for state transitions such as loading/loaded/error (0.25s).
  static let animationStateTransition: Double = 0.25

  /// Duration for data-load animations like stat card count-up (0.4s).
  static let animationDataLoad: Double = 0.4

  /// Duration for chart draw-in animations (0.6s).
  static let animationChartDraw: Double = 0.6

  /// Duration for the streak ring fill animation (0.8s).
  static let animationStreakRing: Double = 0.8

  /// Duration for tab/navigation transitions (0.2s).
  static let animationTabTransition: Double = 0.2

  /// Duration for button press feedback (0.1s).
  static let animationPressFeedback: Double = 0.1

  /// Duration for hover highlight effects (0.15s).
  static let animationHoverHighlight: Double = 0.15
}

// MARK: - Font Extensions

extension Font {
  /// Hero number display (48pt bold) — used for large streak counts and primary metrics.
  static let gpHeroNumber = Font.system(size: 48, weight: .bold, design: .default)

  /// Page title (34pt bold) — used for top-level view titles.
  static let gpPageTitle = Font.system(size: 34, weight: .bold, design: .default)

  /// Section header (22pt semibold) — used for grouping content within a view.
  static let gpSectionHeader = Font.system(size: 22, weight: .semibold, design: .default)

  /// Card title (17pt semibold) — used for titles within glass cards.
  static let gpCardTitle = Font.system(size: 17, weight: .semibold, design: .default)

  /// Body text (15pt regular) — used for standard content and descriptions.
  static let gpBody = Font.system(size: 15, weight: .regular, design: .default)

  /// Caption text (13pt regular) — used for timestamps, secondary labels, and metadata.
  static let gpCaption = Font.system(size: 13, weight: .regular, design: .default)

  /// Micro text (11pt medium) — used for badges, tags, and compact labels.
  static let gpMicro = Font.system(size: 11, weight: .medium, design: .default)

  /// Code text (13pt monospaced) — used for commit hashes, code snippets, and technical values.
  static let gpCode = Font.system(size: 13, weight: .regular, design: .monospaced)
}
