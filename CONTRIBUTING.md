# Contributing to Nexio

Thank you for your interest in contributing. This document explains how to get started.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository and clone your fork
2. Open `Package.swift` in Xcode or your preferred editor
3. Run the test suite to confirm everything passes before making changes

```bash
swift test
```

## Making Changes

- **Bugs** — open an issue first to confirm the behaviour is unintended
- **Features** — open an issue to discuss before spending time on an implementation
- **Docs / tests** — PRs welcome without prior issue

### Branch naming

```
fix/short-description
feat/short-description
docs/short-description
```

### Code style

- Swift 6 strict concurrency must stay clean — no `@unchecked Sendable` without a justifying comment
- No new external dependencies
- Public API changes require a doc comment update and a new test
- Run `swift build -c release` and `swift test` before opening a PR

## Pull Request Checklist

- [ ] `swift build -c release` passes with zero errors and zero warnings
- [ ] `swift test` passes (all platforms you can test)
- [ ] New public API has a doc comment
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] PR description explains *what* changed and *why*

## Reporting Issues

Use GitHub Issues. For security vulnerabilities, see [SECURITY.md](SECURITY.md).
