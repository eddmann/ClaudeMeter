# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ClaudeMeter is a macOS menu bar application that monitors Claude.ai plan usage in real-time. It tracks 5-hour session limits, 7-day weekly limits, and Sonnet-specific usage, displaying color-coded indicators and sending notifications when thresholds are reached.

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

# Build release (local development - unsigned)
xcodebuild clean build \
  -project ClaudeMeter.xcodeproj \
  -scheme ClaudeMeter \
  -configuration Release \
  -derivedDataPath ./build \
  -arch x86_64 -arch arm64
```

**Run:** Press ⌘R in Xcode to build and run. The app appears in the menu bar (not the Dock).

## Architecture

### SwiftUI-First (macOS 14+)

The app uses a SwiftUI-first architecture with a single observable app model and actor-isolated infrastructure.

**AppModel** - `ClaudeMeter/App/AppModel.swift`  
`@MainActor @Observable` state owner used by all views.

- Loads settings and session-key state on startup
- Runs the async refresh loop
- Publishes usage data + error state for UI
- Coordinates notifications when new usage arrives

**Scenes**

- `MenuBarExtra` (window style) hosts the popover content
- `Settings` scene uses native tabbed preferences
- Setup wizard shows in the popover until a session key is saved

### Data & Infrastructure

**Repositories (actors)**

- `KeychainRepository` - secure session key storage
- `SettingsRepository` - UserDefaults persistence
- `CacheRepository` - in-memory + disk cache

**Services (actors/main actor)**

- `NetworkService` - Claude API HTTP client
- `UsageService` - fetch + retry + cache integration
- `NotificationService` - evaluates thresholds + sends notifications

### Concurrency Model

- **@MainActor:** `AppModel` and SwiftUI views
- **Actors:** repositories and network/usage services
- **Async/await:** end-to-end request pipeline

### Usage Data Pipeline

1. `AppModel` starts a `ContinuousClock` refresh loop
2. `UsageService` checks cache (TTL)
3. On miss, fetches from Claude API (`/api/organizations/{id}/usage`)
4. Response decoded + cached
5. `AppModel` updates `usageData`
6. `NotificationService` evaluates thresholds + persists notification state
7. UI binds directly to `AppModel` state

### Notification System

Notifications are sent when usage crosses thresholds:

- `NotificationState` tracks last percentage + sent flags
- Honors the “notify on reset” toggle
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

The menu bar icon is a SwiftUI view (`MenuBarIconView`) used directly as the `MenuBarExtra` label:

- Draws gauge segments with color based on `UsageStatus`
- Shows loading/stale state
- Updates automatically as `AppModel` publishes new usage data

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
2. Installs Apple Developer ID certificate from secrets
3. Builds universal binary (x86_64 + arm64) with code signing
4. Submits to Apple for notarization and staples the ticket
5. Creates ZIP archive
6. Generates release notes
7. Creates GitHub release with artifact

**Note:** Release builds are signed with a Developer ID certificate and notarized by Apple. Users can install and run the app without Gatekeeper warnings.

## Common Development Patterns

### Adding a New Setting

1. Add property to AppSettings struct (ClaudeMeter/Models/AppSettings.swift)
2. Implement save/load in SettingsRepository
3. Add UI control in SettingsView
4. Bind the control to `appModel.settings` (AppModel auto-saves on change)
5. If behavior depends on the setting, update AppModel to react (e.g., restart refresh loop)

### Adding a New API Endpoint

1. Define response model in ClaudeMeter/Models/API/
2. Add method to UsageServiceProtocol
3. Implement in UsageService with retry logic
4. Call from AppModel (or a dedicated helper type) and bind UI to AppModel state

### Testing Session Key Validation

Use the setup wizard to test session key validation. The app calls `/api/organizations` to verify the key. Valid keys start with `sk-ant-` and must be active Claude.ai session keys (found in browser cookies at claude.ai).
