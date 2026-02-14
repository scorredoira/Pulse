# Pulse

A macOS and iOS app that reminds you to take exercise breaks during work sessions. On macOS it lives in the menu bar; on iOS it works as a standalone app.

## Screenshots

### iOS

<p align="center">
  <img src="Screenshots/ios_timer.png" width="200" alt="Timer" />
  <img src="Screenshots/ios_dashboard.png" width="200" alt="Dashboard" />
  <img src="Screenshots/ios_settings.png" width="200" alt="Routines" />
  <img src="Screenshots/ios_exercise_edit.png" width="200" alt="Exercise Editor" />
</p>

### macOS

<p align="center">
  <img src="Screenshots/macos_menubar.png" width="280" alt="Menu Bar Timer" />
  <img src="Screenshots/macos_settings.png" width="480" alt="Settings" />
</p>

## Features

- **Work interval timers** — Set how long you want to work before taking a break (default: 45 minutes). Multiple routines can run in parallel with independent intervals.
- **Exercise routines** — Create custom routines with exercises, sets, rest periods, and ordering. Supports both time-based and rep-based exercises.
- **Voice guidance** — Audio announcements and countdowns guide you through each exercise hands-free.
- **Auto-start exercises** — When a timer completes, exercises begin automatically after a short countdown. You can postpone if needed.
- **Exercise images** — Attach reference images to exercises. Images display as a carousel during sessions.
- **Smart screen detection** (macOS) — Timers pause when your screen sleeps and resume when you're back.
- **Notifications** — System notifications with quick actions to start, snooze, or skip exercises.
- **Dashboard** — Daily and weekly stats, exercise history, and streak tracking.
- **HealthKit integration** (iOS) — Optionally log completed exercises to Apple Health.
- **Import/Export** — Share routines between devices as `.pulse` or `.json` files via AirDrop or Files.

## Requirements

- macOS 15.0+ / iOS 18.0+
- Xcode 15+

## Building

Open `Pulse.xcodeproj` in Xcode and run. No external dependencies.

```bash
# macOS
xcodebuild -scheme Pulse -destination 'platform=macOS' build

# iOS
xcodebuild -scheme "Pulse iOS" -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Routine Import/Export

Pulse supports importing and exporting routines as JSON files with embedded images.

**File paths:**
- macOS: `~/.config/pulse/routines.json`
- iOS: Shared via AirDrop using `.pulse` files, or through the Files app

**How to import on iOS:**
1. Send a `.pulse` file via AirDrop to your device
2. Open it — Pulse will import the routines automatically

**How to import on macOS:**
1. Open Settings → Export (creates `~/.config/pulse/routines.json`)
2. Edit the file in any text editor
3. Changes are auto-imported via file watching

### JSON Format

```json
{
  "routines": [
    {
      "name": "My Routine",
      "isDefault": false,
      "intervalMinutes": 45,
      "isActive": true,
      "exercises": [
        {
          "name": "Exercise Name",
          "durationSeconds": 30,
          "description": "How to perform the exercise",
          "iconName": "figure.walk",
          "sortOrder": 0,
          "sets": 3,
          "restSeconds": 15,
          "restAfterSeconds": 30,
          "images": ["<base64-encoded-png>"],
          "reps": 12,
          "secondsPerRep": 5
        }
      ]
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Exercise or routine name |
| `durationSeconds` | Yes* | Duration in seconds (*auto-calculated if `reps` is set) |
| `sets` | Yes | Number of sets (minimum 1) |
| `restSeconds` | Yes | Rest between sets in seconds |
| `restAfterSeconds` | Yes | Rest after exercise in seconds |
| `iconName` | Yes | SF Symbol name |
| `sortOrder` | Yes | Display order (0-based) |
| `images` | No | Array of Base64-encoded PNG/JPEG data |
| `reps` | No | Number of repetitions (omit or 0 for time-based) |
| `secondsPerRep` | No | Seconds per rep (default 5) |

## License

MIT
