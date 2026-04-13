//  GlassCard.swift
//  GitPulse

import SwiftUI

/// A generic glass container that applies the Liquid Glass effect with standard padding and corner radius.
///
/// Use `GlassCard` as the foundational wrapper for all content panels in the app.
/// It applies `DesignTokens.spacingMD` padding, the `.glassEffect()` modifier, and clips
/// to a rounded rectangle with `DesignTokens.radiusCard` corner radius.
///
/// ```swift
/// GlassCard {
///     Text("Hello, GitPulse")
///         .font(.gpCardTitle)
/// }
/// ```
struct GlassCard<Content: View>: View {
  let content: Content

  /// Creates a glass card wrapping the provided content.
  /// - Parameter content: A view builder producing the card's interior.
  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    content
      .padding(DesignTokens.spacingMD)
      .glassEffect()
      .clipShape(RoundedRectangle(cornerRadius: DesignTokens.radiusCard))
  }
}

// MARK: - Previews

#Preview("GlassCard — Default") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    GlassCard {
      VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
        Text("Today's Commits")
          .font(.gpCaption)
          .foregroundStyle(Color.gpTextSecondary)
        Text("42")
          .font(.gpSectionHeader)
          .foregroundStyle(Color.gpTextPrimary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: 200)
  }
  .frame(width: 300, height: 200)
}

#Preview("GlassCard — Multiple") {
  ZStack {
    Color.gpBackground.ignoresSafeArea()

    VStack(spacing: DesignTokens.spacingSM) {
      GlassCard {
        HStack {
          Image(systemName: "flame.fill")
            .foregroundStyle(Color.gpOrange)
          Text("Current Streak: 14 days")
            .font(.gpBody)
            .foregroundStyle(Color.gpTextPrimary)
        }
      }

      GlassCard {
        HStack {
          Image(systemName: "star.fill")
            .foregroundStyle(Color.gpGold)
          Text("Longest Streak: 30 days")
            .font(.gpBody)
            .foregroundStyle(Color.gpTextPrimary)
        }
      }
    }
    .padding(DesignTokens.spacingMD)
  }
  .frame(width: 350, height: 250)
}
