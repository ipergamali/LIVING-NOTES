## Living Notes Plasmoid (KDE Plasma 6)

Animated sticky notes that react to urgency and time. Notes fade when ignored, pulse near deadlines, and nudge when overdue. Data is stored locally as JSON via `Qt.labs.settings` (no network calls).

### Features
- Grid or free-form draggable layout, with pinned notes surfaced first.
- Priority-aware cards with fade rules based on last view time and animated pulses for upcoming deadlines; overdue notes nudge and show an OVERDUE badge.
- Snooze collapses a note until its wake time; quick actions on hover (Done, Snooze, Delete).
- Local persistence of the full note model (id, title, body, tags, due/snooze, priority, status, position, size, pinned, timestamps).
- Optional notifications for due soon (10 min) and overdue events, delivered once per due cycle.
- Configuration page for fade aggressiveness, default priority, default layout, and notifications toggle.

### File Layout
- `metadata.json` — Plasma 6 metadata (KPackage, declarative applet script).
- `contents/ui/main.qml` — root UI, layout toggles, filtering, and notification checks.
- `contents/ui/NoteCard.qml` — card visuals, fading/pulse/nudge animations, hover actions, drag handling.
- `contents/ui/NoteEditor.qml` — (removed; editing UI not available)
- `contents/ui/NotesStore.js` — JSON load/save helpers using `Qt.labs.settings`.
- `contents/config/config.qml` + `main.xml` — config UI and schema.
- `contents/ui/assets/icon.svg` — placeholder icon.

### Install / Update
```bash
# From this directory
kpackagetool6 --type Plasma/Applet --install .
# Update
kpackagetool6 --type Plasma/Applet --upgrade .
# Remove
kpackagetool6 --type Plasma/Applet --remove org.jope.livingnotes
```

To bundle as a plasmoid file:
```bash
zip -r livingnotes.plasmoid metadata.json contents
```

After installation, add the widget from the Plasma widget explorer. Use the gear menu to adjust defaults; notes are kept per-user in the plasmoid storage/config path as JSON strings.
# LIVING-NOTES
