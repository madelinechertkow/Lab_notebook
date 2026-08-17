import SwiftUI

/// One topic in the in-app manual — a title, sidebar icon, and its content as markdown,
/// rendered through the same `MarkdownPreview` component notes use, so headings/bold/lists/
/// tables all render consistently with the rest of the app instead of needing a second
/// text-rendering system.
struct ManualTopic: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let markdown: String
}

enum ManualContent {
    static let topics: [ManualTopic] = [
        ManualTopic(title: "Getting Started", symbol: "hand.wave.fill", markdown: gettingStarted),
        ManualTopic(title: "Notebooks & Notes", symbol: "book.closed.fill", markdown: notebooksAndNotes),
        ManualTopic(title: "Formatting & Special Characters", symbol: "textformat", markdown: formatting),
        ManualTopic(title: "Searching", symbol: "magnifyingglass", markdown: searching),
        ManualTopic(title: "To-Do List", symbol: "checklist", markdown: todoList),
        ManualTopic(title: "Calendar & Scheduling", symbol: "calendar", markdown: calendar),
        ManualTopic(title: "Protocols", symbol: "list.clipboard.fill", markdown: protocols),
        ManualTopic(title: "Plate Maps", symbol: "square.grid.3x3.fill", markdown: plateMaps),
        ManualTopic(title: "Gel Ladders & Gel Maps", symbol: "chart.bar.doc.horizontal.fill", markdown: gelMaps),
        ManualTopic(title: "Paper Tracker", symbol: "tablecells.fill", markdown: paperTracker),
        ManualTopic(title: "Code Environments & Executable Code", symbol: "chevron.left.forwardslash.chevron.right", markdown: codeExecution),
        ManualTopic(title: "Linked Files", symbol: "link", markdown: linkedFiles),
        ManualTopic(title: "Lab Mode & Organization", symbol: "flask.fill", markdown: labMode),
        ManualTopic(title: "Appearance & Settings", symbol: "paintpalette.fill", markdown: appearance),
        ManualTopic(title: "Windows, Undo & Your Data", symbol: "macwindow", markdown: windowsAndData),
        ManualTopic(title: "Keyboard Shortcuts", symbol: "keyboard", markdown: shortcuts),
    ]

    static let gettingStarted = """
    # Welcome to Cazzy

    Cazzy is a lab notebook: notes live inside **notebooks**, and notebooks can be tagged as **Wet Lab**, **Dry Lab**, or left shared/uncategorized so the app can show or hide bench-specific tools (like plate maps) versus computational tools (like executable code blocks) depending on what kind of work a notebook is for.

    ## The main window

    The sidebar on the left lists:

    - **All Notes** — every note across every visible notebook.
    - **To-Do** and **Calendar** — shortcuts that open those as their own separate windows.
    - **Protocols**, **Plate Maps**, **Gel Ladders**, **Paper Tracker** — the library sections for those features.
    - Your **Notebooks**, each with a note count.
    - **Tags**, once any note has one, letting you browse across notebooks by tag.

    At the very top of the sidebar is the **Lab Mode filter** (All / Wet Lab / Dry Lab) — see the "Lab Mode & Organization" topic for what this does.

    ## Everything autosaves

    There is no save button anywhere in Cazzy. Every change — typing in a note, checking off a to-do, editing a protocol — writes to disk immediately. If you ever want to undo something, **⌘Z** works app-wide (see "Windows, Undo & Your Data").

    ## Where to go next

    If you're just getting oriented, start with **Notebooks & Notes**, then **Formatting & Special Characters**. If you came here for one specific feature, use the list on the left.
    """

