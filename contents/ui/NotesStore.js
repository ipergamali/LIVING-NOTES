.pragma library
// Helper for loading/saving notes and notification state strings.

function createNote(defaultPriority) {
    const now = Date.now();
    return {
        id: "note-" + now + "-" + Math.floor(Math.random() * 1000000),
        title: "New note",
        body: "",
        createdAt: now,
        updatedAt: now,
        dueAt: 0,
        priority: defaultPriority || "MED",
        status: "ACTIVE",
        lastViewedAt: now,
        snoozeUntil: 0,
        tags: [],
        position: { x: 0, y: 0 },
        size: { w: 240, h: 180 },
        pinned: false,
        userColor: ""
    };
}

function parseNotes(jsonString) {
    try {
        return JSON.parse(jsonString || "[]");
    } catch (e) {
        console.log("LivingNotes: failed to parse notes JSON, resetting.", e);
        return [];
    }
}

function stringifyNotes(notes) {
    return JSON.stringify(notes || []);
}

function parseNotificationState(jsonString) {
    try {
        return JSON.parse(jsonString || "{}");
    } catch (e) {
        return {};
    }
}

function stringifyNotificationState(state) {
    return JSON.stringify(state || {});
}

function upsert(notes, note) {
    const list = notes.slice();
    const idx = list.findIndex(n => n.id === note.id);
    if (idx >= 0) {
        list[idx] = note;
    } else {
        list.unshift(note);
    }
    return list;
}

function remove(notes, id) {
    return notes.filter(n => n.id !== id);
}

function updateLastViewed(notes, id, time) {
    const list = notes.slice();
    const idx = list.findIndex(n => n.id === id);
    if (idx >= 0) {
        list[idx] = Object.assign({}, list[idx], { lastViewedAt: time });
    }
    return list;
}

function togglePinned(notes, id) {
    const list = notes.slice();
    const idx = list.findIndex(n => n.id === id);
    if (idx >= 0) {
        const note = list[idx];
        list[idx] = Object.assign({}, note, { pinned: !note.pinned, updatedAt: Date.now() });
    }
    return list;
}

function normalizeNote(raw) {
    // Ensure the note has all expected keys.
    const base = createNote("MED");
    const copy = Object.assign({}, base, raw || {});
    if (!copy.tags) copy.tags = [];
    if (!copy.position) copy.position = { x: 0, y: 0 };
    if (!copy.size) copy.size = { w: 240, h: 180 };
    if (copy.dueAt === undefined || copy.dueAt === null) copy.dueAt = 0;
    if (copy.snoozeUntil === undefined || copy.snoozeUntil === null) copy.snoozeUntil = 0;
    return copy;
}

function normalizeList(notes) {
    return (notes || []).map(normalizeNote);
}
