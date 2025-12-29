import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as Controls
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.core 2.1 as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami

import "NotesStore.js" as NotesStore

PlasmoidItem {
    id: root
    implicitWidth: Kirigami.Units.gridUnit * 24
    implicitHeight: Kirigami.Units.gridUnit * 24
    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 16
    Layout.preferredWidth: Kirigami.Units.gridUnit * 26
    Layout.preferredHeight: Kirigami.Units.gridUnit * 26
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground

    property var notes: []
    property var filteredNotes: []
    property double nowMs: Date.now()
    property string layoutMode: Plasmoid.configuration.defaultLayout === "free" ? "free" : "grid"
    property string filterStatus: "ACTIVE"
    property string searchQuery: ""
    property alias notificationsEnabled: notificationToggle.checked
    property string fadePreset: Plasmoid.configuration.fadePreset || "medium"
    property string defaultPriority: Plasmoid.configuration.defaultPriority || "MED"
    property bool freeLayout: layoutMode === "free"
    property var notificationState: NotesStore.parseNotificationState(Plasmoid.configuration.notificationState)
    property var notifierObject: null

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: {
            root.nowMs = Date.now();
            checkNotifications();
        }
    }

    // Kick off first load and notify watchers.
    Component.onCompleted: {
        notes = NotesStore.normalizeList(NotesStore.parseNotes(Plasmoid.configuration.notesJson));
        updateFilteredNotes();
        checkNotifications();
    }

    function persistNotes(newNotes) {
        notes = NotesStore.normalizeList(newNotes);
        Plasmoid.configuration.notesJson = NotesStore.stringifyNotes(notes);
        updateFilteredNotes();
    }

    function updateFilteredNotes() {
        const q = (searchQuery || "").toLowerCase();
        const status = filterStatus;
        const now = nowMs;
        filteredNotes = notes
                .filter(function (n) {
                    if (status === "ACTIVE" && n.status !== "ACTIVE")
                        return false;
                    if (status === "DONE" && n.status !== "DONE")
                        return false;
                    if (status === "ARCHIVED" && n.status !== "ARCHIVED")
                        return false;
                    if (q.length > 0) {
                        const haystack = (n.title + " " + n.body + " " + (n.tags || []).join(" ")).toLowerCase();
                        if (haystack.indexOf(q) < 0)
                            return false;
                    }
                    return true;
                })
                .sort(function (a, b) {
                    if (a.pinned !== b.pinned)
                        return a.pinned ? -1 : 1;
                    const aDue = a.dueAt || 0;
                    const bDue = b.dueAt || 0;
                    if (aDue && bDue && aDue !== bDue)
                        return aDue - bDue;
                    if (aDue && !bDue)
                        return -1;
                    if (!aDue && bDue)
                        return 1;
                    return b.updatedAt - a.updatedAt;
                });
    }

    function addNote() {
        const note = NotesStore.createNote(defaultPriority);
        note.position = { x: (width - note.size.w) / 2, y: (height - note.size.h) / 2 };
        persistNotes([note].concat(notes));
    }

    function saveNote(note) {
        note.updatedAt = Date.now();
        persistNotes(NotesStore.upsert(notes, note));
    }

    function deleteNote(id) {
        persistNotes(NotesStore.remove(notes, id));
    }

    function markStatus(note, status) {
        const updated = Object.assign({}, note, { status: status, updatedAt: Date.now() });
        persistNotes(NotesStore.upsert(notes, updated));
    }

    function snoozeNote(note, untilMs) {
        const updated = Object.assign({}, note, { snoozeUntil: untilMs, updatedAt: Date.now() });
        persistNotes(NotesStore.upsert(notes, updated));
    }

    function recordViewed(note) {
        persistNotes(NotesStore.updateLastViewed(notes, note.id, Date.now()));
    }

    function togglePinned(note) {
        persistNotes(NotesStore.togglePinned(notes, note.id));
    }

    function setLayout(mode) {
        layoutMode = mode;
    }

    function checkNotifications() {
        if (!Plasmoid.configuration.enableNotifications)
            return;

        const now = nowMs;
        const state = notificationState || {};
        let changed = false;

        // Prune obsolete keys.
        Object.keys(state).forEach(function (key) {
            const parts = key.split("::");
            const id = parts[0];
            const dueAt = Number(parts[1] || 0);
            const stillExists = notes.some(n => n.id === id && n.dueAt === dueAt);
            if (!stillExists) {
                delete state[key];
                changed = true;
            }
        });

        notes.forEach(function (note) {
            if (note.status !== "ACTIVE" || !note.dueAt || (note.snoozeUntil && note.snoozeUntil > now))
                return;
            const mins = (note.dueAt - now) / 60000;
            const key = note.id + "::" + note.dueAt;
            const entry = state[key] || { dueSoon: false, overdue: false };

            if (mins <= 10 && mins > 0 && !entry.dueSoon) {
                sendNotification("Due soon: " + note.title, "Due at " + new Date(note.dueAt).toLocaleString());
                entry.dueSoon = true;
                changed = true;
            }
            if (mins <= 0 && !entry.overdue) {
                sendNotification("Overdue: " + note.title, "This note is overdue.");
                entry.overdue = true;
                changed = true;
            }
            state[key] = entry;
        });

        if (changed) {
            notificationState = state;
            Plasmoid.configuration.notificationState = NotesStore.stringifyNotificationState(state);
        }
    }

    function sendNotification(title, text) {
        const notifier = ensureNotifier();
        if (!notifier)
            return;
        notifier.title = title;
        notifier.text = text;
        notifier.iconName = "view-pim-notes";
        if (notifier.hasOwnProperty("timeout"))
            notifier.timeout = 8000;
        else if (notifier.hasOwnProperty("expireTimeout"))
            notifier.expireTimeout = 8000;
        if (notifier.sendEvent)
            notifier.sendEvent();
        else if (notifier.send)
            notifier.send();
    }

    function ensureNotifier() {
        if (notifierObject === undefined)
            return null;
        if (notifierObject !== null)
            return notifierObject;

        // Try KNotifications (Plasma 6), fall back silently if unavailable.
        try {
            var created = Qt.createQmlObject('import org.kde.knotifications 1.0 as KNotifications; KNotifications.Notification { eventId: "notification" }', root, "Notifier");
            if (!created) {
                console.log("LivingNotes: notifications unavailable (missing org.kde.knotifications)");
                notifierObject = undefined;
                return null;
            }
            notifierObject = created;
            return notifierObject;
        } catch (e) {
            console.log("LivingNotes: notifications unavailable (missing org.kde.knotifications)", e);
            notifierObject = undefined;
            return null;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing
        anchors.margins: Kirigami.Units.smallSpacing

        RowLayout {
            id: topBar
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents3.Button {
                id: addButton
                text: i18n("Add")
                icon.name: "list-add"
                onClicked: addNote()
            }

            PlasmaComponents3.TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n("Search notes…")
                text: searchQuery
                onTextChanged: {
                    searchQuery = text;
                    updateFilteredNotes();
                }
            }

            PlasmaComponents3.ComboBox {
                id: layoutToggle
                model: [ i18n("Grid"), i18n("Free") ]
                textRole: ""
                implicitWidth: Kirigami.Units.gridUnit * 8
                onActivated: {
                    layoutMode = index === 1 ? "free" : "grid";
                    Plasmoid.configuration.defaultLayout = layoutMode;
                }
                Component.onCompleted: currentIndex = layoutMode === "free" ? 1 : 0
            }

            PlasmaComponents3.ComboBox {
                id: filterToggle
                model: [ { label: i18n("Active"), value: "ACTIVE" },
                         { label: i18n("Done"), value: "DONE" },
                         { label: i18n("Archived"), value: "ARCHIVED" } ]
                textRole: "label"
                valueRole: "value"
                onActivated: {
                    filterStatus = model[currentIndex].value;
                    updateFilteredNotes();
                }
                Component.onCompleted: {
                    currentIndex = 0;
                }
            }

            PlasmaComponents3.ToolButton {
                id: notificationToggle
                checkable: true
                checked: Plasmoid.configuration.enableNotifications
                icon.name: checked ? "notifications" : "notifications-disabled"
                onClicked: Plasmoid.configuration.enableNotifications = checked
                Accessible.description: i18n("Enable notifications")
            }
        }

        Loader {
            id: layoutLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: freeLayout ? freeCanvas : gridCanvas
        }
    }

    Component {
        id: gridCanvas
        Controls.ScrollView {
            id: gridScroll
            anchors.fill: parent
            clip: true

            Flow {
                id: gridFlow
                width: parent.width
                spacing: Kirigami.Units.largeSpacing
                Repeater {
                    model: filteredNotes
                    delegate: NoteCard {
                        note: modelData
                        nowMs: root.nowMs
                        fadePreset: root.fadePreset
                        freeLayout: false
                        width: Math.max(Kirigami.Units.gridUnit * 8, gridFlow.width / 2 - Kirigami.Units.largeSpacing)
                        height: note.size ? note.size.h : Kirigami.Units.gridUnit * 10
                        onDeleteRequested: deleteNote(note.id)
                        onStatusChanged: markStatus(note, status)
                        onSnoozeRequested: snoozeNote(note, until)
                        onPinToggled: togglePinned(note)
                        onViewed: recordViewed(note)
                    }
                }
            }
        }
    }

    Component {
        id: freeCanvas
        Item {
            id: freeArea
            anchors.fill: parent
            clip: true

            Repeater {
                model: filteredNotes
                delegate: NoteCard {
                    note: modelData
                    nowMs: root.nowMs
                    fadePreset: root.fadePreset
                    freeLayout: true
                    x: note.position ? note.position.x : 0
                    y: note.position ? note.position.y : 0
                    width: note.size ? note.size.w : Kirigami.Units.gridUnit * 12
                    height: note.size ? note.size.h : Kirigami.Units.gridUnit * 10
                    boundsRect: Qt.rect(0, 0, freeArea.width - width, freeArea.height - height)
                    onMoved: function (pos) {
                        const updated = Object.assign({}, note, { position: pos, updatedAt: Date.now() });
                        persistNotes(NotesStore.upsert(notes, updated));
                    }
                    onDeleteRequested: deleteNote(note.id)
                    onStatusChanged: markStatus(note, status)
                    onSnoozeRequested: snoozeNote(note, until)
                    onPinToggled: togglePinned(note)
                    onViewed: recordViewed(note)
                }
            }
        }
    }

}
