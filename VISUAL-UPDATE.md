# Leash visual update

The native SwiftUI home and walking screens now follow the supplied HTML: lavender background, pill header, rounded 4:5 room/park scene, pixel dog and circular walk controls. The rectangle scene artwork and polygon icons are translated from the reference into SwiftUI Canvas drawing; no web view or external image dependencies are used.

Tap the door or yellow start button to begin. During a walk, log poop/pee, inspect the route, or tap home to finish. Diary and route sheets retain the tracking functionality. Header counters show actual completed walks and total minutes. Game collection, quests, currency, photos, and profile customization remain outside this milestone. The dog is currently the reference's default tan dog. Artwork switches between day and night; the intermediate sunset colors and wandering animation are not included.

Verification: all four Swift files pass syntax parsing. The native artwork helpers were separately type-checked against the iOS SDK. Full build and visual simulator verification remain unavailable because Swift macro plugin execution and CoreSimulator were blocked in this environment. Open the Desktop/Leash project in Xcode and run it on an iPhone simulator or device.
