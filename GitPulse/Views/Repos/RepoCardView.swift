//  RepoCardView.swift
//  GitPulse

import SwiftUI

// MARK: - RepoCardView

/// A card displaying a single repository in the repos list.
///
/// Shows the repo name with language indicator, optional description,
/// star count, sparkline of recent activity, and relative last-push date.
/// The parent view is responsible for handling tap gestures.
///
/// ```swift
/// RepoCardView(repo: item)
///     .onTapGesture { selectedRepo = item }
/// ```
struct RepoCardView: View {

  /// The repository display data to render.
  let repo: RepoDisplayItem

  var body: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      // MARK: Left: language dot + text info
      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
        HStack(spacing: DesignTokens.spacingXS) {
          Circle()
            .fill(repo.languageColor)
            .frame(width: 8, height: 8)

          Text(repo.name)
            .font(.gpCardTitle)
            .foregroundStyle(Color.gpTextPrimary)
            .lineLimit(1)

          if repo.isPrivate {
            Image(systemName: "lock.fill")
              .font(.system(size: 10))
              .foregroundStyle(Color.gpTextTertiary)
          }
        }

        if let description = repo.descriptionText {
          Text(description)
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextSecondary)
            .lineLimit(1)
        }

        HStack(spacing: DesignTokens.spacingSM) {
          if let language = repo.language {
            Text(language)
              .font(.gpCaption)
              .foregroundStyle(repo.languageColor)
          }
        }
      }

      Spacer()

      // MARK: Right: star count, sparkline, last push
      HStack(spacing: DesignTokens.spacingMD) {
        if repo.starCount > 0 {
          HStack(spacing: DesignTokens.spacingXXS) {
            Image(systemName: "star.fill")
              .font(.system(size: 10))
              .foregroundStyle(Color.gpGold)

            Text("\(repo.starCount)")
              .font(.gpCaption)
              .foregroundStyle(Color.gpTextSecondary)
          }
        }

        SparklineView(
          data: repo.recentActivitySparkline,
          color: repo.languageColor
        )

        if let date = repo.lastPushDate {
          Text(date, style: .relative)
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextSecondary)
            .frame(width: 60, alignment: .trailing)
        }
      }
    }
    .padding(.horizontal, DesignTokens.spacingMD)
    .padding(.vertical, DesignTokens.spacingSM)
    .frame(height: DesignTokens.repoCardHeight)
    .glassEffect(in: .rect(cornerRadius: DesignTokens.radiusStat))
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityDescription)
  }

  // MARK: - Accessibility

  /// Builds a combined accessibility label from the repo's properties.
  private var accessibilityDescription: String {
    var parts: [String] = [repo.name]

    if repo.isPrivate {
      parts.append("private repository")
    }

    if let language = repo.language {
      parts.append(language)
    }

    if repo.starCount > 0 {
      let starLabel = repo.starCount == 1 ? "1 star" : "\(repo.starCount) stars"
      parts.append(starLabel)
    }

    if let date = repo.lastPushDate {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .full
      let relative = formatter.localizedString(for: date, relativeTo: .now)
      parts.append("last pushed \(relative)")
    }

    return parts.joined(separator: ", ")
  }
}

// MARK: - Previews

#Preview("RepoCardView — Full") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingSM) {
      RepoCardView(
        repo: RepoDisplayItem(
          id: 1,
          name: "GitPulse",
          fullName: "octocat/GitPulse",
          descriptionText: "A personal GitHub activity tracker for macOS",
          language: "Swift",
          languageColor: Color(hex: "F05138"),
          starCount: 42,
          forkCount: 5,
          isPrivate: false,
          lastPushDate: Date().addingTimeInterval(-7200),
          commitCount: 128,
          recentActivitySparkline: [3, 5, 2, 8, 6, 7, 4]
        )
      )

      RepoCardView(
        repo: RepoDisplayItem(
          id: 2,
          name: "private-api",
          fullName: "octocat/private-api",
          descriptionText: nil,
          language: "TypeScript",
          languageColor: Color(hex: "3178C6"),
          starCount: 0,
          forkCount: 0,
          isPrivate: true,
          lastPushDate: Date().addingTimeInterval(-86400),
          commitCount: 34,
          recentActivitySparkline: [1, 0, 2, 1, 0, 3, 1]
        )
      )

      RepoCardView(
        repo: RepoDisplayItem(
          id: 3,
          name: "awesome-project",
          fullName: "octocat/awesome-project",
          descriptionText:
            "A really long description that should get truncated at the end of the line",
          language: "Python",
          languageColor: Color(hex: "3572A5"),
          starCount: 1024,
          forkCount: 200,
          isPrivate: false,
          lastPushDate: Date().addingTimeInterval(-604_800),
          commitCount: 512,
          recentActivitySparkline: [8, 6, 9, 4, 7, 5, 10]
        )
      )
    }
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 700, height: 320)
}

#Preview("RepoCardView — Minimal") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    RepoCardView(
      repo: RepoDisplayItem(
        id: 4,
        name: "new-repo",
        fullName: "octocat/new-repo",
        descriptionText: nil,
        language: nil,
        languageColor: .gpTextTertiary,
        starCount: 0,
        forkCount: 0,
        isPrivate: false,
        lastPushDate: nil,
        commitCount: 0,
        recentActivitySparkline: []
      )
    )
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 700, height: 120)
}
