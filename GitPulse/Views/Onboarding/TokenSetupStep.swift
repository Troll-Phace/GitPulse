//  TokenSetupStep.swift
//  GitPulse

import SwiftUI

/// The second step of onboarding, where the user enters and validates their GitHub PAT.
///
/// Displays a consolidated instruction panel with numbered steps, a token input field
/// with integrated paste button and validation glow, and a "Validate & Continue" button.
/// Includes a shake animation on validation errors.
struct TokenSetupStep: View {
  /// The onboarding view model driving state for token input, validation, and errors.
  @Bindable var viewModel: OnboardingViewModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAppeared = false
  @State private var shakeOffset: CGFloat = 0
  @State private var glowOpacity: Double = 0

  var body: some View {
    GeometryReader { geo in
      let contentWidth = min(geo.size.width * 0.7, 560)

      ZStack(alignment: .topLeading) {
        // MARK: Back Button
        Button {
          viewModel.goBackStep()
        } label: {
          HStack(spacing: DesignTokens.spacingXXS) {
            Image(systemName: "chevron.left")
            Text("Back")
          }
          .font(.gpBody)
          .foregroundStyle(Color.gpTextSecondary)
        }
        .buttonStyle(.plain)
        .padding(.top, DesignTokens.spacingMD)
        .padding(.leading, DesignTokens.spacingXXL)
        .opacity(isAppeared ? 1 : 0)
        .animation(animationForDelay(0.0), value: isAppeared)
        .accessibilityLabel("Go back to welcome step")

        // MARK: Centered Content
        VStack(spacing: DesignTokens.spacingXL) {
          Spacer()

          // MARK: Title & Subtitle
          VStack(spacing: DesignTokens.spacingXS) {
            Text("Connect to GitHub")
              .font(.gpPageTitle)
              .foregroundStyle(Color.gpTextPrimary)
              .multilineTextAlignment(.center)

            Text("Create a Personal Access Token to get started")
              .font(.gpBody)
              .foregroundStyle(Color.gpTextSecondary)
              .multilineTextAlignment(.center)
          }
          .opacity(isAppeared ? 1 : 0)
          .offset(y: isAppeared ? 0 : 10)
          .animation(animationForDelay(0.1), value: isAppeared)

          // MARK: Unified Instruction Panel
          GlassCard {
            VStack(spacing: 0) {
              InstructionRow(
                number: 1,
                text:
                  "Go to GitHub \u{2192} Settings \u{2192} Developer settings \u{2192} Personal access tokens"
              )

              Divider()
                .background(Color.gpGlassBorder)
                .padding(.vertical, DesignTokens.spacingSM)

              InstructionRow(
                number: 2,
                text: "Generate new token with repo and read:user scopes"
              )

              Divider()
                .background(Color.gpGlassBorder)
                .padding(.vertical, DesignTokens.spacingSM)

              InstructionRow(
                number: 3,
                text: "Copy the token and paste it below"
              )
            }
          }
          .opacity(isAppeared ? 1 : 0)
          .offset(y: isAppeared ? 0 : 10)
          .animation(animationForDelay(0.2), value: isAppeared)

          // MARK: Token Input
          VStack(spacing: DesignTokens.spacingXS) {
            SecureField("ghp_xxxxxxxxxxxx", text: $viewModel.tokenInput)
              .font(.gpCode)
              .textFieldStyle(.plain)
              .padding(DesignTokens.spacingSM)
              .frame(height: 44)
              .glassEffect()
              .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusButton))
              .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.radiusButton)
                  .stroke(Color.gpGreen.opacity(glowOpacity), lineWidth: 2)
              )
              .overlay(alignment: .trailing) {
                Button {
                  if let clipboardString = NSPasteboard.general.string(forType: .string) {
                    viewModel.tokenInput = clipboardString
                  }
                } label: {
                  Image(systemName: "doc.on.clipboard")
                    .font(.gpBody)
                    .foregroundStyle(Color.gpTextSecondary)
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .padding(.trailing, DesignTokens.spacingXXS)
                .accessibilityLabel("Paste token from clipboard")
              }
              .offset(x: shakeOffset)
              .accessibilityLabel("GitHub personal access token")

            // MARK: Error Display
            if let error = viewModel.tokenValidationError {
              HStack(spacing: DesignTokens.spacingXXS) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(Color.gpOrange)
                  .accessibilityHidden(true)
                Text(error)
                  .font(.gpCaption)
                  .foregroundStyle(Color.gpOrange)
              }
              .accessibilityElement(children: .combine)
              .accessibilityLabel("Error: \(error)")
            }
          }
          .opacity(isAppeared ? 1 : 0)
          .offset(y: isAppeared ? 0 : 10)
          .animation(animationForDelay(0.3), value: isAppeared)

