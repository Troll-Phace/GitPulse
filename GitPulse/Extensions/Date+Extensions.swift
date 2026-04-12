//  Date+Extensions.swift
//  GitPulse

import Foundation

extension Date {

  /// Returns the start of the calendar day for this date in the given calendar.
  ///
  /// Wraps `Calendar.startOfDay(for:)` to normalize a date to midnight
  /// in the calendar's time zone.
  /// - Parameter calendar: The calendar (and its associated time zone) used
  ///   to determine the start of day.
  /// - Returns: A `Date` representing midnight at the beginning of this date's day.
  func startOfDay(in calendar: Calendar) -> Date {
    calendar.startOfDay(for: self)
  }

  /// Returns a new date by adding the given number of days in the specified calendar.
  ///
  /// - Parameters:
  ///   - days: The number of days to add. Use negative values to subtract days.
  ///   - calendar: The calendar used for the date arithmetic.
  /// - Returns: A `Date` offset by the specified number of days, or `self`
  ///   if the calendar cannot compute the result.
  func adding(days: Int, in calendar: Calendar) -> Date {
    calendar.date(byAdding: .day, value: days, to: self) ?? self
  }
}
