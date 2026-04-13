//  RecentActivityFeed.swift
//  GitPulse

import SwiftUI

// MARK: - RecentActivityFeed

/// A timeline-style activity list showing recent contribution events.
///
/// Each item displays a colored timeline dot, an event title with subtitle,
/// and a relative timestamp. A dashed vertical line connects consecutive items
/// to form a visual timeline. Wrapped in a `GlassCard` for Liquid Glass styling.
struct RecentActivityFeed: View {
  /// The recent activity items to display, sorted most recent first.
  let items: [ActivityFeedItem]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        Text("Recent Activity")
          .font(.gpCardTitle)
          .foregroundStyle(Color.gpTextPrimary)

        if items.isEmpty {
          emptyState
        } else {
          feedBody
        }
      }
    }
  }

  // MARK: - Subviews

  /// The list of activity rows with timeline indicators.
  private var feedBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        ActivityRow(
          item: item,
          isLast: index == items.count - 1
        )
      }
    }
  }

  /// Empty state when no activity exists.
  private var emptyState: some View {
    Text("No recent activity")
      .font(.gpBody)
      .foregroundStyle(Color.gpTextSecondary)
      .frame(maxWidth: .infinity, minHeight: 100)
      .multilineTextAlignment(.center)
  }
}

// MARK: - ActivityRow

/// A single row in the activity feed with a timeline dot and connector line.
private struct ActivityRow: View {
  /// The activity item to render.
  let item: ActivityFeedItem

  /// Whether this is the last item (suppresses the connector line).
  let isLast: Bool

  /// The fixed width of the timeline indicator column.
  private static let timelineColumnWidth: CGFloat = 16

  /// The outer dot diameter.
  private static let outerDotSize: CGFloat = 8

  /// The inner dot diameter.
  private static let innerDotSize: CGFloat = 4

  var body: some View {
    HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
      // Timeline indicator column
      VStack(spacing: 0) {
        ZStack {
          Circle()
            .fill(item.eventColor.opacity(0.2))
            .frame(width: Self.outerDotSize, height: Self.outerDotSize)

          Circle()
            .fill(item.eventColor)
            .frame(width: Self.innerDotSize, height: Self.innerDotSize)
        }

        if !isLast {
          DashedLine()
            .stroke(
              Color.gpGlassBorder,
              style: StrokeStyle(lineWidth: 1, dash: [2, 2])
            )
            .frame(width: 1)
        }
      }
      .frame(width: Self.timelineColumnWidth)

      // Content
      VStack(alignment: .leading, spacing: DesignTokens.spacingXXS) {
        Text(item.title)
          .font(.gpBody)
          .fontWeight(.medium)
          .foregroundStyle(Color.gpTextPrimary)
          .lineLimit(1)

        Text(item.subtitle)
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
          .lineLimit(1)
      }

      Spacer()

      // Timestamp
      Text(item.relativeTime)
        .font(.gpCaption)
        .foregroundStyle(Color.gpTextTertiary)
    }
    .padding(.vertical, DesignTokens.spacingSM)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(item.title). \(item.subtitle). \(item.relativeTime)")
  }
}

// MARK: - DashedLine

/// A simple vertical dashed line shape for the timeline connector.
private struct DashedLine: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    return path
  }
}

// MARK: - Previews

#Preview("RecentActivityFeed — With Data") {
  let mockItems: [ActivityFeedItem] = [
    ActivityFeedItem(
      id: "1",
      title: "Pushed 3 commits",
      subtitle: "GitPulse",
      relativeTime: "2m ago",
      eventColor: .gpGreen,
      contributionType: .push
    ),
    ActivityFeedItem(
      id: "2",
      title: "Opened pull request",
      subtitle: "Add dashboard view",
      relativeTime: "1h ago",
      eventColor: .gpBlue,
      contributionType: .pullRequest
    ),
    ActivityFeedItem(
      id: "3",
      title: "Reviewed pull request",
      subtitle: "Fix streak calculation",
      relativeTime: "3h ago",
      eventColor: .gpBlue,
      contributionType: .pullRequestReview
    ),
    ActivityFeedItem(
      id: "4",
      title: "Opened issue",
      subtitle: "Widget not updating",
      relativeTime: "Yesterday",
      eventColor: .gpPurple,
      contributionType: .issue
    ),
    ActivityFeedItem(
      id: "5",
      title: "Created repository",
      subtitle: "new-project",
      relativeTime: "2d ago",
      eventColor: .gpOrange,
      contributionType: .create
    ),
  ]

  ZStack {
    Color.gpBackground.ignoresSafeArea()

    RecentActivityFeed(items: mockItems)
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 450, height: 500)
}

#Preview("RecentActivityFeed — Empty") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    RecentActivityFeed(items: [])
      .padding(DesignTokens.spacingLG)
  }
  .frame(width: 450, height: 300)
}
