//  ReposView.swift
//  GitPulse

import SwiftData
import SwiftUI

// MARK: - ReposView

/// The main Repositories screen assembling the language donut chart, search/sort toolbar,
/// and scrollable repo card list with detail sheet drill-in.
///
/// Uses `@Query` to reactively fetch SwiftData models and feeds them into a `ReposViewModel`
/// for display-ready computation. Shows an empty state before the first sync, and a full
/// data layout with language distribution, search, and repo cards.
struct ReposView: View {
  @Query private var repositories: [Repository]
  @Query(sort: \Contribution.date, order: .reverse) private var contributions: [Contribution]

  @State private var viewModel = ReposViewModel()
  @State private var selectedRepoDetail: RepoDetailData?
  @State private var hasAppeared = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Whether there is no data to display yet.
  private var isDataEmpty: Bool { repositories.isEmpty }

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
    .onChange(of: repositories.count) { _, _ in updateViewModel() }
    .onChange(of: contributions.count) { _, _ in updateViewModel() }
    .sheet(item: $selectedRepoDetail) { detail in
      RepoDetailSheet(detail: detail)
    }
  }

  // MARK: - Empty State

  /// Displayed before the first sync when no repository data exists.
  private var emptyStateView: some View {
    VStack(spacing: DesignTokens.spacingMD) {
      Image(systemName: "folder")
        .font(.system(size: 48))
        .foregroundStyle(Color.gpTextTertiary)

      Text("No Repositories")
        .font(.gpSectionHeader)
        .foregroundStyle(Color.gpTextPrimary)

      Text("Sync your GitHub data to see your repositories here.")
        .font(.gpBody)
        .foregroundStyle(Color.gpTextSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Data View

  /// The full repos layout with search, language chart, and repo list.
  private var dataView: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 0) {
        searchAndSortBar
          .padding(.bottom, DesignTokens.spacingMD)

        LanguageDonutChart(
          slices: viewModel.languageSlices,
          centerText: viewModel.formattedLineCount,
          centerSubtext: "lines of code",
          repoCount: viewModel.repoCount
        )
        .padding(.bottom, DesignTokens.spacingMD)

        Text("Repositories (\(viewModel.repoCount))")
          .font(.gpSectionHeader)
          .foregroundStyle(Color.gpTextPrimary)
          .padding(.bottom, DesignTokens.spacingSM)

        if viewModel.filteredRepos.isEmpty && !viewModel.searchText.isEmpty {
          noResultsView
        } else {
          LazyVStack(spacing: DesignTokens.spacingSM) {
            ForEach(viewModel.filteredRepos) { repo in
              RepoCardView(repo: repo)
                .onTapGesture {
                  selectedRepoDetail = viewModel.buildRepoDetail(for: repo.id)
                }
            }
          }
        }
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

  // MARK: - Search & Sort Bar

  /// A glass-styled search field with a sort picker.
  private var searchAndSortBar: some View {
    HStack(spacing: DesignTokens.spacingSM) {
      HStack(spacing: DesignTokens.spacingXS) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(Color.gpTextTertiary)

        TextField("Search repositories...", text: $viewModel.searchText)
          .textFieldStyle(.plain)
          .font(.gpBody)
          .foregroundStyle(Color.gpTextPrimary)
      }
      .padding(.horizontal, DesignTokens.spacingSM)
      .padding(.vertical, DesignTokens.spacingXS)
      .glassEffect(in: .rect(cornerRadius: DesignTokens.radiusMini))

      Picker("Sort", selection: $viewModel.sortOrder) {
        ForEach(RepoSortOrder.allCases, id: \.self) { order in
          Text(order.rawValue).tag(order)
        }
      }
      .pickerStyle(.menu)
      .font(.gpCaption)
    }
  }

  // MARK: - No Results

  /// Shown when search text matches no repositories.
  private var noResultsView: some View {
    VStack(spacing: DesignTokens.spacingSM) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 32))
        .foregroundStyle(Color.gpTextTertiary)

      Text("No repositories match '\(viewModel.searchText)'")
        .font(.gpBody)
        .foregroundStyle(Color.gpTextSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, DesignTokens.spacingXL)
  }

  // MARK: - Data Binding

  /// Updates the view model with the latest SwiftData query results.
  private func updateViewModel() {
    viewModel.update(repositories: repositories, contributions: contributions)
  }
}

// MARK: - Previews

#Preview("ReposView — Empty") {
  ReposView()
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

#Preview("ReposView") {
  ReposView()
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
