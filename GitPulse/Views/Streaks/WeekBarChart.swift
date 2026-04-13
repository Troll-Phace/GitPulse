//  WeekBarChart.swift
//  GitPulse

import SwiftUI

/// A monthly calendar grid showing contribution activity for each day.
///
/// Renders the current month as a 7-column grid with visual indicators for
/// committed days (green tint + dot), today (red at-risk or green active),
/// future days (dimmed), and placeholder cells for alignment.
struct StreakCalendarView: View {

  /// The calendar day cells to display, including placeholders for alignment.
  let days: [CalendarDay]

  /// Whether the user has made a contribution today.
  let isActiveToday: Bool

  /// The formatted month and year string derived from the current date.
  private var monthName: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter.string(from: .now)
  }

  /// Seven-column grid layout for the calendar.
  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: DesignTokens.spacingXXS),
    count: 7
  )

  /// Day-of-week header labels starting from Sunday.
  private let dayHeaders = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

  var body: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
        headerRow
        dayHeaderRow
        calendarGrid
        legendRow
      }
    }
  }

  // MARK: - Subviews

  /// The header row with month name and "Today" link.
  private var headerRow: some View {
    HStack {
      Text(monthName)
        .font(.gpCardTitle)
        .foregroundStyle(Color.gpTextPrimary)
      Spacer()
      Text("Today")
        .font(.gpMicro)
        .foregroundStyle(Color.gpBlue)
    }
  }

  /// The row of abbreviated day-of-week labels.
  private var dayHeaderRow: some View {
    HStack {
      ForEach(dayHeaders, id: \.self) { day in
        Text(day)
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextTertiary)
          .frame(maxWidth: .infinity)
      }
    }
  }

  /// The main calendar grid of day cells.
  private var calendarGrid: some View {
    LazyVGrid(columns: columns, spacing: DesignTokens.spacingXXS) {
      ForEach(days) { day in
        calendarCell(for: day)
      }
    }
  }

  /// The legend row explaining the committed and at-risk indicators.
  private var legendRow: some View {
    HStack(spacing: DesignTokens.spacingMD) {
      HStack(spacing: DesignTokens.spacingXXS) {
        Circle()
          .fill(Color.gpGreen)
          .frame(width: 6, height: 6)
        Text("Committed")
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextSecondary)
      }
      HStack(spacing: DesignTokens.spacingXXS) {
        RoundedRectangle(cornerRadius: 3)
          .fill(Color.gpRed.opacity(0.2))
          .overlay(
            RoundedRectangle(cornerRadius: 3)
              .stroke(Color.gpRed.opacity(0.4), lineWidth: 0.5)
          )
          .frame(width: 10, height: 8)
        Text("Today (at risk)")
          .font(.gpMicro)
          .foregroundStyle(Color.gpTextSecondary)
      }
      Spacer()
    }
  }

  // MARK: - Cell Rendering

  /// Renders a single calendar cell based on its state.
  ///
  /// - Parameter day: The calendar day model to render.
  /// - Returns: A view representing the day cell.
  @ViewBuilder
  private func calendarCell(for day: CalendarDay) -> some View {
    if day.isPlaceholder {
      Color.clear
        .frame(height: 36)
        .accessibilityHidden(true)
    } else if day.isToday && !day.hasContribution {
      todayAtRiskCell(day: day)
    } else if day.isToday && day.hasContribution {
      todayActiveCell(day: day)
    } else if day.hasContribution {
      committedCell(day: day)
    } else if day.isFuture {
      futureCell(day: day)
    } else {
      uncommittedCell(day: day)
    }
  }

  /// A committed past day with green tint and dot indicator.
  private func committedCell(day: CalendarDay) -> some View {
    VStack(spacing: 2) {
      Text("\(day.dayNumber)")
        .font(.system(size: 12))
        .foregroundStyle(Color.gpTextPrimary)
      Circle()
        .fill(Color.gpGreen)
        .frame(width: 5, height: 5)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 36)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
        .fill(Color.gpGreen.opacity(0.15))
    )
    .accessibilityLabel("Day \(day.dayNumber), committed")
  }

  /// Today with no contribution: red tint, red border, "TODAY" micro label.
  private func todayAtRiskCell(day: CalendarDay) -> some View {
    VStack(spacing: 0) {
      Text("\(day.dayNumber)")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.gpRed)
      Text("TODAY")
        .font(.system(size: 7, weight: .medium))
        .foregroundStyle(Color.gpRed)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 36)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
        .fill(Color.gpRed.opacity(0.1))
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
        .stroke(Color.gpRed.opacity(0.4), lineWidth: 1)
    )
    .accessibilityLabel("Day \(day.dayNumber), no commits, today")
  }

  /// Today with a contribution: green tint, green border, dot indicator.
  private func todayActiveCell(day: CalendarDay) -> some View {
    VStack(spacing: 2) {
      Text("\(day.dayNumber)")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color.gpTextPrimary)
      Circle()
        .fill(Color.gpGreen)
        .frame(width: 5, height: 5)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 36)
    .background(
      RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
        .fill(Color.gpGreen.opacity(0.15))
    )
    .overlay(
      RoundedRectangle(cornerRadius: DesignTokens.radiusMini)
        .stroke(Color.gpGreen.opacity(0.4), lineWidth: 1)
    )
    .accessibilityLabel("Day \(day.dayNumber), committed, today")
  }

  /// A future day with dimmed text and no background.
  private func futureCell(day: CalendarDay) -> some View {
    Text("\(day.dayNumber)")
      .font(.system(size: 12))
      .foregroundStyle(Color.gpTextTertiary)
      .frame(maxWidth: .infinity)
      .frame(height: 36)
      .accessibilityLabel("Day \(day.dayNumber), future")
  }

  /// A past day with no contribution: secondary text, no background.
  private func uncommittedCell(day: CalendarDay) -> some View {
    Text("\(day.dayNumber)")
      .font(.system(size: 12))
      .foregroundStyle(Color.gpTextSecondary)
      .frame(maxWidth: .infinity)
      .frame(height: 36)
      .accessibilityLabel("Day \(day.dayNumber), no commits")
  }
}

