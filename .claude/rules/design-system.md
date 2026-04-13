---
paths:
  - "GitPulse/Views/**/*.swift"
  - "GitPulse/Components/**/*.swift"
  - "GitPulseWidget/**/*.swift"
---

# Design System Rules

- **WIREFRAME FIRST**: Before implementing any view, read the corresponding wireframe from `wireframes/` — see .claude/rules/wireframe-required.md for the mapping
- Use design tokens from docs/DESIGN_SYSTEM.md — NEVER hardcode colors, spacing, or font sizes
- Use Color extension tokens (e.g., `.commitGreen`, `.linkBlue`, `.streakOrange`) — never raw hex/RGB
- Use spacing scale tokens (e.g., `.spacingS`, `.spacingM`) — no arbitrary pixel values
- All text must meet WCAG AA contrast ratio (4.5:1 minimum) against the dark background
- Focus indicators on all interactive elements — use `.focusable()` and `.focusEffectDisabled()` appropriately
- Respect `@Environment(\.accessibilityReduceMotion)` for all animations
- Reference docs/DESIGN_SYSTEM.md for all token values and component specs
- Liquid Glass: use `.glassEffect(.regular)` for standard panels, tinted variants for status cards
- Use `GlassEffectContainer` when grouping multiple glass elements (stat card rows, tab bars)
- Glass sparingly — hero elements and navigation, not every surface
- Dark theme is the only theme — design for #0D0D0F background exclusively
- Accent colors are reserved for semantic meaning: green=commits/positive, blue=links/navigation, purple=merges, orange=streaks/warnings, gold=personal bests