    static let notebooksAndNotes = """
    # Notebooks & Notes

    ## Creating a notebook

    Click the **+** next to "Notebooks" in the sidebar. Give it a name, pick a symbol from the grid, and choose whether it's **Shared**, **Wet Lab**, or **Dry Lab** (this defaults to whichever Lab Mode filter is currently active in the sidebar). New notebooks appear at the bottom of the sidebar's Notebooks list — drag notebooks up and down to reorder them.

    ## Creating and organizing notes

    With a notebook selected, click the pencil-and-paper icon at the top of the note list (or select **All Notes** — a new note goes into the first available notebook). Notes are listed newest-first by default; drag a note in the list to reorder it, which sets a custom order that sticks until you drag it again.

    Each note can carry **tags** — type into the "+ tag" field under the title and press Return. Tags are shown in the sidebar once any note has one, and clicking a tag shows every note carrying it, across all notebooks.

    ## Archiving and deleting

    Right-click a note for **Archive Note** or **Delete Note…**. Archiving just hides it from the normal list (it's still there, dimmed, under an "Archived" section) — deleting is permanent, though like everything else it's covered by **⌘Z**. The same right-click options exist for whole notebooks in the sidebar; a notebook can't be archived or deleted if it's the only active one left, since new notes always need somewhere to go.

    ## Preview vs. Edit

    The eye/pencil icon at the top-right of a note toggles between **editing** the raw markdown and **previewing** the rendered result — headings, bold/italic, bullet and numbered lists, checklists, tables, block quotes, and embedded images all render properly in Preview. Executable code blocks, plate maps, and gel maps (see their own topics) are only interactive in Preview mode.

    ## Word count

    The bottom of the editor always shows a live word count and when the note was last edited.
    """

    static let formatting = """
    # Formatting & Special Characters

    ## The formatting toolbar

    While editing (not previewing) a note, a toolbar sits just above the text area:

    | Button | What it does |
    |---|---|
    | **Bold** | Wraps the selected text in `**...**` |
    | **Italic** | Wraps the selection in `*...*` |
    | **Code** | Wraps the selection in `` `...` `` (inline code) |
    | **Insert code block** | Only shown in Dry Lab notebooks — see "Code Environments & Executable Code" |
    | **Heading** | Prefixes the current line(s) with `## ` |
    | **Bullet list** | Prefixes the current line(s) with `- ` |
    | **Checklist** | Adds a checkbox to the start of the current line(s) — renders as a real checkbox in Preview |
    | **Insert special character** | Opens a grid of your configured special-character shortcuts — click one to insert it |
    | **Insert image** | Copies a photo into the note as an inline image |
    | **Insert plate map** / **Insert gel map** | Only shown in Wet Lab (or shared) notebooks — see their own topics |

    Bold/Italic/Code wrap whatever's currently selected; Heading/Bullet/Checklist apply to whichever line(s) your cursor or selection touches, and toggle back off if the line already has that prefix.

    ## Greek letters and fractions

    You don't need special characters for common science notation — typing a LaTeX-style command directly renders it in Preview automatically: a backslash followed by a Greek letter's spelled-out name (lowercase for the lowercase letter, capitalized for the uppercase one — alpha, beta, theta, Delta, Omega, and the rest of the Greek alphabet), or a backslash, "frac", and two curly-brace groups for a fraction. These work whether or not they're wrapped in dollar signs, the way you'd write inline math in LaTeX.

    Underline, superscript, and subscript also work directly in the text, using the same wrapping tags web pages use for them — an opening and closing pair of angle-bracket tags named "u" around underlined text, "sup" around superscript, and "sub" around subscript.

    ## Special Character Shortcuts

    Beyond the toolbar's picker, Cazzy lets you type a **keystroke** directly into a note to insert a character — the same way Option-key combos work system-wide on a Mac, except you can see, edit, and add to the full list.

    By default, every standard macOS Option-key symbol (Option+P → π, Option+8 → •, Option+Shift+- → — em dash, and so on) is already set up, plus an extra Control+Option layer specifically for Greek letters and math/logic symbols (Control+Option+G → γ, Control+Option+P → π, Control+Option+2 → →, etc.), matching macOS's own Greek keyboard layout where possible.

    To see, edit, remove, or add your own shortcuts, go to **Settings → Special Characters → Edit Special Character Shortcuts…**. Click **Add Shortcut**, click the "Click to record" box, press the key combination you want, then fill in what it should insert and a short label. **Reset to Defaults** restores the original full set at any time.
    """

    static let searching = """
    # Searching

    Cazzy has two distinct kinds of search, for two different jobs.

    ## Searching within an open entry — ⌘F

    Press **⌘F** while a note is open and focused to search for text *inside that note* — this opens the same native Find bar macOS uses in TextEdit and Xcode, docked at the top of the text area. Matches stay highlighted the whole time the Find bar is open (recolored to match your current theme's accent color rather than the system's default yellow), and:

    - **⌘G** jumps to the next match.
    - **⌘⇧G** jumps to the previous match.

    ⌘F only does something when a note's text is focused — it's inert if you're looking at, say, the Protocols list or the Calendar.

    ## Searching across all your notes

    The note list (whichever notebook, tag, or "All Notes" you're viewing) has its own search field with a magnifying-glass icon above the list. Typing there filters that list live, matching against note **titles**, **body text**, and **tags** — this is how you find a note when you don't already have it open.
    """

