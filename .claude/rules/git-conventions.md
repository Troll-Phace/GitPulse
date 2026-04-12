# Git Conventions

## Commit Format
phase({N}): {concise description of what changed}

Examples:
- phase(1): scaffold Xcode project with SwiftData models and directory structure
- phase(3): implement GitHub API client with async/await networking layer
- phase(7): build dashboard view with contribution heatmap and stat cards
- fix: resolve streak calculation off-by-one for timezone boundary

## Branch Naming
- Feature: phase/{N}-{short-description}
- Fix: fix/{issue-description}
- Experiment: experiment/{description}

## Rules
- Never force-push to main/master
- Stage specific files, not `git add .`
- Never commit .env, secrets, API tokens, or Keychain data
- Never commit .xcodeproj/xcuserdata/ or .DS_Store
- PR titles under 70 characters
- PR body includes: Summary, Test Plan, and phase reference
- Keep .gitignore updated: exclude build products, DerivedData, xcuserdata, .env, *.xcuserstate
