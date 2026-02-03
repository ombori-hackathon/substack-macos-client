---
name: feature
description: Build a new Swift/SwiftUI feature with TDD. Creates spec, writes tests first, then implements.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# /feature - Swift Feature Workflow

Build SwiftUI features using test-driven development.

## Usage

```
/feature <brief description of what you want to build>
```

## Workflow

### Step 1: Understand the Feature

Ask the user:
1. **What should this feature do?** (one sentence)
2. **What triggers it?** (button tap, app launch, etc.)
3. **What's the expected UI/result?**
4. **Does it need API calls?** If yes, which endpoint?

### Step 2: Check for Existing Spec

Look for related spec in `../../specs/` (workspace specs folder).
If none exists, create one.

### Step 3: Enter Plan Mode

Use EnterPlanMode to design the implementation:

```markdown
# Feature: [Name]

## Summary
[One sentence description]

## UI Changes
- New view/component: [describe]
- Modified views: [list]

## Model Changes
- New models in Models.swift: [list]

## API Integration (if needed)
- Endpoint: [METHOD /path]
- Request/Response models

## Implementation Plan
1. [ ] Write failing tests
2. [ ] Add models
3. [ ] Create/update views
4. [ ] Add API integration
5. [ ] Run tests
```

### Step 4: TDD Red Phase

1. Create test file: `Tests/SubStackClientTests/FeatureTests.swift`
2. Write tests for new functionality
3. Run `swift test` - confirm FAILS (Red)

### Step 5: TDD Green Phase

1. Add models to `Sources/Models.swift`
2. Create/update views in `Sources/`
3. Add async functions for API calls
4. Run `swift test` - should PASS (Green)

### Step 6: Verify

```bash
swift build
swift test
swift run SubStackClient  # Manual verification
```

### Step 7: Commit

```bash
git checkout -b feature/<name>
git add .
git commit -m "feat: <description>"
git push -u origin feature/<name>
gh pr create --title "feat: <description>" --body "Implements <feature>"
```
