# Lab_notebook

Cazzy — a native macOS lab notebook app (SwiftUI, Swift Package executable).

## Build & run

```sh
swift build
cp .build/debug/Cazzy Cazzy.app/Contents/MacOS/Cazzy
xattr -cr Cazzy.app        # Box sync adds metadata that breaks codesign
codesign --force --sign - Cazzy.app
open Cazzy.app
```

The `Cazzy.app` bundle is not tracked in git. If it needs to be recreated, its
`Contents/Info.plist` must include the calendar usage-description keys or the
experiment calendar's busy/free feature can't prompt for permission:

```xml
<key>NSCalendarsUsageDescription</key>
<string>Cazzy checks when you're busy so you can plan experiments in free time slots, and can optionally add scheduled experiments to your calendar.</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Cazzy checks when you're busy so you can plan experiments in free time slots, and can optionally add scheduled experiments to your calendar.</string>
```

Data is stored as a single JSON blob in `~/Library/Application Support/Cazzy/data.json`.
