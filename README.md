# Lab_notebook

Cazzy — a native macOS lab notebook app (SwiftUI, Swift Package executable).
Requires macOS 13 or later.

## What's in it

- **Notebooks and entries** — Markdown entries organized into notebooks, with
  tags, search, images, spell check, Greek letters/fractions, and custom
  special-character shortcuts. Entries open in a formatted **View** mode; the
  pencil switches to **Edit** and keeps your place.
- **Protocols** — a reusable library with buffer recipes (C₁V₁ = C₂V₂ amounts
  worked out for you), materials grouped by category, steps with sections,
  notes, warnings and pause points, step tables and a dilution calculator, a
  bench-friendly View mode with tick-offs, saved versions, printing, and
  export as PDF, Markdown or a shareable `.cazzyprotocol` file. Entries can
  reference the protocol version they used, and each protocol lists the
  entries that used it.
- **Calendar and to-dos** — schedule experiments from protocols, see Apple
  Calendar busy times, and keep a dated to-do list with subtasks.
- **Bench and analysis tools** — plate maps, labelled gel images with ladder
  presets, a paper tracker that auto-fills from a DOI, linked files, and
  runnable Python/R/Bash code blocks in Dry Lab notebooks.
- **Box backup** — a readable Markdown copy of everything in Box Drive.

The full user guide is built into the app: **Settings → Manual → Open Manual…**
(source: [`ManualView.swift`](Sources/Cazzy/Views/ManualView.swift) — update it
alongside any user-visible change).

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
scripts/build_app.sh            # debug build of Cazzy.app (quick to compile)
scripts/build_app.sh release    # optimized build — use this for everyday use
open Cazzy.app
```

The debug build is noticeably slower to use; build `release` for anything
you'll actually work in.

`Cazzy.app` isn't tracked in git (Box sync adds metadata that breaks
codesign on a tracked copy), so the script assembles the whole bundle —
`Contents/MacOS`, the icon, `Info.plist` — from scratch rather than assuming
one already exists. Re-run it after any source change; it rebuilds and
re-signs in place.

`Info.plist` is generated from [`Packaging/Info.plist`](Packaging/Info.plist).
If you need to change bundle metadata (version, calendar usage strings,
the `.cazzyprotocol` document type, etc.), edit that file, not a copy inside
`Cazzy.app`.

### Updating the installed copy

To replace the copy in `/Applications` with a fresh build:

1. Back up your data first: copy `~/Library/Application Support/Cazzy/data.json`
   to a dated name in the same folder (e.g. `data-before-<change>-<date>.json`).
2. `scripts/build_app.sh release`
3. Quit Cazzy normally (⌘Q — not Force Quit), replace `/Applications/Cazzy.app`
   with the freshly built `Cazzy.app`, and open it again.

### Testing on a copy of your data

Point Cazzy at a different data folder so a test run can never touch your real
notes (Box backup is switched off in this mode):

```sh
CAZZY_DATA_DIR=/path/to/copy .build/release/Cazzy
```

Adding `CAZZY_RENDER_TEST_DIR=/path/to/output` makes it write every protocol's
PDF and Markdown export there, print each entry's View-mode layout anchors,
and quit — useful for checking that a change didn't alter any output.

## Package a .dmg to share with someone else

```sh
scripts/make_dmg.sh
```

Produces `Cazzy-x.y.dmg` in the repo root — a release build in a
drag-to-Applications installer window. Send that file to whoever wants
Cazzy; they don't need Swift, Xcode, or the terminal. See the Install
section above for what to tell them about the Gatekeeper prompt.

## Data storage

Everything lives in `~/Library/Application Support/Cazzy/`:

- `data.json` — notebooks, entries, protocols, to-dos, scheduled experiments,
  plate map templates, gel ladder presets, code environments, the paper
  tracker and linked files, as a single JSON file. (Preferences like the theme
  and Box folder are kept in the app's standard macOS preferences instead.) It's rewritten on every change,
  so there's no save step.
- `NoteImages/` and `GelImages/` — images inserted into entries and gel maps
  (entries only store a reference to the filename).
- `box-backup-manifest.json` — what Box backup last wrote, so only changes are
  rewritten.

If `data.json` can't be read at launch (e.g. after an incompatible change to
the data model), Cazzy never overwrites it: it saves an untouched copy as
`data-recovered-<date>.json`, tells the user where it is, and shows sample
data in the meantime. Keep model changes backward compatible
(`decodeIfPresent` with a default for new fields) so old files keep loading.

### Box backup

Settings → **Box Backup** mirrors everything into a `Cazzy/` subfolder of a
folder you choose (normally inside Box Drive, `~/Library/CloudStorage/Box-Box`):
`Cazzy/<Notebook>/<yyyy-MM-dd> <Title>.md` (a folder per notebook, images in
`<Notebook>/images/`) and `Cazzy/Protocol Library/<Protocol>.md`. Box Drive does
the uploading — no Box API credentials are involved.

Changes are copied to Box every 5 minutes, on **⌘S** (File → Back Up to Box
Now), and when Cazzy quits — not on every keystroke, so Box Drive isn't
re-uploading the entry you're typing in. Only changed items are rewritten;
renamed entries have their file moved; deleted entries keep their backup file.
