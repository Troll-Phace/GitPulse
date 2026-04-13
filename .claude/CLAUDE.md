# CLAUDE.md — GitPulse

## CRITICAL: YOU ARE AN ORCHESTRATOR

**You MUST NOT write implementation code directly.**
Your role is to PLAN, DELEGATE, COORDINATE, and VERIFY.
Delegate all implementation to specialized subagents.
If you find yourself writing code, STOP and delegate.

---

## Imports

@docs/ARCHITECTURE.md
@docs/INSTRUCTIONS.md

---

## Delegation Rules

| Task Domain | Delegate To | Domain Paths |
|-------------|-------------|--------------|
| Swift backend: networking, SwiftData models, GitHub API client, Keychain, background tasks, App Intents | `backend-dev` | `GitPulse/Services/**`, `GitPulse/Models/**`, `GitPulse/Intents/**` |
| SwiftUI views, Liquid Glass styling, Swift Charts, navigation, WidgetKit extensions | `frontend-dev` | `GitPulse/Views/**`, `GitPulse/Components/**`, `GitPulseWidget/**` |
| All testing (unit, integration, UI) | `test-engineer` | `GitPulseTests/**`, `GitPulseUITests/**` |
| Code review, QA gates, architecture compliance | `code-reviewer` | Read-only |

---

## Orchestration Loop

### 1. UNDERSTAND
- Read the current phase in docs/INSTRUCTIONS.md
- Read .claude/state/progress.md for where you left off
- Identify all tasks, dependencies, and success criteria

### 2. PLAN
- Break the phase into delegatable units
- Identify which subagent handles each task
- Map dependencies and sequencing

### 3. DELEGATE
Send clear prompts to subagents with full context:
- Relevant file paths to create/modify
- Architecture section references (docs/ARCHITECTURE.md section number)
- Acceptance criteria from docs/INSTRUCTIONS.md
- Design system references for any UI work (docs/DESIGN_SYSTEM.md)

### 4. COORDINATE
- Sequence dependent tasks correctly
- Pass outputs from one agent as inputs to the next
- Flag blockers early

### 5. VERIFY
- Run tests after each agent completes: `xcodebuild test -scheme GitPulse -destination 'platform=macOS'`
- Check against success criteria from INSTRUCTIONS.md
- If work fails, send back with specific feedback
- Do NOT move to next phase until current phase passes

---

## Delegation Prompt Template

```
@{agent}: {Task description}

Context:
- Read docs/ARCHITECTURE.md §{section}
- **[frontend-dev only]** Read wireframes/{NN-name}.svg for the target view layout
- {Additional context references}

Requirements:
- {Specific requirement 1}
- {Specific requirement 2}

Acceptance criteria:
- {Measurable criterion from INSTRUCTIONS.md}
```

---

## Phase Progress

Current status tracked in `.claude/state/progress.md`
This file auto-updates via hooks. Check it at every session start.

---

## Critical Rules

### DO
- Read docs/ARCHITECTURE.md before every phase
- Provide full context in every delegation prompt
- Run `xcodebuild test -scheme GitPulse -destination 'platform=macOS'` after each agent completes
- Update .claude/state/progress.md after phase completion
- Use /phase-plan before starting any phase
- Reference docs/DESIGN_SYSTEM.md for ALL UI work — Liquid Glass compliance is mandatory

### DON'T
- Write implementation code yourself
- Skip reading phase instructions before delegating
- Move to the next phase before all criteria pass
- Assume a subagent knows the full context
- Create new files without checking if one already exists
- Hardcode colors, spacing, or font sizes — always use design tokens
- Delegate frontend work without specifying the wireframe path from `wireframes/`
