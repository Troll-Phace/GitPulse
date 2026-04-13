//  OnboardingFlow.swift
//  GitPulse

import SwiftUI

/// The container view that orchestrates the 4-step onboarding flow.
///
/// Owns the `OnboardingViewModel`, renders the appropriate step view based
/// on the current step, displays a segmented progress bar, and applies
/// slide + scale transitions between steps with reduced-motion support.
struct OnboardingFlow: View {
  /// The view model managing onboarding state and step progression.
  @State private var viewModel: OnboardingViewModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Creates an onboarding flow that calls `onComplete` when the user finishes setup.
  ///
  /// - Parameter onComplete: A closure invoked when onboarding is fully completed,
  ///   typically used to flip an `@AppStorage` flag.
  init(onComplete: @escaping () -> Void) {
    let vm = OnboardingViewModel()
    vm.onComplete = onComplete
    _viewModel = State(initialValue: vm)
  }

  var body: some View {
    ZStack {
      Color.gpBackground.ignoresSafeArea()

      // Subtle radial gradient accent
      RadialGradient(
        colors: [Color.gpGreen.opacity(0.03), Color.clear],
        center: .center,
        startRadius: 50,
        endRadius: 400
      )
      .ignoresSafeArea()

      VStack(spacing: DesignTokens.spacingLG) {
        // MARK: Step Content
        Group {
          switch viewModel.currentStep {
          case .welcome:
            WelcomeStep {
              viewModel.advanceStep()
            }
          case .tokenSetup:
            TokenSetupStep(viewModel: viewModel)
          case .repoSelection:
            RepoSelectionStep(viewModel: viewModel)
          case .completion:
            CompletionStep(viewModel: viewModel)
          }
        }
        .id(viewModel.currentStep)
        .transition(
          reduceMotion
            ? .opacity
            : .asymmetric(
              insertion: .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.02)),
              removal: .move(edge: .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98))
            )
        )
        .animation(
          reduceMotion
            ? .none
            : .easeInOut(duration: DesignTokens.animationTabTransition),
          value: viewModel.currentStep
        )

        // MARK: Progress Bar
        OnboardingProgressBar(
          totalSteps: 4,
          currentStep: viewModel.currentStep.rawValue
        )
        .padding(.horizontal, DesignTokens.spacingXXL)
        .padding(.bottom, DesignTokens.spacingMD)
      }
    }
  }
}

// MARK: - Previews

#Preview("OnboardingFlow") {
  OnboardingFlow(onComplete: {})
    .frame(width: 700, height: 600)
}
