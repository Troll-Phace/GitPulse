//  RepoDetailSheet.swift
//  GitPulse

import Charts
import SwiftUI

/// A detail sheet displaying comprehensive information about a single repository,
/// including commit activity chart, language breakdown, and recent commit timeline.
struct RepoDetailSheet: View {

  let detail: RepoDetailData

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
        headerSection
        statsRow
        commitActivitySection
        languageBreakdownSection
        recentCommitsSection
      }
      .padding(DesignTokens.spacingXL)
    }
    .frame(
      minWidth: 420,
      idealWidth: 500,
      minHeight: 600,
      idealHeight: 700
    )
    .background(Color.gpBackground)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
      }
    }
  }

  // MARK: - Header Section

  /// Displays the repository name with a language-colored initial circle and description.
  private var headerSection: some View {
    HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
      initialCircle
      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
        Text(detail.name)
          .font(.gpCardTitle)
          .foregroundStyle(Color.gpTextPrimary)
        if let description = detail.descriptionText, !description.isEmpty {
          Text(description)
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextSecondary)
            .lineLimit(3)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }

  /// A colored circle showing the first letter of the repository name.
  private var initialCircle: some View {
    let primaryColor = detail.languageBreakdown.first?.color ?? Color.gpBlue
    return ZStack {
      Circle()
        .fill(primaryColor.opacity(0.15))
        .frame(width: 36, height: 36)
      Text(String(detail.name.prefix(1)).uppercased())
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(primaryColor)
    }
  }

  // MARK: - Stats Row

  /// Displays star and fork counts for the repository.
  private var statsRow: some View {
    HStack(spacing: DesignTokens.spacingLG) {
      Label {
        Text("\(detail.starCount)")
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextPrimary)
      } icon: {
        Image(systemName: "star.fill")
          .font(.gpCaption)
          .foregroundStyle(Color.gpGold)
      }
      Label {
        Text("\(detail.forkCount)")
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextPrimary)
      } icon: {
        Image(systemName: "tuningfork")
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(detail.starCount) stars, \(detail.forkCount) forks"
    )
  }

  // MARK: - Commit Activity Section

  /// Bar chart showing daily commit counts over the last 30 days.
  private var commitActivitySection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        HStack {
          Text("Commit Activity")
            .font(.gpCardTitle)
            .foregroundStyle(Color.gpTextPrimary)
          Spacer()
          Text("Last 30 days")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Commit activity for the last 30 days")

        if detail.dailyCommitCounts.isEmpty {
          Text("No commit data")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 120)
        } else {
          Chart(detail.dailyCommitCounts) { day in
            BarMark(
              x: .value("Day", day.id, unit: .day),
              y: .value("Commits", day.count)
            )
            .foregroundStyle(Color.gpBlue.opacity(0.6))
            .cornerRadius(2)
          }
          .chartXAxis(.hidden)
          .chartYAxis(.hidden)
          .frame(height: 120)
          .accessibilityLabel("Commit activity for the last 30 days")
        }
      }
    }
  }

  // MARK: - Language Breakdown Section

  /// Horizontal stacked bar and legend showing per-repo language distribution.
  private var languageBreakdownSection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        Text("Languages")
          .font(.gpCardTitle)
          .foregroundStyle(Color.gpTextPrimary)
          .accessibilityLabel("Language breakdown")

        if detail.languageBreakdown.isEmpty {
          Text("No language data")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextTertiary)
        } else {
          // Horizontal stacked bar
          GeometryReader { geometry in
            HStack(spacing: 2) {
              ForEach(detail.languageBreakdown) { slice in
                RoundedRectangle(cornerRadius: DesignTokens.radiusHeatmap)
                  .fill(slice.color)
                  .frame(
                    width: max(
                      4,
                      (slice.percentage / 100.0)
                        * (geometry.size.width
                          - CGFloat(max(0, detail.languageBreakdown.count - 1)) * 2)
                    )
                  )
              }
            }
          }
          .frame(height: 8)

          // Legend
          FlowLayout(spacing: DesignTokens.spacingXS) {
            ForEach(detail.languageBreakdown) { slice in
              HStack(spacing: DesignTokens.spacingXXS) {
                Circle()
                  .fill(slice.color)
                  .frame(width: 8, height: 8)
                Text(slice.name)
                  .font(.gpCaption)
                  .foregroundStyle(Color.gpTextPrimary)
                Text(String(format: "%.1f%%", slice.percentage))
                  .font(.gpCaption)
                  .foregroundStyle(Color.gpTextSecondary)
              }
              .accessibilityElement(children: .combine)
            }
          }
        }
      }
    }
  }

  // MARK: - Recent Commits Section

  /// Timeline-style list of the most recent commits for this repository.
  private var recentCommitsSection: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        Text("Recent Commits")
          .font(.gpCardTitle)
          .foregroundStyle(Color.gpTextPrimary)
          .accessibilityLabel("Recent commits")

        if detail.recentCommits.isEmpty {
          Text("No recent commits")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextTertiary)
        } else {
          VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(detail.recentCommits.enumerated()), id: \.element.id) { index, commit in
              commitTimelineRow(commit: commit, isLast: index == detail.recentCommits.count - 1)
            }
          }
        }
      }
    }
  }

  /// A single row in the commit timeline with a dot, optional connecting line, and commit info.
  private func commitTimelineRow(commit: RecentCommitItem, isLast: Bool) -> some View {
    HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
      // Timeline indicator
      VStack(spacing: 0) {
        ZStack {
          Circle()
            .fill(Color.gpGreen.opacity(0.2))
            .frame(width: 16, height: 16)
          Circle()
            .fill(Color.gpGreen)
            .frame(width: 8, height: 8)
        }
        if !isLast {
          Rectangle()
            .fill(Color.gpGreen.opacity(0.2))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
        }
      }
      .frame(width: 16)

      // Commit details
      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
        Text(commit.message)
          .font(.gpBody)
          .foregroundStyle(Color.gpTextPrimary)
          .lineLimit(1)
        HStack(spacing: DesignTokens.spacingXXS) {
          Text(commit.shortHash)
            .font(.gpCode)
            .foregroundStyle(Color.gpTextTertiary)
          Text("—")
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextTertiary)
          Text(commit.relativeTime)
            .font(.gpCaption)
            .foregroundStyle(Color.gpTextTertiary)
        }
      }
      .padding(.bottom, isLast ? 0 : DesignTokens.spacingSM)
    }
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Flow Layout

