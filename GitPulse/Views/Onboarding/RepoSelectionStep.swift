//  RepoSelectionStep.swift
//  GitPulse

import SwiftUI

/// The third step of onboarding, where the user selects repositories to track.
///
/// Displays a title with a count pill, minimal text controls for select/deselect all,
/// and a polished list of repos with selection-based opacity and hover highlights.
struct RepoSelectionStep: View {
  /// The onboarding view model providing repository data and selection state.
  @Bindable var viewModel: OnboardingViewModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAppeared = false

  var body: some View {
    GeometryReader { geo in
      let contentWidth = min(geo.size.width * 0.7, 560)

      VStack(spacing: DesignTokens.spacingLG) {
        // MARK: Header
        HStack(spacing: DesignTokens.spacingXS) {
          Text("Select Repositories")
            .font(.gpPageTitle)
            .foregroundStyle(Color.gpTextPrimary)

          // Count pill
          Text(
            "\(viewModel.selectedRepoIDs.count) of \(viewModel.repositories.count)"
          )
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextSecondary)
          .padding(.horizontal, DesignTokens.spacingXS)
          .padding(.vertical, DesignTokens.spacingXXS)
          .glassEffect()
          .clipShape(Capsule())
        }
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 10)
        .animation(animationForDelay(0.0), value: isAppeared)

        // MARK: Toolbar
        HStack {
          Spacer()

          Button("Select All") {
            viewModel.selectAllRepos()
          }
          .buttonStyle(.plain)
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
          .accessibilityLabel("Select all repositories")

          Text("\u{00B7}")
            .foregroundStyle(Color.gpTextTertiary)

          Button("Deselect All") {
            viewModel.deselectAllRepos()
          }
          .buttonStyle(.plain)
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
          .accessibilityLabel("Deselect all repositories")
        }
        .opacity(isAppeared ? 1 : 0)
        .animation(animationForDelay(0.1), value: isAppeared)

        // MARK: Content
        if viewModel.isLoadingRepos {
          Spacer()
          ProgressView("Fetching repositories...")
            .font(.gpBody)
            .foregroundStyle(Color.gpTextSecondary)
          Spacer()
        } else if let error = viewModel.repoLoadError {
          Spacer()
          VStack(spacing: DesignTokens.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 32))
              .foregroundStyle(Color.gpOrange)
              .accessibilityHidden(true)

            Text(error)
              .font(.gpBody)
              .foregroundStyle(Color.gpTextSecondary)
              .multilineTextAlignment(.center)

            Button("Retry") {
              Task {
                await viewModel.fetchRepositories()
              }
            }
            .buttonStyle(SecondaryButtonStyle())
            .frame(maxWidth: 160)
            .accessibilityLabel("Retry fetching repositories")
          }
          Spacer()
        } else {
          // MARK: Repo List
          ScrollView {
            LazyVStack(spacing: DesignTokens.spacingXS) {
              ForEach(
                Array(viewModel.repositories.enumerated()),
                id: \.element.id
              ) { index, repo in
                let isSelected = viewModel.selectedRepoIDs.contains(repo.id)

                RepoRow(
                  repo: repo,
                  isSelected: isSelected
                ) {
                  withAnimation(
                    .easeInOut(duration: DesignTokens.animationStateTransition)
                  ) {
                    viewModel.toggleRepoSelection(repo.id)
                  }
                }
                .opacity(isAppeared ? 1 : 0)
                .offset(y: isAppeared ? 0 : 10)
                .animation(
                  animationForDelay(0.15 + Double(index) * 0.03),
                  value: isAppeared
                )
              }
            }
            .padding(.horizontal, DesignTokens.spacingXXS)
          }
        }

        // MARK: Continue Button
        Button("Continue") {
          viewModel.advanceStep()
        }
        .buttonStyle(PrimaryCTAButtonStyle())
        .disabled(viewModel.selectedRepoIDs.isEmpty)
        .opacity(viewModel.selectedRepoIDs.isEmpty ? 0.5 : 1.0)
        .frame(maxWidth: .infinity)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 10)
        .animation(animationForDelay(0.2), value: isAppeared)
        .accessibilityLabel("Continue to completion")
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

// MARK: - Repo Row

/// A single repository row with selection-based opacity and hover highlight.
private struct RepoRow: View {
  let repo: GitHubRepo
  let isSelected: Bool
  let onToggle: () -> Void

  @State private var isHovered = false

  var body: some View {
    Button(action: onToggle) {
      HStack(spacing: DesignTokens.spacingSM) {
        // MARK: Repo Info
        VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
          HStack(spacing: DesignTokens.spacingXXS) {
            Text(repo.name)
              .font(.gpCardTitle)
              .foregroundStyle(Color.gpTextPrimary)
              .lineLimit(1)

            if repo.isPrivate {
              Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.gpTextTertiary)
                .accessibilityLabel("Private repository")
            }

            if let language = repo.language {
              HStack(spacing: DesignTokens.spacingXXS) {
                Circle()
                  .fill(languageColor(for: language))
                  .frame(width: 8, height: 8)
                Text(language)
                  .font(.gpCaption)
                  .foregroundStyle(Color.gpTextSecondary)
              }
              .padding(.leading, DesignTokens.spacingXXS)
            }
          }

          if let description = repo.description {
            Text(description)
              .font(.gpCaption)
              .foregroundStyle(Color.gpTextSecondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
        }

        Spacer()

        // MARK: Star Count
        HStack(spacing: DesignTokens.spacingXXS) {
          Image(systemName: "star.fill")
            .font(.gpCaption)
            .foregroundStyle(Color.gpGold)
            .accessibilityHidden(true)
          Text("\(repo.stargazersCount)")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextSecondary)
        }
      }
      .padding(DesignTokens.spacingSM)
      .background(
        RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
          .fill(isHovered ? Color.gpGlassHighlight : Color.clear)
      )
      .glassEffect()
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMini))
      .opacity(isSelected ? 1.0 : 0.4)
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(repo.name)\(repo.isPrivate ? ", private" : ""), \(repo.language ?? "no language"), \(repo.stargazersCount) stars"
    )
    .accessibilityValue(isSelected ? "selected" : "not selected")
    .accessibilityAddTraits(.isButton)
  }

  /// Returns a color for a given programming language name.
  private func languageColor(for language: String) -> Color {
    switch language.lowercased() {
    case "swift": return Color.gpOrange
    case "javascript", "typescript": return Color(hex: "F1E05A")
    case "python": return Color(hex: "3572A5")
    case "rust": return Color(hex: "DEA584")
    case "go": return Color(hex: "00ADD8")
    case "ruby": return Color(hex: "701516")
    case "java", "kotlin": return Color(hex: "B07219")
    case "c", "c++", "objective-c": return Color(hex: "555555")
    default: return Color.gpBlue
    }
  }
}

// MARK: - Previews

#Preview("RepoSelectionStep") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()
    RepoSelectionStep(viewModel: OnboardingViewModel())
  }
  .frame(width: 700, height: 600)
}
