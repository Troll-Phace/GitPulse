//  StreaksView.swift
//  GitPulse

import SwiftData
import SwiftUI

// MARK: - StreaksView

/// The main Streaks screen assembling the streak ring, stat cards, calendar, and history chart.
///
/// Uses `@Query` to reactively fetch SwiftData models and feeds them into a `StreaksViewModel`
/// for display-ready computation. Shows an empty state before the first sync, and a full
/// data layout with a hero ring card, stat cards, streak calendar, and streak history timeline.
struct StreaksView: View {
  @Query(sort: \Contribution.date, order: .reverse) private var contributions: [Contribution]
  @Query private var userProfiles: [UserProfile]

  @State private var viewModel = StreaksViewModel()
  @State private var hasAppeared = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The first user profile, if any.
  private var userProfile: UserProfile? { userProfiles.first }

  /// Whether there is no data to display yet.
  private var isDataEmpty: Bool { contributions.isEmpty }

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
  }

  // MARK: - Empty State

  /// Displayed before the first sync when no contribution data exists.
  private var emptyStateView: some View {
    VStack(spacing: DesignTokens.spacingMD) {
      Image(systemName: "flame")
        .font(.system(size: 48))
        .foregroundStyle(Color.gpTextTertiary)

      Text("No Streak Data")
        .font(.gpSectionHeader)
        .foregroundStyle(Color.gpTextPrimary)

      Text("Sync your GitHub data to see your streaks")
        .font(.gpBody)
        .foregroundStyle(Color.gpTextSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Data View

  /// The full streaks layout with all sections.
  private var dataView: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: 0) {
        // Warning banner (conditional)
        if viewModel.showWarningBanner {
          warningBanner
            .padding(.bottom, DesignTokens.spacingMD)
        }

        // Page title
        HStack(spacing: DesignTokens.spacingXS) {
          Image(systemName: "flame.fill")
            .font(.system(size: 24))
            .foregroundStyle(Color.gpTextPrimary)
          Text("Streaks")
            .font(.gpPageTitle)
            .foregroundStyle(Color.gpTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, DesignTokens.spacingMD)

        // Two-column layout: ring card + calendar
        HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
          heroRingCard
            .frame(minWidth: 350, idealWidth: 400)

          StreakCalendarView(
            days: viewModel.buildCalendarDays(),
            isActiveToday: viewModel.isActiveToday
          )
          .frame(maxWidth: .infinity)
        }
        .padding(.bottom, DesignTokens.spacingSM)

        // Stat cards row below
        statCardsRow
          .padding(.bottom, DesignTokens.spacingMD)

        // Full-width streak history
        StreakHistoryTimeline(bars: viewModel.buildStreakHistoryBars())
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

  // MARK: - Warning Banner

  /// A red-tinted banner warning that the user's streak is at risk of being broken.
  @ViewBuilder
  private var warningBanner: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color.gpRed)

      VStack(alignment: .leading, spacing: 2) {
        Text("Streak at risk!")
          .font(.gpCaption)
          .fontWeight(.medium)
          .foregroundStyle(Color.gpRed)

        Text(viewModel.warningMessage)
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextSecondary)
      }

      Spacer()

      Button {
        viewModel.warningDismissed = true
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(Color.gpTextTertiary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Dismiss warning")
    }
    .padding(DesignTokens.spacingSM)
    .background(Color.gpRed.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusMini))
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
        .stroke(Color.gpRed.opacity(0.2), lineWidth: 0.5)
    )
  }

  // MARK: - Hero Ring Card

  /// A glass card containing the streak ring, label, goal subtitle, and progress bar.
  private var heroRingCard: some View {
    GlassCard {
      VStack(spacing: DesignTokens.spacingMD) {
        StreakRingView(
          currentStreak: viewModel.currentStreak,
          goal: viewModel.streakGoal,
          isActiveToday: viewModel.isActiveToday
        )

        Text("Current Streak")
          .font(.gpCardTitle)
          .foregroundStyle(Color.gpTextPrimary)

        Text("Goal: \(viewModel.streakGoal) days (\(viewModel.goalPercentage)% complete)")
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextSecondary)

        // Progress bar
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
              .fill(Color(hex: "3A3A3C"))
              .frame(height: 4)

            RoundedRectangle(cornerRadius: 2)
              .fill(
                LinearGradient(
                  colors: [Color(hex: "FF9F0A"), Color(hex: "FF453A")],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: geo.size.width * viewModel.goalProgress, height: 4)
          }
        }
        .frame(height: 4)
        .padding(.horizontal, DesignTokens.spacingXL)
      }
      .frame(maxWidth: .infinity)
    }
    .accessibilityElement(children: .combine)
  }

  // MARK: - Stat Cards Row

  /// A horizontal row of two stat cards: longest streak and average daily commits.
  private var statCardsRow: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      StatCard(
        title: "Longest Streak",
        value: "\(viewModel.longestStreak)",
        accentColor: .gpGold,
        subtitle: viewModel.longestStreakDateRange.isEmpty ? nil : viewModel.longestStreakDateRange
      ) {
        Image(systemName: "trophy.fill")
          .font(.system(size: 20))
          .foregroundStyle(Color.gpGold)
      }

      StatCard(
        title: "Avg Daily Commits",
        value: String(format: "%.1f", viewModel.averageDailyCommits),
        accentColor: .gpBlue,
        trendDirection: viewModel.averageDailyTrendDirection,
        trendValue: viewModel.averageDailyTrend
      ) {
        EmptyView()
      }
    }
  }

  // MARK: - Data Binding

  /// Updates the view model with the latest SwiftData query results.
  private func updateViewModel() {
    viewModel.update(
      contributions: contributions,
      userProfile: userProfile
    )
  }
}

// MARK: - Previews

#Preview("StreaksView — Empty") {
  StreaksView()
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

#Preview("StreaksView") {
  StreaksView()
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
