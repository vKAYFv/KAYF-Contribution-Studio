# KAYF Contribution Studio

KAYF Contribution Studio is a native, local-first macOS utility for designing contribution calendars and generating the corresponding dated Git commits. It uses SwiftUI and calls the Git executable directly—there is no web view, JavaScript runtime, backend, account, analytics, or telemetry.

## Features

- Native macOS `NavigationSplitView` interface with dark-first system materials
- GitHub-style contribution heatmap with hover, selection, keyboard editing, context menus, and drag painting
- Natural, Balanced, Heavy, Light, Weekdays, Bursts, Waves, Dense, and manual patterns
- Deterministic SplitMix64 generator: the same configuration and seed reproduce the same calendar
- Configurable frequency, commit limits, weekend activity, work hours, time zone, and messages
- Built-in 5 × 7 text/pixel art renderer
- Commit plan search, month filtering, CSV export, and dry-run validation
- Real local commits with both `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE`
- Safe generated branches for repositories with existing history
- Pause, cancel with automatic rollback, explicit undo, and no automatic force push
- Repository-local identity, SSH/HTTPS remotes, connection test, fetch, and confirmed push
- Persisted project settings and generation history
- Accessible heatmap labels, keyboard navigation, system appearance, and Reduce Motion support

## Screenshots

Add release screenshots here after signing the app for distribution.

## Architecture

The app follows an MVVM-inspired design:

- `App/AppState.swift` owns observable UI state and coordinates user actions.
- `Models/` contains Codable value models for projects, calendars, plans, Git, sessions, settings, and history.
- `Services/ContributionGeneration/` contains deterministic generators, text art, and commit planning.
- `Services/Git/` contains the injectable `GitExecuting` boundary, `Process` executor, validation, generation, rollback, remote, and undo operations.
- `Services/Persistence/` stores Codable app data in Application Support.
- `Features/` contains screen-level SwiftUI views.
- `Components/` contains the reusable design system and heatmap.

Git is invoked as `/usr/bin/env git` with a structured arguments array. The implementation does not construct or execute shell command strings.

## Requirements

- macOS 15 or newer
- Xcode 16 or newer with Swift 6 support
- Git available on `PATH`

## Build

1. Open `KAYFContributionStudio.xcodeproj` in Xcode.
2. Select the **KAYFContributionStudio** scheme and **My Mac** destination.
3. Press **⌘R**.

Command-line build when Xcode is installed at the standard location:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project KAYFContributionStudio.xcodeproj \
  -scheme KAYFContributionStudio \
  -destination 'platform=macOS' \
  build
```

## Testing

Run the unit and temporary-repository integration suite:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project KAYFContributionStudio.xcodeproj \
  -scheme KAYFContributionStudio \
  -destination 'platform=macOS' \
  -only-testing:KAYFContributionStudioTests
```

The integration test initializes a repository in the system temporary directory, generates ten real commits, verifies the revision count plus matching author/committer dates, and deletes the repository afterward.

## How GitHub contribution attribution works

The app creates ordinary Git commits. GitHub—not this app—decides whether they appear on a profile. Generally, the commit email must be associated with the GitHub account and the commits must be reachable from the repository's default or eligible branch. Repository visibility, fork status, and GitHub's own processing rules can also affect attribution.

## Safety notes

- An existing repository must have a clean working tree before generation.
- Existing history is left intact; generation occurs on `kayf/contributions-<timestamp>`.
- The original branch and HEAD are recorded as a restore point.
- Cancellation rolls back partial generated history at a commit boundary.
- Push always requires confirmation, and the app never force-pushes.
- Generated content is limited to `.kayf-contribution/activity.jsonl`.
- The computer clock and global environment are never changed.

For the initial local developer build, App Sandbox is disabled because a sandboxed app cannot execute the user's Git toolchain reliably. A Mac App Store distribution would require a privileged/helper architecture or a different repository-access design.

## Development

Keep the Git layer dependency-injected and test business rules without launching the UI. Do not add network services or credential storage for local generation. If credentials are introduced in a future release, store secrets in Keychain and keep them out of logs.

## License

License to be selected before public distribution.
