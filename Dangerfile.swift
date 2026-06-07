// Copyright (c) 2026 ANSCoder
// Licensed under the MIT License. See LICENSE in the project root for details.

import Danger

let danger = Danger()

// Warn on large PRs
let bigPRThreshold = 400
let additions = danger.github.pullRequest.additions ?? 0
let deletions = danger.github.pullRequest.deletions ?? 0
if additions + deletions > bigPRThreshold {
    warn("PR is large (\(additions + deletions) lines). Consider splitting.")
}

// Require CHANGELOG update for non-trivial PRs
let hasChangelogUpdate = danger.git.modifiedFiles.contains("CHANGELOG.md")
    || danger.git.createdFiles.contains("CHANGELOG.md")
let isTrivial = danger.github.pullRequest.title.contains("[trivial]")
    || danger.github.pullRequest.title.contains("docs:")
    || danger.github.pullRequest.title.contains("chore:")
if !hasChangelogUpdate && !isTrivial {
    warn("No `CHANGELOG.md` update. Add an entry under `[Unreleased]` or prefix title with `chore:`/`docs:` to skip.")
}

// Require PR description
let bodyLength = danger.github.pullRequest.body?.count ?? 0
if bodyLength < 20 {
    fail("PR description is too short. Explain what changed and why.")
}

// Warn if tests were not touched when source was modified
let sourceChanged = danger.git.modifiedFiles.contains { $0.hasPrefix("Sources/") }
let testsChanged = danger.git.modifiedFiles.contains { $0.hasPrefix("Tests/") }
    || danger.git.createdFiles.contains { $0.hasPrefix("Tests/") }
if sourceChanged && !testsChanged {
    warn("Source files changed but no test files modified. Add or update tests where appropriate.")
}