    static let todoList = """
    # To-Do List

    Open the to-do list from the sidebar's **To-Do** row, or from the Calendar window's toolbar — it opens as its own separate window, not a popup sheet, so you can keep it open alongside your notes.

    ## To-dos live on real calendar dates

    Every to-do belongs to a specific day, not a recurring day-of-week. The window shows **one week at a time**:

    - **◀** / **▶** step back and forward a week; **Today** jumps back to the current week.
    - **Week** shows every day's to-dos grouped together; clicking a specific day chip (e.g. "Mon 12") narrows the view to just that day.
    - The date picker next to the "Add a task" field controls which day a new task is added to (it's locked to the current day when a specific day is selected).

    ## Adding, checking off, and editing tasks

    Type into the **"Add a task"** field at the bottom and press Return. To edit an existing task's text, **click directly on it** — it becomes an editable field; press Return or click elsewhere to save (an empty result is ignored rather than saving a blank task).

    Click the circle next to a task to mark it done. **Completing a task also marks all of its subtasks as done** — un-completing it afterward leaves the subtasks' individual progress alone rather than resetting them.

    Drag the handle (the small horizontal-lines icon, visible on hover) to reorder tasks within a day.

    ## Subtasks

    Hover a task and click the **+** to add subtasks under it, or click the chevron next to a task that already has some to expand/collapse them. Each subtask has its own checkbox and can be deleted independently by hovering it and clicking the **×**.

    ## Clearing completed tasks

    A **"Clear completed"** link appears whenever the currently-shown scope (the week, or a single selected day) has at least one completed task — it only clears within that scope, not your whole list.

    ## To-dos on the Calendar

    Every day header in the Calendar window has its own checklist icon — click it to see, check off, and quickly add to-dos for that specific day, without switching windows. The Calendar's toolbar also has a **To-Do List** button that opens the full to-do window.
    """

    static let calendar = """
    # Calendar & Scheduling

    Open the Calendar from the sidebar's **Calendar** row. It shows a scrollable hourly grid for one week at a time, with a compact month overview on the left for jumping to a specific week.

    ## Scheduling an experiment

    Click an empty slot in the grid (snaps to the nearest half hour) or the **New Experiment** button in the toolbar. In the sheet that opens you can set:

    - **Title**, and optionally a **Protocol** to link — picking one auto-fills the duration from that protocol's total time, and the title too if you hadn't typed one yet.
    - **Starts** (date and time) and a duration in hours/minutes.
    - A **Color** for the block (8 choices).
    - Free-text **Notes**.
    - **Repeats** (only when creating, not editing) — "Doesn't repeat", "Every N days", or "Weekly", each with an end date. Repeating creates independent occurrences up front rather than one recurring rule, so deleting later gives you the choice of just one occurrence or the whole series.

    If you've granted Cazzy access to Apple Calendar, the sheet also tells you live whether the chosen time is free or overlaps something on your real calendar.

    ## Working with scheduled experiments

    Drag a block vertically to change its time, or horizontally to move it to a different day. Double-click to edit it. Right-click for more:

    - **Running Behind — Delay Rest of Day** / **Ahead of Schedule — Move Up**: shifts this experiment *and every later experiment that same day* by 15–120 minutes, so one step running long doesn't require manually re-dragging the rest of your afternoon.
    - **Mark as Done** / **Mark as Not Done**.
    - **Create Notebook Entry** (or **Open Notebook Entry** if one already exists) — generates a pre-filled note in your "Lab Notebook" notebook with the experiment's time, linked protocol, and that protocol's steps as an unchecked checklist, ready to fill in as you go.
    - **Ignore Overlap**, if it conflicts with something on your Apple Calendar and you know that's fine.
    - **Add to Apple Calendar** / **Remove from Apple Calendar** for that one experiment.
    - **Delete** / **Delete Entire Series**.

    Pressing **Delete/Backspace** with an experiment selected deletes it too (not while a text field has focus).

    ## Apple Calendar sync

    Busy times from your real calendars show as gray blocks behind your scheduled experiments, with a warning triangle if one of your experiments overlaps a busy time. Whether new experiments are automatically pushed to Apple Calendar (rather than just added one at a time from the right-click menu), and which of your calendars count toward busy-time checking, are both controlled in **Settings → Calendar** and **Settings → Calendars to Show**.
    """