          Spacer()

          // MARK: Validate Button
          Button {
            Task {
              await viewModel.validateToken()
            }
          } label: {
            HStack(spacing: DesignTokens.spacingXS) {
              if viewModel.isValidatingToken {
                ProgressView()
                  .controlSize(.small)
              }
              Text("Validate & Continue")
            }
          }
          .buttonStyle(PrimaryCTAButtonStyle())
          .disabled(viewModel.tokenInput.isEmpty || viewModel.isValidatingToken)
          .opacity(
            (viewModel.tokenInput.isEmpty || viewModel.isValidatingToken) ? 0.5 : 1.0
          )
          .frame(maxWidth: .infinity)
          .opacity(isAppeared ? 1 : 0)
          .offset(y: isAppeared ? 0 : 10)
          .animation(animationForDelay(0.4), value: isAppeared)
          .accessibilityLabel(
            viewModel.isValidatingToken
              ? "Validating token" : "Validate and continue"
          )
        }
        .frame(width: contentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
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
    .onChange(of: viewModel.isValidatingToken) { _, isValidating in
      if isValidating {
        startGlowAnimation()
      } else {
        withAnimation(.easeOut(duration: DesignTokens.animationStateTransition)) {
          glowOpacity = 0
        }
      }
    }
    .onChange(of: viewModel.tokenValidationError) { _, newError in
      if newError != nil {
        triggerShake()
      }
    }
  }

  /// Returns a spring animation with a given delay, or `.none` if reduced motion is on.
  private func animationForDelay(_ delay: Double) -> Animation? {
    reduceMotion
      ? .none
      : .spring(response: 0.5, dampingFraction: 0.8).delay(delay)
  }

  /// Triggers a shake animation on the token input field.
  private func triggerShake() {
    guard !reduceMotion else { return }
    withAnimation(.easeInOut(duration: 0.08)) {
      shakeOffset = 10
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      withAnimation(.easeInOut(duration: 0.08)) {
        shakeOffset = -10
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
      withAnimation(.easeInOut(duration: 0.08)) {
        shakeOffset = 6
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
      withAnimation(.easeInOut(duration: 0.08)) {
        shakeOffset = -6
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
      withAnimation(.easeInOut(duration: 0.08)) {
        shakeOffset = 0
      }
    }
  }

  /// Starts a pulsing glow animation on the token input field border.
  private func startGlowAnimation() {
    guard !reduceMotion else { return }
    withAnimation(
      .easeInOut(duration: 0.8)
        .repeatForever(autoreverses: true)
    ) {
      glowOpacity = 0.6
    }
  }
}

// MARK: - Instruction Row

/// A compact instruction row with a numbered circle and description text.
private struct InstructionRow: View {
  let number: Int
  let text: String

  var body: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      Text("\(number)")
        .font(.gpCaption)
        .fontWeight(.semibold)
        .foregroundStyle(.black)
        .frame(width: 24, height: 24)
        .background(Color.gpGreen)
        .clipShape(Circle())
        .accessibilityHidden(true)

      Text(text)
        .font(.gpCaption)
        .foregroundStyle(Color.gpTextPrimary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Step \(number): \(text)")
  }
}

// MARK: - Previews

#Preview("TokenSetupStep") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()
    TokenSetupStep(viewModel: OnboardingViewModel())
  }
  .frame(width: 700, height: 600)
}

#Preview("TokenSetupStep - Error") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    let viewModel = OnboardingViewModel()
    TokenSetupStep(viewModel: viewModel)
      .onAppear {
        viewModel.tokenInput = "ghp_invalid"
        viewModel.tokenValidationError =
          "Invalid token. Please check your token and try again."
      }
  }
  .frame(width: 700, height: 600)
}
