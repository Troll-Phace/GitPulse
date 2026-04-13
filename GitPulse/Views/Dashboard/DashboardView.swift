//  DashboardView.swift
//  GitPulse

import SwiftData
import SwiftUI

// MARK: - DashboardView

/// The main Dashboard screen assembling contribution stats, heatmap, weekly chart, and activity feed.
///
/// Uses `@Query` to reactively fetch SwiftData models and feeds them into a `DashboardViewModel`
/// for display-ready computation. Shows an empty state before the first sync, and a full
/// data layout with stat cards, heatmap, weekly chart, recent activity, and sync status bar.
struct DashboardView: View {
  @Query(sort: \Contribution.date, order: .reverse) private var contributions: [Contribution]
  @Query private var repositories: [Repository]
  @Query private var pullRequests: [PullRequest]
  @Query private var userProfiles: [UserProfile]
  @Query private var syncMetadatas: [SyncMetadata]

  @State private var viewModel = DashboardViewModel()
  @State private var hasAppeared = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The first user profile, if any.
  private var userProfile: UserProfile? { userProfiles.first }

  /// The first sync metadata record, if any.
  private var syncMetadata: SyncMetadata? { syncMetadatas.first }

  /// Whether there is no data to display yet.
  private var isDataEmpty: Bool {
    contributions.isEmpty && repositories.isEmpty && pullRequests.isEmpty
  }

  var body: some View {
    Group {
      if isDataEmpty {
        emptyStateView
      } else {
        dataView
      }
    }
    .onAppear {
      updateViewModel()
      hasAppeared = true
    }
    .onChange(of: contributions.count) { _, _ in updateViewModel() }
    .onChange(of: repositories.count) { _, _ in updateViewModel() }
    .onChange(of: pullRequests.count) { _, _ in updateViewModel() }
  }

  // MARK: - Empty State

  /// Displayed before the first sync when no data exists.
  private var emptyStateView: some View {
    VStack(spacing: DesignTokens.spacingMD) {
      Image(systemName: "chart.bar.xaxis")
        .font(.system(size: 48))
        .foregroundStyle(Color.gpTextTertiary)

      Text("Welcome to GitPulse")
        .font(.gpSectionHeader)
        .foregroundStyle(Color.gpTextPrimary)

      Text("Sync your GitHub data to see your dashboard")
        .font(.gpBody)
        .foregroundStyle(Color.gpTextSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Data View

  /// The full dashboard layout with all sections.
  private var dataView: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: DesignTokens.spacingLG) {
        StatCardsRow(viewModel: viewModel)

        ContributionHeatmap(
          cells: viewModel.buildHeatmapCells(),
          totalContributions: viewModel.totalContributionsInPeriod
        )

        HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
          WeeklyActivityChart(days: viewModel.buildWeeklyActivity())
            .frame(maxWidth: .infinity)

          RecentActivityFeed(items: viewModel.buildRecentActivity())
            .frame(maxWidth: .infinity)
        }

        syncStatusBar
      }
      .padding(.horizontal, DesignTokens.spacingLG)
      .padding(.top, DesignTokens.spacingMD)
      .padding(.bottom, DesignTokens.spacingXL)
      .opacity(hasAppeared ? 1 : 0)
      .offset(y: hasAppeared ? 0 : 8)
      .animation(
        reduceMotion ? .none : .easeOut(duration: 0.3),
        value: hasAppeared
      )
    }
  }

  // MARK: - Sync Status Bar

  /// A footer bar showing last sync time and API rate limit status.
  private var syncStatusBar: some View {
    HStack {
      Text("Last synced: \(viewModel.lastSyncedText)")
        .font(.gpMicro)
        .foregroundStyle(Color.gpTextTertiary)

      Spacer()

      HStack(spacing: DesignTokens.spacingXXS) {
        Circle()
          .fill(Color.gpGreen)
          .frame(width: 6, height: 6)

        Text("API: \(viewModel.rateLimitText)")
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextTertiary)
      }
    }
  }

  // MARK: - Data Binding

  /// Updates the view model with the latest SwiftData query results.
  private func updateViewModel() {
    viewModel.update(
      contributions: contributions,
      repositories: repositories,
      pullRequests: pullRequests,
      userProfile: userProfile,
      syncMetadata: syncMetadata
    )
  }
}

// MARK: - Previews

#Preview("DashboardView — Empty") {
  DashboardView()
    .modelContainer(
      for: [
        Contribution.self, Repository.self, PullRequest.self,
        UserProfile.self, SyncMetadata.self, LanguageStat.self,
      ],
      inMemory: true
    )
    .frame(width: 1000, height: 700)
    .background(Color.gpBackground)
}

#Preview("DashboardView") {
  DashboardView()
    .modelContainer(
      for: [
        Contribution.self, Repository.self, PullRequest.self,
        UserProfile.self, SyncMetadata.self, LanguageStat.self,
      ],
      inMemory: true
    )
    .frame(width: 1000, height: 700)
    .background(Color.gpBackground)
}