    static let protocols = """
    # Protocols

    Protocols live in their own library (sidebar → **Protocols**), separate from any single note, so the same procedure can be scheduled and reused over and over.

    ## Building a protocol

    A protocol has a **name**, a **purpose**, a list of **Materials & Reagents** (name/amount/unit/notes), and a list of **Steps**. Each step is one of three kinds — a numbered **Step**, or a non-numbered **Note** or **Warning** callout for things that interrupt the flow rather than being an actual procedure step. Steps additionally have an **importance** (Normal / Important / Critical, shown as a colored flag), and optional duration, temperature, and notes.

    Drag the handle on any step or reagent row to reorder it.

    At the bottom of the Steps section, Cazzy totals up the duration from your steps automatically, but you can also set an explicit **override** — this override (when set) is what's used as the protocol's duration when you schedule it as an experiment.

    ## Versioning

    Click **Save New Version** any time you want to snapshot the current draft (an optional note about what changed is a good idea). This doesn't stop you from continuing to edit — the live protocol is always your current draft, and every saved version is kept in **Version History**, each with a **Restore** button that loads that snapshot back into the draft (restoring doesn't itself create a new version — save again if you want to keep the restored state in history too).

    ## Scheduling a protocol

    Click **Schedule…** in a protocol's editor to jump straight to the Calendar with a new-experiment sheet pre-filled from it.

    ## Printing

    Click **Print** for a clean, black-and-white printout (or "Save as PDF" from the print panel) — regardless of your current theme, so a printed protocol stays legible on paper. It includes the reagent table, numbered steps with their duration/temperature/importance, and Note/Warning callouts as colored side-bar blocks.

    ## Sharing a protocol with someone else

    **Export…** saves a `.cazzyprotocol` file you can send to a labmate; **Import…** reads one back in. If you import an update to a protocol you already have, Cazzy merges the changes automatically when there's no real conflict, or opens a **merge view** letting you pick which version of each conflicting item (name, purpose, a specific reagent, a specific step) to keep, side by side.
    """

    static let plateMaps = """
    # Plate Maps

    Plate map **templates** live in their own library (sidebar → **Plate Maps**) for 6/12/24/48/96-well layouts you use repeatedly. Click **+** to create one, name it, and pick a size.

    ## Filling in a plate

    Click a well to open its color-and-label editor immediately — no extra step to "turn on" color. To label and color several wells identically at once, select them first:

    - **⌘-click** wells to add or remove them from the selection one at a time.
    - **⇧-click** selects the whole rectangle between your last click and the new one — handy for a full row, column, or block of wells.

    With multiple wells selected, opening the editor (click any selected well again) applies whatever label and color you set to every well in that selection at once.

    ## Using a plate map in a note

    From a note's formatting toolbar, the plate-map button lets you insert either a **blank** plate of any size, or a copy of one of your saved templates. Once inserted, that plate map is its own independent copy embedded in the note — editing it there never changes the original template, and editing the template later never changes plate maps you've already inserted into notes. This feature only appears in Wet Lab and shared notebooks, not Dry Lab ones.
    """

    static let gelMaps = """
    # Gel Ladders & Gel Maps

    This is a lightweight way to label a gel-electrophoresis photo — placing lane and ladder-size labels where they belong on the image, for reading and reference. It doesn't estimate sizes for you; you position the labels by eye.

    ## Ladder presets

    If you use the same ladder often, save it once (sidebar → **Gel Ladders** → **+**) as an ordered list of band sizes (largest to smallest, matching how a ladder reads top-to-bottom), each with a unit (bp / kb / kDa). You can then drop the whole preset onto a gel image in one step instead of typing each size by hand every time.

    ## Adding a gel image to a note

    Use the **Insert gel map** button in a note's formatting toolbar (Wet Lab / shared notebooks only) and choose a photo. Cazzy copies it into the note.

    In the embedded gel map block:

    - **Adjust** lets you straighten a crooked photo (rotation slider) and crop it by dragging the four edge handles — this always creates a new image rather than editing your original in place, so re-adjusting never compounds on already-processed pixels.
    - **Lane** adds a draggable label across the top of the image — drag it to whichever lane it belongs to, double-click to rename or delete it.
    - **Ladder** adds a label down the left edge, either a blank one you type a size into, or an entire saved ladder preset dropped in at once (evenly spaced) if you have any presets saved. Drag each band label to line it up with its actual band on the gel; double-click to edit or delete it.
    """

