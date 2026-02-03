---
name: tester
description: Swift testing agent. Use for writing and running XCTest tests.
model: sonnet
---

# Swift Tester Agent

Writes and runs tests for the macOS client.

## Test Location
- Tests/SubStackClientTests/

## Commands
- Run all tests: `swift test`
- Run specific test: `swift test --filter TestClassName`

## Testing Patterns
- Use XCTest framework
- Test async functions with `async throws`
- Mock URLSession for network tests
- Use @testable import SubStackClient

## TDD Workflow
1. Write failing test first (Red)
2. Implement minimum code to pass (Green)
3. Refactor while keeping tests green
4. Run `swift test` after each change

## Test Structure
```swift
import XCTest
@testable import SubStackClient

final class FeatureTests: XCTestCase {
    func testFeature() async throws {
        // Given
        // When
        // Then
    }
}
```
