//  StreakRingView.swift
//  GitPulse

import SwiftUI

// MARK: - Streak Arc Shape

/// An animatable arc shape used as the progress indicator in the streak ring.
///
/// Draws a circular arc from the 12 o'clock position (top) clockwise, with the
/// sweep determined by `progress` (0.0 to 1.0). Conforms to `Animatable` so
/// SwiftUI can interpolate the arc smoothly during state transitions.
private struct StreakArc: Shape, Animatable {
  /// The fraction of the full circle to draw, from 0.0 (no arc) to 1.0 (full circle).
  var progress: Double

  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    var path = Path()
    path.addArc(
      center: center,
      radius: radius,
      startAngle: .degrees(-90),
      endAngle: .degrees(-90 + 360 * progress),
      clockwise: false
    )
    return path
  }
}

// MARK: - Streak Ring View

/// A hero ring visualization showing the user's current streak progress toward a goal.
///
/// Displays a circular progress arc with a warm orange-to-red gradient, a flame icon
/// at center, the streak count in large bold text, and a "day streak" subtitle.
/// The arc animates from zero to the target progress on appear, respecting the
/// user's reduced-motion accessibility preference.
///
/// ```swift
/// StreakRingView(currentStreak: 14, goal: 30, isActiveToday: true)
/// ```
struct StreakRingView: View {
  /// The user's current consecutive-day streak count.
  let currentStreak: Int

  /// The streak goal (e.g., longest streak or a user-set target). Used to compute
  /// the progress fraction; the arc fills fully when `currentStreak >= goal`.
  let goal: Int

  /// Whether the user has made at least one contribution today.
  let isActiveToday: Bool

  // MARK: Private State

  @State private var animatedProgress: Double = 0
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The target progress fraction, clamped to 0...1.
  private var goalProgress: Double {
    min(Double(currentStreak) / Double(max(goal, 1)), 1.0)
  }

  // MARK: Body

  var body: some View {
    ZStack {
      // Background track ring
      Circle()
        .stroke(Color(hex: "3A3A3C"), lineWidth: DesignTokens.streakRingLineWidth - 4)

      // Progress arc with gradient and glow
      StreakArc(progress: animatedProgress)
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [Color(hex: "FF9F0A"), Color(hex: "FF453A")]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * goalProgress)
          ),
          style: StrokeStyle(
            lineWidth: DesignTokens.streakRingLineWidth,
            lineCap: .round
          )
        )
        .shadow(color: Color(hex: "FF9F0A").opacity(0.35), radius: 6)

      // Inner content: flame icon, streak number, subtitle
      VStack(spacing: DesignTokens.spacingXXS) {
        Image(systemName: "flame.fill")
          .font(.system(size: 28))
          .foregroundStyle(
            .linearGradient(
              colors: [Color(hex: "FFD60A"), Color(hex: "FF9F0A"), Color(hex: "FF453A")],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .shadow(color: Color(hex: "FF9F0A").opacity(0.5), radius: 12)

        Text("\(currentStreak)")
          .font(.gpHeroNumber)
          .foregroundStyle(Color.gpTextPrimary)

        Text("day streak")
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
      }
    }
    .frame(width: DesignTokens.streakRingSize, height: DesignTokens.streakRingSize)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Current streak: \(currentStreak) days. Goal: \(goal) days. \(Int(goalProgress * 100)) percent complete."
    )
    .task {
      if reduceMotion {
        animatedProgress = goalProgress
      } else {
        withAnimation(
          .spring(response: DesignTokens.animationStreakRing, dampingFraction: 0.7)
        ) {
          animatedProgress = goalProgress
        }
      }
    }
    .onChange(of: currentStreak) {
      if reduceMotion {
        animatedProgress = goalProgress
      } else {
        withAnimation(
          .spring(response: DesignTokens.animationStreakRing, dampingFraction: 0.7)
        ) {
          animatedProgress = goalProgress
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("Streak Ring — Active") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakRingView(currentStreak: 14, goal: 30, isActiveToday: true)
  }
  .frame(width: 300, height: 300)
}

#Preview("Streak Ring — Full") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakRingView(currentStreak: 30, goal: 30, isActiveToday: true)
  }
  .frame(width: 300, height: 300)
}

#Preview("Streak Ring — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakRingView(currentStreak: 0, goal: 30, isActiveToday: false)
  }
  .frame(width: 300, height: 300)
}
