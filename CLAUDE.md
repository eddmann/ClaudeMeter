# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeMeter is a macOS menu bar application that monitors Claude.ai plan usage in real-time. It tracks 5-hour session limits, 7-day weekly limits, and Opus-specific usage, displaying color-coded indicators and sending notifications when thresholds are reached.

**Platform:** macOS 14.0+ (Sonoma or later)
**Language:** Swift (SwiftUI + AppKit)
**Build System:** Xcode 16.0+

## Build & Run Commands

```bash
# Open in Xcode
open ClaudeMeter.xcodeproj

# Build from command line
xcodebuild clean build \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Debug

# Build release (unsigned)
xcodebuild clean build \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Release \
  -derivedDataPath ./build \
  -arch x86_64 -arch arm64 \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

**Run:** Press ⌘R in Xcode to build and run. The app appears in the menu bar (not the Dock).

## Architecture

### MVVM-C (Model-View-ViewModel-Coordinator)

The app follows the MVVM-C pattern, separating navigation logic (Coordinators) from presentation logic (ViewModels):

**Coordinators** - Handle navigation flow and window/view lifecycle:

1. **AppCoordinator** (ClaudeMeter/App/AppCoordinator.swift:14) - Root coordinator that manages app lifecycle

   - Checks for session key on launch
   - Routes to SetupCoordinator (first-time setup) or MenuBarManager (main app)
   - Manages SettingsCoordinator for preferences window

2. **SetupCoordinator** - Guides user through initial session key configuration

   - Validates session key with Claude API
   - Saves to Keychain on successful validation
   - Calls completion handler to transition to main app

3. **SettingsCoordinator** - Manages settings window lifecycle and presentation

4. **MenuBarManager** (ClaudeMeter/Views/MenuBar/MenuBarManager.swift:14) - Acts as coordinator for menu bar
   - Owns NSStatusItem and NSPopover
   - Creates and configures ViewModels
   - Observes ViewModel changes to update UI

**ViewModels** - Handle presentation logic and business logic coordination:

Views use dedicated ViewModels that interact with services through protocols:

- **MenuBarViewModel** (ClaudeMeter/ViewModels/MenuBarViewModel.swift:14) - Manages auto-refresh timer, fetches usage data, checks notification thresholds
- **UsagePopoverViewModel** - Displays detailed usage breakdown in popover
- **SettingsViewModel** - Handles preference changes and validation
- **SetupViewModel** - Manages setup wizard state and validation

### Dependency Injection

**DIContainer** (ClaudeMeter/DependencyInjection/DIContainer.swift:12) - Single shared container that creates and owns all dependencies:

**Repositories:**

- KeychainRepository (actor) - Secure session key storage using macOS Keychain
- SettingsRepository (actor) - UserDefaults persistence for app settings
- CacheRepository (actor) - In-memory cache with TTL for usage data (55s TTL)

**Services:**

- NetworkService (actor) - HTTP client for Claude API
- UsageService (actor) - Fetches usage data with exponential backoff retry (3 attempts, 2x backoff for network errors, 3x for rate limits)
- NotificationService - Sends macOS notifications for threshold warnings

All repositories and services implement protocols for testability.

### Concurrency Model

- **All actors:** Repositories and most services are `actor`-isolated for thread-safe state management
- **@MainActor:** Coordinators, ViewModels, and MenuBarManager are `@MainActor` for UI operations
- **Async/await:** Used throughout for API calls and data fetching

### Usage Data Pipeline

1. MenuBarViewModel triggers refresh on timer (60s default, configurable 60-600s)
2. UsageService checks CacheRepository (55s TTL)
3. If cache miss, fetches from Claude API (`/api/organizations/{id}/usage`)
4. NetworkService performs request with retry logic
5. Response cached and returned to ViewModel
6. ViewModel updates @Published properties
7. MenuBarManager observes changes and re-renders icon
8. Icon cached in IconCache (LRU, max 100 entries)

### Notification System

Notifications are sent when usage percentages cross thresholds (default 75% warning, 90% critical):

- NotificationState (ClaudeMeter/Models/NotificationState.swift) tracks last notification sent
- Prevents duplicate notifications for same threshold
- Sends reset notification when usage drops below warning threshold
- Uses UserNotificationCenter with banner and sound

## Key Implementation Details

### Session Key Handling

Session keys (format: `sk-ant-*`) are stored securely in Keychain with:

- Service: `com.claudemeter.sessionkey`
- Account: `"default"`
- Accessible: After first unlock only
- Not synchronized across devices

Session keys may contain embedded organization UUID after the hyphen (e.g., `sk-ant-{uuid}`), which is extracted and cached to avoid organization list API calls.

### Menu Bar Icon Rendering

Icons are rendered dynamically using MenuBarIconRenderer (ClaudeMeter/Views/MenuBar/MenuBarIconRenderer.swift):

- Draws gauge segments with color based on UsageStatus (safe: green, warning: yellow, critical: red)
- Shows loading spinner animation
- Indicates stale data (>10s old) with visual cue
- Cached by IconCache with composite key: (percentage, status, isLoading, isStale)

### Error Handling & Retry

UsageService implements exponential backoff for transient failures:

- Network unavailable: 2.0^attempt delay, max 3 retries
- Rate limit: 3.0^attempt delay (more aggressive)
- Auth failure: Immediate error, no retry
- Falls back to last known cached data if all retries fail

### Constants

Key constants in ClaudeMeter/Models/Constants.swift:42:

- Cache TTL: 55 seconds (slightly less than minimum refresh)
- Network retries: 3 attempts
- Refresh intervals: 60-600 seconds
- Icon cache size: 100 entries

## Release Process

Releases are created via GitHub Actions workflow (`.github/workflows/release.yml`):

```bash
# Trigger release from GitHub UI
# Go to Actions → Release ClaudeMeter → Run workflow
# Enter version number (e.g., 1.0.0)
```

The workflow:

1. Updates MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.pbxproj
2. Builds unsigned universal binary (x86_64 + arm64)
3. Creates ZIP archive
4. Generates release notes
5. Creates GitHub release with artifact

**Note:** Builds are unsigned and require users to right-click → Open or run `xattr -cr` to bypass Gatekeeper.

## Common Development Patterns

### Adding a New Setting

1. Add property to AppSettings struct (ClaudeMeter/Models/AppSettings.swift)
2. Implement save/load in SettingsRepository
3. Add UI control in SettingsView
4. Update SettingsViewModel to bind to the setting
5. Post `.settingsDidChange` notification if live update needed

### Adding a New API Endpoint

1. Define response model in ClaudeMeter/Models/API/
2. Add method to UsageServiceProtocol
3. Implement in UsageService with retry logic
4. Call from ViewModel or Coordinator

### Testing Session Key Validation

Use the setup wizard to test session key validation. The app calls `/api/organizations` to verify the key. Valid keys start with `sk-ant-` and must be active Claude.ai session keys (found in browser cookies at claude.ai).
