//  WelcomeStep.swift
//  GitPulse

import SwiftUI

/// The first step of onboarding, introducing the app and its key features.
///
/// Displays a hero icon cluster, a large welcome title, a concise subtitle,
/// three pill-shaped feature badges, and a "Get Started" call-to-action button.
/// All elements animate in with staggered spring timing.
struct WelcomeStep: View {
  /// Called when the user taps "Get Started" to advance to the next step.
  var onContinue: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAppeared = false

  var body: some View {
    GeometryReader { geo in
      let contentWidth = min(geo.size.width * 0.7, 560)

      VStack(spacing: DesignTokens.spacingXL) {
        Spacer()

        // MARK: Hero Icon Cluster
        ZStack {
          HeroCircle(
            icon: "folder.fill",
            tint: Color.gpPurple,
            size: 56
          )
          .offset(x: 30, y: 20)
          .opacity(isAppeared ? 1 : 0)
          .scaleEffect(isAppeared ? 1 : 0.5)
          .animation(animationForDelay(0.2), value: isAppeared)

          HeroCircle(
            icon: "chart.bar.fill",
            tint: Color.gpBlue,
            size: 56
          )
          .offset(x: -30, y: 20)
          .opacity(isAppeared ? 1 : 0)
          .scaleEffect(isAppeared ? 1 : 0.5)
          .animation(animationForDelay(0.1), value: isAppeared)

          HeroCircle(
            icon: "flame.fill",
            tint: Color.gpGreen,
            size: 56
          )
          .offset(x: 0, y: -20)
          .opacity(isAppeared ? 1 : 0)
          .scaleEffect(isAppeared ? 1 : 0.5)
          .animation(animationForDelay(0.0), value: isAppeared)
        }
        .frame(height: 96)
        .accessibilityHidden(true)

        // MARK: Title & Subtitle
        VStack(spacing: DesignTokens.spacingXS) {
          Text("Welcome to GitPulse")
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(Color.gpTextPrimary)
            .multilineTextAlignment(.center)

          Text("Your GitHub activity, visualized.")
            .font(.gpBody)
            .foregroundStyle(Color.gpTextSecondary)
            .multilineTextAlignment(.center)
        }
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 10)
        .animation(animationForDelay(0.25), value: isAppeared)

        // MARK: Feature Badges
        HStack(spacing: DesignTokens.spacingSM) {
          FeatureBadge(icon: "flame.fill", label: "Streaks")
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 10)
            .animation(animationForDelay(0.35), value: isAppeared)

          FeatureBadge(icon: "chart.bar.fill", label: "Insights")
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 10)
            .animation(animationForDelay(0.4), value: isAppeared)

          FeatureBadge(icon: "folder.fill", label: "Repos")
            .opacity(isAppeared ? 1 : 0)
            .offset(y: isAppeared ? 0 : 10)
            .animation(animationForDelay(0.45), value: isAppeared)
        }

        Spacer()

        // MARK: CTA Button
        Button("Get Started") {
          onContinue()
        }
        .buttonStyle(PrimaryCTAButtonStyle())
        .frame(maxWidth: .infinity)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 10)
        .animation(animationForDelay(0.5), value: isAppeared)
        .accessibilityLabel("Get started with GitPulse setup")
      }
      .frame(width: contentWidth)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(DesignTokens.spacingXXL)
    .onAppear {
      if reduceMotion {
        isAppeared = true
      } else {
        withAnimation {
          isAppeared = true
        }
      }
    }
  }

  /// Returns a spring animation with a given delay, or `.none` if reduced motion is on.
  private func animationForDelay(_ delay: Double) -> Animation? {
    reduceMotion
      ? .none
      : .spring(response: 0.5, dampingFraction: 0.8).delay(delay)
  }
}

// MARK: - Hero Circle

/// A glass circle containing an SF Symbol, used in the welcome hero cluster.
private struct HeroCircle: View {
  let icon: String
  let tint: Color
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(tint.opacity(0.08))
        .frame(width: size, height: size)
        .glassEffect()
        .clipShape(Circle())

      Image(systemName: icon)
        .font(.system(size: size * 0.4))
        .foregroundStyle(tint)
    }
  }
}

// MARK: - Feature Badge

/// A pill-shaped glass badge with an icon and label for feature highlights.
private struct FeatureBadge: View {
  let icon: String
  let label: String

  var body: some View {
    HStack(spacing: DesignTokens.spacingXXS) {
      Image(systemName: icon)
        .font(.gpCaption)
        .foregroundStyle(Color.gpGreen)
        .accessibilityHidden(true)

      Text(label)
        .font(.gpCaption)
        .foregroundStyle(Color.gpTextPrimary)
    }
    .padding(.horizontal, DesignTokens.spacingSM)
    .padding(.vertical, DesignTokens.spacingXS)
    .glassEffect()
    .clipShape(Capsule())
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Previews

#Preview("WelcomeStep") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()
    WelcomeStep(onContinue: {})
  }
  .frame(width: 700, height: 600)
}
