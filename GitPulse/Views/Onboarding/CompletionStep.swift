//  CompletionStep.swift
//  GitPulse

import SwiftUI

/// The final step of onboarding, confirming the user is set up and ready to go.
///
/// Displays an animated checkmark that draws itself, the user's avatar and username,
/// a repository count summary, and a "Start Using GitPulse" call-to-action button.
struct CompletionStep: View {
  /// The onboarding view model providing the validated user and selected repo count.
  @Bindable var viewModel: OnboardingViewModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var checkmarkProgress: CGFloat = 0
  @State private var checkmarkScale: CGFloat = 1.0
  @State private var textAppeared = false
  @State private var ctaAppeared = false

  var body: some View {
    GeometryReader { geo in
      let contentWidth = min(geo.size.width * 0.7, 560)

      VStack(spacing: DesignTokens.spacingXL) {
        Spacer()

        // MARK: Animated Checkmark
        ZStack {
          Circle()
            .fill(Color.gpGreen.opacity(0.08))
            .frame(width: 100, height: 100)
            .glassEffect()
            .clipShape(Circle())

          CheckmarkShape()
            .trim(from: 0, to: checkmarkProgress)
            .stroke(
              Color.gpGreen,
              style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 40, height: 40)
        }
        .scaleEffect(checkmarkScale)
        .accessibilityLabel("Setup complete")

        // MARK: User Info
        VStack(spacing: DesignTokens.spacingSM) {
          if let user = viewModel.validatedUser {
            HStack(spacing: DesignTokens.spacingSM) {
              AsyncImage(url: URL(string: user.avatarUrl)) { phase in
                switch phase {
                case .success(let image):
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                case .failure:
                  Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.gpTextSecondary)
                case .empty:
                  ProgressView()
                    .frame(width: 48, height: 48)
                @unknown default:
                  Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.gpTextSecondary)
                }
              }
              .frame(width: 48, height: 48)
              .clipShape(Circle())
              .overlay(
                Circle()
                  .stroke(Color.gpGlassBorder, lineWidth: 1)
              )

              Text("Signed in as **\(user.login)**")
                .font(.gpBody)
                .foregroundStyle(Color.gpTextPrimary)
            }
          }

          Text(
            "\(viewModel.selectedRepoIDs.count) repositories ready to track"
          )
          .font(.gpBody)
          .foregroundStyle(Color.gpTextSecondary)
        }
        .opacity(textAppeared ? 1 : 0)
        .offset(y: textAppeared ? 0 : 10)

        Spacer()

        // MARK: CTA Button
        Button {
          viewModel.completeOnboarding()
        } label: {
          HStack(spacing: DesignTokens.spacingXS) {
            Text("Start Using GitPulse")
            Image(systemName: "arrow.right")
              .font(.gpCardTitle)
          }
        }
        .buttonStyle(PrimaryCTAButtonStyle())
        .frame(maxWidth: .infinity)
        .opacity(ctaAppeared ? 1 : 0)
        .offset(y: ctaAppeared ? 0 : 10)
        .accessibilityLabel("Finish setup and start using GitPulse")
      }
      .frame(width: contentWidth)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .padding(DesignTokens.spacingXXL)
    .task {
      if reduceMotion {
        checkmarkProgress = 1.0
        textAppeared = true
        ctaAppeared = true
      } else {
        // Draw checkmark
        withAnimation(.easeOut(duration: DesignTokens.animationChartDraw)) {
          checkmarkProgress = 1.0
        }

        // Bounce after draw
        try? await Task.sleep(for: .milliseconds(650))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
          checkmarkScale = 1.08
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
          checkmarkScale = 1.0
        }

        // Text fade in
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
          textAppeared = true
        }

        // CTA fade in
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
          ctaAppeared = true
        }
      }
    }
  }
}

// MARK: - Checkmark Shape

/// A custom shape that draws a checkmark path for trim animation.
struct CheckmarkShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let w = rect.width
    let h = rect.height

    // Checkmark: starts bottom-left, goes to bottom-center, then top-right
    path.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
    path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.75))
    path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.25))

    return path
  }
}

// MARK: - Previews

#Preview("CompletionStep") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    let viewModel = OnboardingViewModel()
    CompletionStep(viewModel: viewModel)
      .onAppear {
        viewModel.selectedRepoIDs = [1, 2, 3, 4, 5]
      }
  }
  .frame(width: 700, height: 600)
}
