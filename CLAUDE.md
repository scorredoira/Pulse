# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a native Swift/SwiftUI Xcode project with **no external dependencies**. Open `Pulse.xcodeproj` in Xcode and build.

**Targets:** macOS (`Pulse`) and iOS (`Pulse iOS`), both under bundle ID `com.microdynamics.pulse`.

**Requirements:** Xcode 15+, macOS 15.0+ deployment target, iOS 17.0+ deployment target.

To build from the command line:
```
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=macOS' build
xcodebuild -project Pulse.xcodeproj -scheme "Pulse iOS" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

There are no tests, linters, or formatters configured.

## Architecture

**Pattern:** SwiftUI + SwiftData with `@Observable` services injected via SwiftUI environment.

### Platform Entry Points
- `App/macOS/PulseApp.swift` — MenuBarExtra scene + separate Window scenes (Dashboard, Exercise Session, Settings). `LSUIElement = true` hides from Dock.
- `App/iOS/PulseApp.swift` — Single WindowGroup with TabView (Timer, Dashboard, Settings).

### Models (SwiftData `@Model`)
All in `Models/`. Core entities: **Exercise**, **Routine** (has-many exercises with cascade delete), **WorkSession** (has-many ExerciseLogs), **ExerciseLog**, **AppSettings** (singleton for preferences).

### Services (`@Observable`, in `Services/`)
- **TimerService** — Multi-timer management for parallel routines. States: idle → running → paused / exerciseTime. Uses `RunLoop.main` with `.common` mode for menu bar responsiveness.
- **ExerciseSessionService** — Orchestrates exercise flow: preparing → running → completed, with phases for exercise/restBetweenSets/restAfterExercise. Produces ExerciseLogs.
- **AudioGuidanceService** — AVSpeechSynthesizer for voice + platform-specific sounds (NSSound on macOS, AudioToolbox on iOS).
- **NotificationService** — Singleton. UNUserNotificationCenter with custom actions (Start, Snooze, Skip).
- **HealthKitService** — Conditional compilation with `#if canImport(HealthKit)`. Logs workouts with mapped activity types.
- **PersistenceService** — Static. Sets up ModelContainer and seeds two default routines on first launch.
- **ScreenActivityService** — macOS only. Pauses timers on screen sleep, resumes on wake.

### Views (in `Views/`)
Organized by feature: `MenuBar/`, `Exercise/`, `Dashboard/`, `Settings/`, `Common/`. Shared design system in `Common/DesignSystem.swift` (CardStyle, PillButtonStyle, etc.).

### Utilities
- `Constants.swift` — Default intervals, window IDs, notification identifiers.
- `TimeFormatting.swift` — Display and spoken duration formatters.

### Core Flow
Timer countdown → notification + audio alert → exercise session window opens → voice-guided exercises with countdowns → session logged to SwiftData (+ optional HealthKit) → timer auto-restarts.

## Key Conventions
- Platform-specific code uses `#if os(macOS)` / `#if os(iOS)` conditionals.
- HealthKit is behind `#if canImport(HealthKit)`.
- Window management on macOS uses `openWindow(id:)` with IDs defined in `Constants.swift`.
- `ENABLE_HARDENED_RUNTIME = NO` for unsigned dev builds; set to YES for production.
