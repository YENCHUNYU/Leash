# Languages and full-screen scene

Use the gear button at the top right → Language / 語言 to select English or 繁體中文. The preference uses AppStorage and persists across launches. Initial language follows the device's preferred language, falling back to English. App labels, summaries, alerts, GPS messages, dates and distance formatting follow the selection. iOS permission dialogs and system-owned map labels follow iOS settings.

The room and park now fill the display edge to edge. The header and bottom walk controls respect safe-area insets. The dog wanders within the floor area, pauses between trips, turns toward its destination, and bobs gently. Movement stops when the scene is inactive and respects Reduce Motion.

Verification: Swift parsing passed; executable assertions cover both language selections, GPS translations and load/save errors. AppLanguage type-checks against the iOS SDK. Full SwiftUI build and simulator visual verification remain blocked by this environment's macro-plugin and CoreSimulator restrictions. In Xcode, check both languages, relaunch persistence, portrait/landscape safe areas, dog movement, Reduce Motion, and start/finish a walk.
