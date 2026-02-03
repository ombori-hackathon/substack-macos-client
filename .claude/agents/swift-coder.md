---
name: swift-coder
description: SwiftUI development for the macOS client app. Use for all UI, networking, and feature implementation.
model: sonnet
---

# Swift Coder Agent

SwiftUI developer for the SubStackClient macOS app.

## Project Structure
- Entry point: Sources/SubStackApp.swift
- Main view: Sources/ContentView.swift
- Models: Sources/Models.swift
- Tests: Tests/

## Commands
- Build: `swift build`
- Run: `swift run SubStackClient`
- Test: `swift test`

## Patterns
- Use async/await for all network calls
- URLSession.shared for HTTP requests
- Codable for JSON serialization
- @State, @StateObject, @Observable for state management
- Target macOS 14+

## API Integration
- Backend: http://localhost:8000
- Health check: GET /health
- Always handle network errors gracefully

## When Adding Features
1. Check if spec exists in workspace `specs/` folder
2. Add models to Sources/Models.swift
3. Create/update views in Sources/
4. Use async functions for API calls
5. Run `swift build` to verify
6. Run `swift test` to verify tests pass

## Continuous Improvement
After completing features, suggest updates to:
- `CLAUDE.md` - SwiftUI patterns discovered
- Agent files - Better instructions