// MARK: - Preview Helpers

/// Builds mock calendar days for the current month for use in previews.
///
/// - Parameter todayActive: Whether today should be marked as having a contribution.
/// - Returns: An array of `CalendarDay` values for the current month.
private func makePreviewCalendarDays(todayActive: Bool) -> [CalendarDay] {
  let calendar = Calendar.current
  let today = calendar.startOfDay(for: .now)
  let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
  let range = calendar.range(of: .day, in: .month, for: today) ?? 1..<31
  let firstWeekday = calendar.component(.weekday, from: monthStart)
  let placeholderCount = firstWeekday - 1

  var days: [CalendarDay] = []
  days.reserveCapacity(placeholderCount + range.count)

  for i in 0..<placeholderCount {
    let date =
      calendar.date(byAdding: .day, value: -(placeholderCount - i), to: monthStart) ?? monthStart
    days.append(
      CalendarDay(
        id: date, dayNumber: 0, hasContribution: false,
        isToday: false, isFuture: false, isPlaceholder: true
      )
    )
  }

  for dayNumber in range {
    let date = calendar.date(bySetting: .day, value: dayNumber, of: monthStart) ?? monthStart
    let startOfDay = calendar.startOfDay(for: date)
    let isToday = calendar.isDateInToday(date)
    let isFuture = startOfDay > today
    let hasContribution: Bool
    if isToday {
      hasContribution = todayActive
    } else {
      hasContribution = !isFuture
    }

    days.append(
      CalendarDay(
        id: startOfDay, dayNumber: dayNumber, hasContribution: hasContribution,
        isToday: isToday, isFuture: isFuture, isPlaceholder: false
      )
    )
  }

  return days
}

// MARK: - Previews

#Preview("Streak Calendar") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakCalendarView(
      days: makePreviewCalendarDays(todayActive: false),
      isActiveToday: false
    )
    .frame(width: 572)
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 620, height: 340)
}

#Preview("Streak Calendar - Active Today") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    StreakCalendarView(
      days: makePreviewCalendarDays(todayActive: true),
      isActiveToday: true
    )
    .frame(width: 572)
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 620, height: 340)
}
