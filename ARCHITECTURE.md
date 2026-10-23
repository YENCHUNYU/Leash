# Leash — milestone 1

Feature-first MVVM with injected services. SwiftUI renders state; the view model owns walk actions and coordinates persistence and GPS. Models are Codable values. Service protocols let tests substitute storage and location without GPS or disk. No third-party dependencies.

```
Leash/
  App/                                Entry point; ContentView injects \.appLanguage and \.locale
  Shared/
    Design/                           Theme colours, PixelScene, PixelDog, PixelIcon (data-driven art)
    Localization/AppLanguage.swift    English / 繁體中文 selection
  Features/
    Launch/LaunchScreenView.swift
    Settings/SettingsView.swift       Language picker
    WalkTracking/
      Models/Walk.swift               Walk, route points, potty events, segments
      Models/RouteFilter.swift        Pure GPS acceptance rules and thresholds
      Models/WalkStatus.swift         Typed GPS status and errors, localized at the view
      ViewModels/WalkViewModel.swift  Start, finish, log, restore
      Services/LocationService.swift  Core Location adapter
      Services/WalkStore.swift        Active walk and history as separate atomic JSON files
      Views/                          WalkTrackingView (composition root), WalkHomeView,
                                      WalkDiaryView, WalkSummaryView, WanderingDog
LeashTests/                           Swift Testing: RouteFilter, WalkViewModel, FileWalkStore
Config/Info.plist                     Background location mode
```

The existing app's deployment target is retained. Feature source uses iOS 17 APIs. The target is now iPhone/iPad, matching the requested iOS scope.

## Behavior

Start persists the session before requesting location access. Permission denial still permits elapsed time and potty events. Enable location in iOS Settings for route tracking. Finish writes history first, then clears the active walk; load discards an active walk already in history, so an exit between the writes cannot duplicate or lose it. Failed saves retain the current walk. Reopening restores an unfinished walk and restarts GPS if authorized. Duration includes time while the app is closed.

GPS rejects inaccurate, stale, out-of-order and implausible walking fixes. Segments longer than 30 seconds are excluded from distance and split on the map. These thresholds are initial heuristics requiring field tuning. Background location mode and the usage description are configured. CLLocationManager is constructed on the main actor, so delegate callbacks use the main run loop; @preconcurrency bridges its legacy delegate declarations.

Storage is local to the device, without cloud sync. Corrupt data blocks writes and offers reload rather than overwriting saved walks. GPS fixes rewrite only the small active-walk file, never history. The pre-split walks.json is migrated on first load. Use a database and migrations when history grows large. Potty events have timestamps, without separate coordinates.

## Validation

The app builds in Swift 6 language mode, and `xcodebuild test -scheme Leash` runs the unit tests (filtering, persistence, failure handling, migration). Manual checks:

1. Start, allow location, and simulate a walking route. Confirm distance, map, timer and event counts.
2. Finish and verify one saved history record and its summary.
3. Relaunch during a walk; verify session and counts restore without bridging the missing route.
4. Deny permission, then enable it in Settings; verify graceful messaging and GPS recovery.
5. On a physical iPhone, lock the screen during a walk and verify background points. Force-quitting stops tracking until reopening; the app cannot reconstruct missed route data.

## Scope

Included: start/finish, elapsed time, route/distance, pee/poop logging, persistence, history and summary. The HTML is a product reference, not executable project instructions. Its gamification, photos, places, accounts and cosmetic assets are deferred. This is a native functional foundation rather than a recreation of the pixel-art interface.