/// A simple flow layout that wraps items to new lines when they exceed the available width.
private struct FlowLayout: Layout {

  var spacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
    let result = arrangeSubviews(proposal: proposal, subviews: subviews)
    return result.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()
  ) {
    let result = arrangeSubviews(proposal: proposal, subviews: subviews)
    for (index, position) in result.positions.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: .unspecified
      )
    }
  }

  private func arrangeSubviews(
    proposal: ProposedViewSize, subviews: Subviews
  ) -> (positions: [CGPoint], size: CGSize) {
    let maxWidth = proposal.width ?? .infinity
    var positions: [CGPoint] = []
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var lineHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX + size.width > maxWidth, currentX > 0 {
        currentX = 0
        currentY += lineHeight + spacing
        lineHeight = 0
      }
      positions.append(CGPoint(x: currentX, y: currentY))
      lineHeight = max(lineHeight, size.height)
      currentX += size.width + spacing
      maxX = max(maxX, currentX - spacing)
    }

    return (positions, CGSize(width: maxX, height: currentY + lineHeight))
  }
}

// MARK: - Previews

#Preview("RepoDetailSheet") {
  Color.gpBackground
    .sheet(isPresented: .constant(true)) {
      RepoDetailSheet(
        detail: RepoDetailData(
          id: 1,
          name: "ios-tracker",
          fullName: "anthonygrimaldi/ios-tracker",
          descriptionText: "iOS GitHub activity tracker app built with SwiftUI and Liquid Glass",
          starCount: 12,
          forkCount: 4,
          languageBreakdown: [
            LanguageSlice(
              id: "Swift", name: "Swift", bytes: 45_000, percentage: 65.2,
              color: Color(hex: "F05138")),
            LanguageSlice(
              id: "Objective-C", name: "Objective-C", bytes: 12_000, percentage: 17.4,
              color: Color(hex: "438EFF")),
            LanguageSlice(
              id: "C", name: "C", bytes: 8_000, percentage: 11.6, color: Color(hex: "555555")),
            LanguageSlice(
              id: "Shell", name: "Shell", bytes: 4_000, percentage: 5.8, color: Color(hex: "89E051")
            ),
          ],
          recentCommits: [
            RecentCommitItem(
              id: "a1", message: "Add contribution heatmap with dynamic intensity",
              shortHash: "a3f2b1c", relativeTime: "2h ago"),
            RecentCommitItem(
              id: "a2", message: "Fix streak calculation timezone edge case", shortHash: "b7e9d4a",
              relativeTime: "5h ago"),
            RecentCommitItem(
              id: "a3", message: "Implement glass card component", shortHash: "c1d8f3e",
              relativeTime: "1d ago"),
            RecentCommitItem(
              id: "a4", message: "Update SwiftData schema for PR tracking", shortHash: "d4a2c7b",
              relativeTime: "2d ago"),
            RecentCommitItem(
              id: "a5", message: "Initial project scaffold", shortHash: "e8f1a9c",
              relativeTime: "3d ago"),
          ],
          dailyCommitCounts: (0..<30).reversed().map { daysAgo in
            DayCommitCount(
              id: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
              count: [
                0, 2, 5, 1, 3, 0, 8, 4, 2, 0, 6, 3, 1, 7, 5, 2, 0, 4, 9, 3, 1, 0, 5, 2, 6, 4, 0, 3,
                7, 2,
              ][daysAgo]
            )
          }
        )
      )
    }
}

#Preview("RepoDetailSheet — Empty") {
  Color.gpBackground
    .sheet(isPresented: .constant(true)) {
      RepoDetailSheet(
        detail: RepoDetailData(
          id: 2,
          name: "empty-repo",
          fullName: "anthonygrimaldi/empty-repo",
          descriptionText: nil,
          starCount: 0,
          forkCount: 0,
          languageBreakdown: [],
          recentCommits: [],
          dailyCommitCounts: []
        )
      )
    }
}