    static let paperTracker = """
    # Paper Tracker

    Sidebar → **Paper Tracker** is a spreadsheet-style table for keeping track of literature, with columns for the date added, authors, journal, year, title, relevance, follow-up flag, read status, and tags, plus a full detail panel per paper for methods, models used, data availability, key findings, and your own notes.

    Click the **+** button to add a paper. Use the search field and the status/follow-up filters above the table to narrow a long list down.

    ## Auto-filling from a DOI or link

    Paste a paper's DOI or URL into the **Link/DOI** field (in the detail panel) and click **Fetch** — Cazzy looks the paper up (via CrossRef first, falling back to scraping the page's own citation metadata for sites like Nature, Science, PubMed, or bioRxiv) and fills in the title, journal, year, and first/last author automatically. Only fields it actually finds are overwritten — anything you've already typed elsewhere is left alone.
    """

    static let codeExecution = """
    # Code Environments & Executable Code

    This is a **Dry Lab notebook** feature — a note in a Wet Lab or shared notebook won't show any of this.

    ## Setting up a note to run code

    At the top of a dry-lab note, two menus let you choose a **language** (Python, R, or Bash) and, optionally, a **code environment** — a saved shell command (like `conda activate ds` or `source ~/venv/bin/activate`) that runs before your code, so it executes inside the right environment instead of your plain login shell. Manage your saved environments from that same menu's **Manage Environments…**, or from within a note.

    ## Adding and running a block

    The toolbar's **Insert code block** button drops in a code block you can type directly into. Switch the note to **Preview** to actually run it — click **Run**. While running you get a **Cancel** button; once it finishes you see the exit code, how long it took, and the full stdout/stderr output, plus a collapsible **Environment** section recording the exact interpreter version (and installed package list, for Python/R) that produced that result — useful for tracing back what actually generated a given output later. If you edit the code after running it, a warning appears letting you know the shown result is now stale.

    Code always runs in your real login shell (the same one Terminal uses), and only ever runs when you explicitly click Run — never automatically.
    """

    static let linkedFiles = """
    # Linked Files

    For files that need to keep living somewhere else — a thesis chapter still being drafted in Word, a large dataset, a shared PDF — rather than copying them into Cazzy, a notebook can **link** to them instead.

    Select a notebook, switch to its **Files** tab (next to Notes), and either drag files in or click the import button and choose them. A linked file always opens from its real, original location — edits made there (even from a totally different app) are what you see next time you open it from Cazzy.

    Right-click a linked file for **Open**, **Reveal in Finder**, or **Relink…** (if the file's moved and Cazzy can no longer find it — you'll see "File not found" in that case). Removing a link only removes it from the notebook; it never touches the actual file on disk.
    """

    static let labMode = """
    # Lab Mode & Organization

    Every notebook can be tagged **Wet Lab**, **Dry Lab**, or left **shared** (uncategorized) — set when you create it, from the symbol next to its name. This isn't just a label: it decides which tools show up in notes belonging to that notebook.

    - **Dry Lab** notebooks get executable code blocks (Python/R/Bash), but not plate maps or gel maps.
    - **Wet Lab** notebooks get plate maps and gel maps, but not code execution.
    - **Shared** notebooks get plate maps and gel maps too (the same as Wet Lab), just not code execution.

    ## The sidebar filter

    The segmented control at the top of the sidebar (All / Wet Lab / Dry Lab) filters which notebooks are visible throughout the app — shared notebooks always stay visible no matter which of the three you pick, since they're not lab-specific. This is purely a display filter; it doesn't move or delete anything, and switching it back to All brings everything into view again.
    """

