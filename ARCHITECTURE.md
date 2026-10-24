# Leash — milestone 1

Feature-first MVVM with injected services. SwiftUI renders state; the view model owns walk actions and coordinates persistence and GPS. Models are Codable values. Service protocols let tests substitute storage and location without GPS or disk. No third-party dependencies.

```
Leash/
  App/                                Entry point; ContentView injects \.appLanguage and \.locale
  Shared/
    Design/                           Theme, Toast, PixelScene, PixelDog (any breed), PixelIcon
    Localization/AppLanguage.swift    English / 繁體中文 selection
    Persistence/JSONFile.swift        Atomic Codable files in Application Support/Leash
  Resources/Spots/                    OpenStreetMap dog parks (Taiwan + US), bundled
  Features/
    Launch/, Settings/
    WalkTracking/
      Models/                         Walk, RouteFilter (GPS rules), typed status and errors
      ViewModels/WalkViewModel.swift  Start (optionally at a spot), finish, log, photos, indoor play
      Services/                       LocationService, WalkStore (active walk + history files)
      Views/                          WalkTrackingView (composition root), WalkHomeView (scene,
                                      header, dock, walk HUD), diary, summary, WanderingDog
    Game/
      Models/                         Breed (25), GameState + DogProfile, GameProgress (XP, level,
                                      treats, streaks, quests, badges, tips), Encounter rules + RNG
      GameModel.swift                 Progress, encounters, treat tosses, profile, milestones
      Views/                          Quests, Dex, Profile, Encounter
    Album/                            PhotoLibrary (JPEG files + index), album, camera picker
    Spots/
      Models/                         Spot (address, hours, facility status, leash policy, source),
                                      ParkQuery (search, filter chips, nearest-first sorting)
      Services/                       SpotCatalog (bundled OSM + custom spots), MapsLauncher
      Views/                          SpotsView (map/list), ParkMapView, ParkDetailView, ParkComponents
LeashTests/                           Swift Testing: GPS filter, view model, storage, game rules
Config/Info.plist                     Background location mode
```

## Game layer

Ported from the HTML prototype. Progress is never stored: XP, level, treats, streaks, quests and badges are recomputed from walk history, photos, custom spots and `GameState` (encounter outcomes, treats spent, friends). Only encounter results and the dog profile are persisted. Visiting dogs appear one minute into a walk, then every eight minutes (up to four); every 120 outdoor minutes hatches an egg dog of uncommon rarity or better. Breeds and toss outcomes come from a string-seeded generator matching the prototype's `hashStr`, so an encounter cannot be rerolled. Hot-weather rules and the Dex region list follow the app language (English uses US seasons and states; Chinese uses Taiwan's), as in the prototype.

## Park discovery

Spots shows parks on a MapKit map (markers for the 150 parks nearest the map centre) or as a list, nearest first from the user's location. Filter chips combine (all must match). Park data is a bundled OpenStreetMap snapshot, not live: facilities are only recorded when present, so a missing tag is shown as "Not verified", never "No". Every OSM dog park is an off-leash area by definition, so that chip barely narrows results. Opening hours are shown as the raw OSM `opening_hours` text when mapped (248 parks), otherwise "Unknown". User-added spots have no coordinates; Go searches Apple Maps by name for them.

"Go" opens walking directions in Apple Maps and saves the park (`leash.plannedSpotID`); the next walk started with the floating Start button is linked to it. The view model can request a single location fix outside walks (`locateUser`) to sort parks by distance.

Not ported: the prototype's cloud account sync, sunset sky colours, and its hand-curated spot list (the bundled OSM data covers the same parks).

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
