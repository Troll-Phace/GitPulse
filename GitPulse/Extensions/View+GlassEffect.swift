//  View+GlassEffect.swift
//  GitPulse

import SwiftUI

// MARK: - Primary CTA Button Style

/// A button style for primary call-to-action buttons per DESIGN_SYSTEM.md section 5.6.
///
/// Renders a 48pt tall button with a green gradient background, black text,
/// and a press effect that scales to 0.97 with reduced opacity.
///
/// ```swift
/// Button("Get Started") { }
///     .buttonStyle(PrimaryCTAButtonStyle())
/// ```
struct PrimaryCTAButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.gpCardTitle)
      .foregroundStyle(.black)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(
        LinearGradient(
          colors: [Color.gpGreen, Color.gpGreen.opacity(0.8)],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton))
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .opacity(configuration.isPressed ? 0.9 : 1.0)
      .animation(
        reduceMotion
          ? .none
          : .easeOut(duration: DesignTokens.animationPressFeedback),
        value: configuration.isPressed
      )
  }
}

// MARK: - Secondary Button Style

/// A button style for secondary actions per DESIGN_SYSTEM.md section 5.7.
///
/// Renders a 40pt tall button with a glass effect background and primary-colored text.
///
/// ```swift
/// Button("Learn More") { }
///     .buttonStyle(SecondaryButtonStyle())
/// ```
struct SecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.gpBody)
      .foregroundStyle(Color.gpTextPrimary)
      .frame(maxWidth: .infinity)
      .frame(height: 40)
      .glassEffect()
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton))
      .opacity(configuration.isPressed ? 0.8 : 1.0)
  }
}

// MARK: - Destructive Button Style

/// A button style for destructive actions per DESIGN_SYSTEM.md section 5.8.
///
/// Renders a 40pt tall button with a translucent orange background, orange text,
/// and a subtle orange border.
///
/// ```swift
/// Button("Disconnect") { }
///     .buttonStyle(DestructiveButtonStyle())
/// ```
struct DestructiveButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.gpBody)
      .foregroundStyle(Color.gpOrange)
      .frame(maxWidth: .infinity)
      .frame(height: 40)
      .background(Color.gpOrange.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton))
      .overlay(
        RoundedRectangle(cornerRadius: DesignTokens.radiusButton)
          .stroke(Color.gpOrange.opacity(0.3), lineWidth: 1)
      )
      .opacity(configuration.isPressed ? 0.8 : 1.0)
  }
}

// MARK: - Step Indicator

/// A horizontal row of dots indicating progress through a multi-step flow.
///
/// The current step is highlighted in `gpGreen`; inactive steps use `gpGlassBorder`.
/// Transitions between steps are animated unless the user prefers reduced motion.
///
/// ```swift
/// StepIndicator(totalSteps: 4, currentStep: 2)
/// ```
struct StepIndicator: View {
  /// The total number of steps in the flow.
  let totalSteps: Int

  /// The zero-indexed current step.
  let currentStep: Int

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: DesignTokens.spacingXS) {
      ForEach(0..<totalSteps, id: \.self) { index in
        Circle()
          .fill(index == currentStep ? Color.gpGreen : Color.gpGlassBorder)
          .frame(width: 8, height: 8)
          .animation(
            reduceMotion
              ? .none
              : .easeInOut(duration: DesignTokens.animationStateTransition),
            value: currentStep
          )
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
  }
}

// MARK: - Onboarding Progress Bar

/// A segmented progress bar for the onboarding flow.
///
/// Displays `totalSteps` segments separated by small gaps. Completed and current
/// segments fill with `gpGreen`; upcoming segments use `gpGlassBorder`.
/// Fill changes are animated unless the user prefers reduced motion.
struct OnboardingProgressBar: View {
  /// The total number of steps in the flow.
  let totalSteps: Int

  /// The zero-indexed current step.
  let currentStep: Int

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(spacing: DesignTokens.spacingXXS) {
      ForEach(0..<totalSteps, id: \.self) { index in
        RoundedRectangle(cornerRadius: 1.5)
          .fill(index <= currentStep ? Color.gpGreen : Color.gpGlassBorder)
          .frame(height: 3)
          .animation(
            reduceMotion
              ? .none
              : .easeInOut(duration: DesignTokens.animationStateTransition),
            value: currentStep
          )
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Step \(currentStep + 1) of \(totalSteps)")
  }
}

// MARK: - Previews

#Preview("OnboardingProgressBar") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingLG) {
      OnboardingProgressBar(totalSteps: 4, currentStep: 0)
      OnboardingProgressBar(totalSteps: 4, currentStep: 1)
      OnboardingProgressBar(totalSteps: 4, currentStep: 2)
      OnboardingProgressBar(totalSteps: 4, currentStep: 3)
    }
    .padding(DesignTokens.spacingXL)
  }
  .frame(width: 400, height: 200)
}

#Preview("PrimaryCTAButtonStyle") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingMD) {
      Button("Get Started") {}
        .buttonStyle(PrimaryCTAButtonStyle())

      Button("Continue") {}
        .buttonStyle(PrimaryCTAButtonStyle())
    }
    .padding(DesignTokens.spacingXL)
  }
  .frame(width: 400, height: 200)
}

#Preview("SecondaryButtonStyle") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingMD) {
      Button("Learn More") {}
        .buttonStyle(SecondaryButtonStyle())

      Button("Skip for Now") {}
        .buttonStyle(SecondaryButtonStyle())
    }
    .padding(DesignTokens.spacingXL)
  }
  .frame(width: 400, height: 200)
}

#Preview("DestructiveButtonStyle") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    Button("Disconnect Account") {}
      .buttonStyle(DestructiveButtonStyle())
      .padding(DesignTokens.spacingXL)
  }
  .frame(width: 400, height: 150)
}

#Preview("StepIndicator") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingLG) {
      StepIndicator(totalSteps: 4, currentStep: 0)
      StepIndicator(totalSteps: 4, currentStep: 1)
      StepIndicator(totalSteps: 4, currentStep: 2)
      StepIndicator(totalSteps: 4, currentStep: 3)
    }
  }
  .frame(width: 200, height: 200)
}