    static let appearance = """
    # Appearance & Settings

    Open Settings from the app menu (**Cazzy → Settings…**, or **⌘,**).

    ## Theme

    - **Mode**: Light, Dark, or Auto (Auto follows your Mac's own system appearance setting).
    - **Presets**: a strip of ready-made color palettes — click one to apply it instantly.
    - **Colors**: fine-tune the accent, secondary accent, background, sidebar, and text colors individually on top of whatever preset you picked.
    - **Reset to Default** at the bottom restores the original theme.

    ## Fonts

    Pick separate typefaces for **Headings** and **Body text**, each with a live preview right there in Settings.

    Font *size* (as opposed to typeface) is a separate, app-wide control available any time from the menu bar, not in Settings — see "Keyboard Shortcuts".

    ## Calendar

    Whether scheduling a new experiment automatically pushes it to Apple Calendar, which calendar it goes to, and which of your Apple calendars count toward busy-time/overlap checking on the Calendar screen — see the "Calendar & Scheduling" topic for how these interact.

    ## Special Characters

    **Edit Special Character Shortcuts…** opens the manager described in "Formatting & Special Characters".
    """

    static let windowsAndData = """
    # Windows, Undo & Your Data

    ## Multiple windows

    The main notebook window, the To-Do list, and the Calendar are each their own separate window, openable from the sidebar (or the Calendar's own toolbar, for To-Do). You can have all three open side by side. Clicking the Dock icon when no window is open brings the main window back; it won't open a second one if a window is already open.

    ## Undo, app-wide

    **⌘Z** undoes your most recent change — and this isn't limited to whatever text field you're currently in. Every change anywhere in Cazzy (a note edit, a to-do checked off, a protocol step reordered, an experiment rescheduled) goes through the same history, so ⌘Z steps back through your actual recent actions in order, and **⌘⇧Z** redoes. Rapid typing is grouped into one undo step rather than one per keystroke, so undo doesn't feel like erasing one character at a time.

    ## Where your data lives, and what happens if something goes wrong

    Everything — notebooks, notes, protocols, plate maps, gel ladders, the paper tracker, your to-do list, scheduled experiments — is stored in one file on your Mac, and saved to disk immediately after every change (there's nothing to remember to save).

    If that file is ever unreadable when Cazzy launches — most likely after an app update changed something incompatibly — Cazzy does **not** overwrite or discard it. It backs up the unreadable file untouched under a new name in the same folder, shows you a one-time alert explaining exactly where that backup went, and shows sample notebooks in the meantime rather than silently presenting an empty (or wrong) notebook as if nothing happened.
    """

    static let shortcuts = """
    # Keyboard Shortcuts

    ## App-wide (work no matter which window is focused)

    | Shortcut | Action |
    |---|---|
    | ⌘Z | Undo |
    | ⌘⇧Z | Redo |
    | ⌘F | Find within the open note |
    | ⌘G | Find Next |
    | ⌘⇧G | Find Previous |
    | ⌘+ | Increase text size, app-wide |
    | ⌘− | Decrease text size, app-wide |
    | ⌘0 | Reset text size to normal |
    | ⌘, | Open Settings |

    ## In dialogs and sheets

    Return/Enter confirms the highlighted action (Save, Create, Apply, and so on); Escape cancels — this is standard throughout Cazzy's sheets (new protocol, new plate map template, scheduling an experiment, editing a special-character shortcut, etc.), even where it isn't spelled out on the button itself.

    ## Special characters while writing a note

    Your own configured combinations (Option-key symbols by default, plus a Control+Option Greek/math layer) insert directly as you type — see "Formatting & Special Characters" for the full list and how to customize it from **Settings → Special Characters**.
    """
}

struct ManualView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTopicID: ManualTopic.ID?

    private var selectedTopic: ManualTopic {
        ManualContent.topics.first(where: { $0.id == selectedTopicID }) ?? ManualContent.topics[0]
    }

    var body: some View {
        NavigationSplitView {
            List(ManualContent.topics, selection: $selectedTopicID) { topic in
                Label(topic.title, systemImage: topic.symbol)
                    .tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            MarkdownPreview(markdown: selectedTopic.markdown)
                .id(selectedTopic.id)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Manual")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            if selectedTopicID == nil {
                selectedTopicID = ManualContent.topics[0].id
            }
        }
        .frame(minWidth: 820, minHeight: 640)
    }
}
