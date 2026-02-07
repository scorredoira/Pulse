# Pulse - Plan de Implementación

## Estado Actual - BUILD SUCCEEDED
- [x] Estructura de directorios creada
- [x] Modelos SwiftData (Exercise, Routine, WorkSession, ExerciseLog, AppSettings)
- [x] Servicios (TimerService, ExerciseSessionService, AudioGuidanceService, NotificationService, HealthKitService, PersistenceService)
- [x] Vistas MenuBar (MenuBarContentView, TimerDisplayView, QuickActionsView)
- [x] Vistas Exercise (ExerciseSessionView, ExerciseStepView, ExerciseCompleteView)
- [x] Vistas Dashboard (DashboardView, DailyStatsChart, WeeklyStatsChart, StreakView, ExerciseHistoryList)
- [x] Vistas Settings (SettingsView, GeneralSettingsTab, RoutineSettingsTab, HealthSettingsTab)
- [x] Vistas Common (CircularProgressView)
- [x] Utilities (Constants, TimeFormatting)
- [x] Resources (DefaultRoutines.json, Assets.xcassets)
- [x] App entry point (PulseApp.swift, Info.plist, Entitlements)
- [x] Xcode project file (.xcodeproj)

## Notas
- Entitlements están vacíos para permitir build sin certificado de desarrollo
- Para HealthKit: añadir entitlements de vuelta cuando se tenga team de desarrollo configurado
- `ENABLE_HARDENED_RUNTIME = NO` para builds sin signing. Cambiar a YES para producción
- Para ejecutar: `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` y luego abrir en Xcode

## Estructura del Proyecto

```
Pulse/
├── App/
│   ├── PulseApp.swift           # @main, MenuBarExtra + Window scenes
│   └── Info.plist                    # LSUIElement = true
├── Models/
│   ├── Exercise.swift               # @Model: nombre, duración, icono, tipo HealthKit
│   ├── Routine.swift                # @Model: lista ordenada de ejercicios
│   ├── WorkSession.swift            # @Model: sesión de trabajo completada
│   ├── ExerciseLog.swift            # @Model: ejercicio completado
│   └── AppSettings.swift            # @Model: singleton de preferencias
├── Services/
│   ├── TimerService.swift           # @Observable: countdown del intervalo
│   ├── ExerciseSessionService.swift # @Observable: ejecuta rutina paso a paso
│   ├── AudioGuidanceService.swift   # AVSpeechSynthesizer + beeps
│   ├── NotificationService.swift    # UNUserNotificationCenter
│   ├── HealthKitService.swift       # HKHealthStore (condicional)
│   └── PersistenceService.swift     # ModelContainer setup + seed data
├── Views/
│   ├── MenuBar/
│   │   ├── MenuBarContentView.swift
│   │   ├── TimerDisplayView.swift
│   │   └── QuickActionsView.swift
│   ├── Exercise/
│   │   ├── ExerciseSessionView.swift
│   │   ├── ExerciseStepView.swift
│   │   └── ExerciseCompleteView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── DailyStatsChart.swift
│   │   ├── WeeklyStatsChart.swift
│   │   ├── StreakView.swift
│   │   └── ExerciseHistoryList.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsTab.swift
│   │   ├── RoutineSettingsTab.swift
│   │   └── HealthSettingsTab.swift
│   └── Common/
│       └── CircularProgressView.swift
├── Utilities/
│   ├── Constants.swift
│   └── TimeFormatting.swift
├── Resources/
│   ├── Assets.xcassets
│   └── DefaultRoutines.json
└── Pulse.entitlements
```

## Modelos de Datos

### Exercise
- `name: String`, `durationSeconds: Int`, `exerciseDescription: String`
- `iconName: String` (SF Symbol), `healthKitActivityType: Int?`
- `sortOrder: Int`, relación inversa con `Routine`

### Routine
- `name: String`, `isDefault: Bool`
- `@Relationship(deleteRule: .cascade)` exercises: [Exercise]

### WorkSession
- `startDate: Date`, `endDate: Date?`, `workIntervalMinutes: Int`, `wasCompleted: Bool`
- `@Relationship(deleteRule: .cascade)` exerciseLogs: [ExerciseLog]

### ExerciseLog
- `exerciseName: String`, `durationSeconds: Int`, `completedAt: Date`
- `skipped: Bool`, `healthKitSynced: Bool`

### AppSettings (singleton)
- `workIntervalMinutes: Int` (default 45), `soundEnabled`, `voiceGuidanceEnabled`
- `speechRate: Float`, `healthKitEnabled`, `launchAtLogin`

## Servicios

### TimerService (@Observable)
- Estados: `.idle` → `.running` → `.paused` / `.exerciseTime`
- Timer cada 1s en RunLoop.main modo .common
- `displayString` ("32:15") para menu bar label
- Callback `onWorkIntervalComplete`

### ExerciseSessionService (@Observable)
- Recorre ejercicios secuencialmente
- Coordina con AudioGuidanceService para TTS
- Produce ExerciseLogs al finalizar
- Dispara HealthKit

### AudioGuidanceService
- AVSpeechSynthesizer para voz
- AVAudioPlayer para beeps de transición
- Anuncia: nombre, duración, countdown (10, 5, 3, 2, 1), completado

### NotificationService
- UNUserNotificationCenter con acciones (Start/Snooze/Skip)

### HealthKitService
- `#if canImport(HealthKit)` compilación condicional
- Logea HKWorkout con activityType mapeado

### PersistenceService
- ModelContainer setup + seed data

## Flujo Principal
```
Timer (45 min) → 0 → Notificación + Alerta → Ventana Exercise Session
→ TTS guía ejercicios → Countdown por ejercicio → Log SwiftData + HealthKit
→ Timer reinicia automáticamente
```

## Menu Bar
- `MenuBarExtra` con `.menuBarExtraStyle(.window)`
- Label dinámico: countdown cuando corre, solo icono cuando idle
- `LSUIElement = true` para ocultar del Dock
- Ventanas separadas via `Window(id:)` + `openWindow(id:)`
