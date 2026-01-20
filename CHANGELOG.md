# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1] - 2026-01-20

### Changed

- Release workflow now extracts version and release notes automatically from CHANGELOG.md

## [1.2.0] - 2026-01-16

### Added

- Pacing risk indicator to usage cards

### Changed

- Rename README directory to docs

### Fixed

- Skip snapshot tests due to rendering differences
- Disable code signing for test workflow

### CI

- Add test workflow to run Xcode tests on push

## [1.1.2] - 2026-01-14

### Changed

- Replace MenuBarExtra with NSStatusItem/NSPopover for improved menu bar behavior
- Modernize app lifecycle and testing architecture

### Added

- Notification tap-to-open functionality

## [1.1.1] - 2026-01-04

### Fixed

- Only show loading spinner when no data exists in menu bar

## [1.1.0] - 2026-01-02

### Added

- Configurable menu bar icon styles
- Homebrew tap distribution
- GitHub Pages landing page

## [1.0.7] - 2025-12-24

### Added

- Export usage data to ~/.claudemeter/usage.json for external tools
- os.log logging for API error debugging

### Fixed

- Force refresh usage data on app boot

## [1.0.6] - 2025-11-26

### Added

- Code signing and notarization to release workflow

## [1.0.5] - 2025-11-25

### Changed

- Replace Opus tracking with Sonnet

### Added

- Tooltip showing exact reset time

### Fixed

- NSUserNotificationsUsageDescription configuration

## [1.0.4] - 2025-11-19

### Fixed

- Change NotificationService from actor to @MainActor class for improved reliability

## [1.0.3] - 2025-11-19

### Fixed

- Improve settings persistence
- Improve notification permission handling

## [1.0.2] - 2025-11-19

### Fixed

- Replace ProgressView with static SF Symbol
- Adjust staleness threshold
- Force UserDefaults sync

## [1.0.1] - 2025-11-18

### Changed

- Clarify Claude.ai plan usage vs developer API in documentation

## [1.0.0] - 2025-11-18

### Added

- Initial ClaudeMeter macOS menu bar app
- Real-time usage monitoring for 5-hour session, 7-day weekly, and Sonnet-specific usage limits
- Menu bar integration with clean, color-coded usage indicator
- Smart notifications with configurable alerts at warning and critical thresholds (defaults: 75% and 90%)
- Auto-refresh with automatic usage updates every 1-10 minutes (customizable)
