---
name: test
description: Run Swift tests and report results.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob
---

# /test - Run Swift Tests

Run tests for the macOS client.

## Usage

```
/test           # Run all tests
/test <name>    # Run tests matching name
```

## Workflow

### Run Tests

```bash
# All tests
swift test

# Specific test class or method
swift test --filter <TestName>

# Verbose output
swift test --verbose
```

### Interpret Results

- **All tests passed**: Report success
- **Tests failed**:
  1. Show which tests failed
  2. Show error messages
  3. Suggest fixes if obvious

### Common Issues

- **Build failed**: Run `swift build` first to see build errors
- **Test not found**: Check test file is in Tests/SubStackClientTests/
- **Async test timeout**: Increase timeout or check for deadlocks
