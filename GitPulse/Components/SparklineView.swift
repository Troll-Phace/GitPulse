//  SparklineView.swift
//  GitPulse

import SwiftUI

// MARK: - SparklineView

/// A miniature line chart for visualizing recent activity trends.
///
/// Renders a smooth line through the provided data points, scaled to fit
/// the fixed 60x24pt frame. Intended as a decorative accessory inside
/// stat cards and repo cards.
///
/// ```swift
/// SparklineView(data: [3, 5, 2, 8, 6, 7, 4])
/// SparklineView(data: recentCommits, color: .gpBlue)
/// ```
struct SparklineView: View {
  /// The data points to plot. Each value represents one time unit.
  let data: [Double]

  /// The stroke color for the sparkline. Defaults to GitHub green.
  var color: Color = .gpGreen

  // MARK: Constants

  /// Fixed width for the sparkline frame.
  private static let sparklineWidth: CGFloat = 60

  /// Fixed height for the sparkline frame.
  private static let sparklineHeight: CGFloat = 24

  /// Stroke line width for the sparkline path.
  private static let strokeWidth: CGFloat = 1.5

  var body: some View {
    Canvas { context, size in
      drawSparkline(in: context, size: size)
    }
    .frame(width: Self.sparklineWidth, height: Self.sparklineHeight)
    .accessibilityHidden(true)
  }

  // MARK: - Drawing

  /// Draws the sparkline path onto the given canvas context.
  private func drawSparkline(in context: GraphicsContext, size: CGSize) {
    guard !data.isEmpty else { return }

    // Single point: draw a centered dot
    if data.count == 1 {
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let dotPath = Path(
        ellipseIn: CGRect(
          x: center.x - Self.strokeWidth,
          y: center.y - Self.strokeWidth,
          width: Self.strokeWidth * 2,
          height: Self.strokeWidth * 2
        ))
      context.fill(dotPath, with: .color(color))
      return
    }

    let minValue = data.min() ?? 0
    let maxValue = data.max() ?? 0
    let range = maxValue - minValue

    let points = data.enumerated().map { index, value in
      let x = size.width * CGFloat(index) / CGFloat(data.count - 1)
      let y: CGFloat
      if range == 0 {
        // All values are the same: flat line at center
        y = size.height / 2
      } else {
        // Scale value to fill height (top = max, bottom = min)
        y = size.height - (CGFloat((value - minValue) / range) * size.height)
      }
      return CGPoint(x: x, y: y)
    }

    var path = Path()
    path.move(to: points[0])
    for point in points.dropFirst() {
      path.addLine(to: point)
    }

    context.stroke(
      path,
      with: .color(color),
      lineWidth: Self.strokeWidth
    )
  }
}

// MARK: - Previews

#Preview("SparklineView — Normal") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    SparklineView(data: [3, 5, 2, 8, 6, 7, 4, 9, 5, 6, 8, 3, 7, 10])
  }
  .frame(width: 120, height: 60)
}

#Preview("SparklineView — Single Point") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    SparklineView(data: [5])
  }
  .frame(width: 120, height: 60)
}

#Preview("SparklineView — Flat") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    SparklineView(data: [4, 4, 4, 4, 4, 4, 4])
  }
  .frame(width: 120, height: 60)
}

#Preview("SparklineView — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    SparklineView(data: [])
  }
  .frame(width: 120, height: 60)
}

#Preview("SparklineView — Blue Color") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    SparklineView(data: [1, 4, 2, 6, 3, 8, 5, 7], color: .gpBlue)
  }
  .frame(width: 120, height: 60)
}
