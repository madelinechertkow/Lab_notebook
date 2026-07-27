# Lab_notebook

Cazzy — a native macOS lab notebook app (SwiftUI, Swift Package executable).

## Install (no coding needed)

If someone sent you a `Cazzy-x.y.dmg` file:

1. Open it, then drag **Cazzy** into the **Applications** shortcut in the same window.
2. In Applications, **right-click (or Control-click) Cazzy → Open**, then click **Open** again in the dialog that appears.

Step 2 matters — Cazzy isn't notarized by Apple (that requires a paid developer
account), so macOS Gatekeeper blocks a plain double-click the first time with
an "unidentified developer" warning. Right-click → Open is how you tell macOS
you trust it anyway; you only need to do this once. After that it opens
normally, including from Spotlight or the Dock.

## Build & run from source

```sh
scripts/build_app.sh        # builds a debug Cazzy.app
open Cazzy.app
```

`Cazzy.app` isn't tracked in git (Box sync adds metadata that breaks
codesign on a tracked copy), so the script assembles the whole bundle —
`Contents/MacOS`, the icon, `Info.plist` — from scratch rather than assuming
one already exists. Re-run it after any source change; it rebuilds and
re-signs in place.

`Info.plist` is generated from [`Packaging/Info.plist`](Packaging/Info.plist).
If you need to change bundle metadata (version, calendar usage strings,
etc.), edit that file, not a copy inside `Cazzy.app`.

## Package a .dmg to share with someone else

```sh
scripts/make_dmg.sh
```

Produces `Cazzy-x.y.dmg` in the repo root — a release build in a
drag-to-Applications installer window. Send that file to whoever wants
Cazzy; they don't need Swift, Xcode, or the terminal. See the Install
section above for what to tell them about the Gatekeeper prompt.

## Data storage

Data is stored as a single JSON blob in `~/Library/Application Support/Cazzy/data.json`.
