//  LanguageStat.swift
//  GitPulse

import Foundation
import SwiftData

/// A programming language usage statistic for a single repository.
///
/// Each `LanguageStat` records the byte count for one language within a
/// repository, as reported by the GitHub Languages API
/// (`/repos/{owner}/{repo}/languages`). The `color` is the hex color
/// associated with the language on GitHub.
@Model
final class LanguageStat {

  /// The name of the programming language (e.g., "Swift", "Python").
  var name: String

  /// The number of bytes of code written in this language within the repository.
  var bytes: Int

  /// The hex color code associated with this language on GitHub (e.g., "#F05138").
  var color: String

  /// The repository this language stat belongs to.
  @Relationship(inverse: \Repository.languages) var repository: Repository?

  /// Creates a new language statistic record.
  /// - Parameters:
  ///   - name: The programming language name.
  ///   - bytes: Byte count of code in this language.
  ///   - color: Hex color string from GitHub.
  ///   - repository: The owning repository (defaults to nil).
  init(
    name: String,
    bytes: Int,
    color: String,
    repository: Repository? = nil
  ) {
    self.name = name
    self.bytes = bytes
    self.color = color
    self.repository = repository
  }
}
