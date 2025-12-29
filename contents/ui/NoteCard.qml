import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15 as Controls
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: card
    property var note
    property double nowMs: Date.now()
    property string fadePreset: "medium"
    property bool freeLayout: false
    property rect boundsRect: Qt.rect(0, 0, 0, 0)
    property bool hovered: false
    property real pulseScale: 1.0
    property real shakeOffset: 0
    property bool suppressClick: false

    signal deleteRequested()
    signal statusChanged(string status)
    signal snoozeRequested(var until)
    signal pinToggled()
    signal viewed()
    signal moved(var position)

    width: note && note.size ? note.size.w : Kirigami.Units.gridUnit * 12
    height: minimized ? Kirigami.Units.gridUnit * 4 : (note && note.size ? note.size.h : Kirigami.Units.gridUnit * 10)

    readonly property bool snoozed: note && note.snoozeUntil && note.snoozeUntil > nowMs
    readonly property bool isOverdue: note && note.dueAt > 0 && note.dueAt < nowMs && note.status === "ACTIVE" && !snoozed
    readonly property bool dueSoon24h: note && note.dueAt > nowMs && note.dueAt - nowMs <= 24 * 60 * 60 * 1000 && note.status === "ACTIVE" && !snoozed
    readonly property bool dueSoon2h: note && note.dueAt > nowMs && note.dueAt - nowMs <= 2 * 60 * 60 * 1000 && note.status === "ACTIVE" && !snoozed
    readonly property real baseOpacity: {
        if (!note) return 1.0;
        const elapsed = (nowMs - (note.lastViewedAt || nowMs)) / (60 * 60 * 1000); // hours
        var value = 1.0;
        if (elapsed <= 6) value = 1.0;
        else if (elapsed <= 24) value = 0.85;
        else if (elapsed <= 72) value = 0.7;
        else value = 0.55;

        if (fadePreset === "gentle") value = Math.min(1.0, value + 0.1);
        else if (fadePreset === "bold") value = Math.max(0.45, value - 0.1);
        return value;
    }

    readonly property color baseColor: note && note.userColor && note.userColor.length > 0 ? note.userColor :
                                            note && note.priority === "HIGH" ? "#ff8a80" :
                                            note && note.priority === "MED" ? "#ffd180" : "#c5e1a5"
    readonly property color surfaceColor: note && note.status !== "ACTIVE" ? Qt.darker(baseColor, 1.2) : baseColor
    readonly property bool minimized: snoozed

    transform: Translate { x: shakeOffset }
    scale: minimized ? 0.95 : pulseScale
    opacity: minimized ? baseOpacity * 0.7 : baseOpacity

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing * 1.2
        color: surfaceColor
        border.color: note && note.pinned ? Qt.darker(baseColor, 1.2) : Qt.darker(baseColor, 1.05)
        border.width: 1
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: card.hovered = true
        onExited: card.hovered = false
        onPressAndHold: function (mouse) {
            contextMenu.popup(card, Qt.point(mouse.x, mouse.y));
            suppressClick = true;
        }
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup(card, Qt.point(mouse.x, mouse.y));
                return;
            }
            if (suppressClick) {
                suppressClick = false;
                return;
            }
            card.viewed();
        }
        onCanceled: suppressClick = false
        onReleased: suppressClick = false
    }

    DragHandler {
        id: dragHandler
        target: freeLayout ? card : null
        xAxis.enabled: freeLayout
        yAxis.enabled: freeLayout
        onActiveChanged: {
            if (!active && freeLayout) {
                const clamped = card.clampPosition(card.x, card.y);
                card.x = clamped.x;
                card.y = clamped.y;
                moved(clamped);
            }
        }
    }

    function clampPosition(px, py) {
        var bx = boundsRect ? boundsRect.x : 0;
        var by = boundsRect ? boundsRect.y : 0;
        var bw = boundsRect ? boundsRect.width : 0;
        var bh = boundsRect ? boundsRect.height : 0;
        var nx = Math.max(bx, Math.min(px, bx + bw));
        var ny = Math.max(by, Math.min(py, by + bh));
        return { x: nx, y: ny };
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 5
                text: note ? note.title : ""
                wrapMode: Text.WordWrap
                maximumLineCount: minimized ? 1 : 2
                elide: Text.ElideRight
            }

            PlasmaComponents3.ToolButton {
                icon.name: note && note.pinned ? "pin" : "pin-outline"
                visible: hovered
                onClicked: {
                    pinToggled();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing / 2
            visible: !minimized

            Text {
                text: note && note.body ? note.body : ""
                color: "#202020"
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing / 2

            Repeater {
                model: badgesModel
                delegate: Rectangle {
                    id: badge
                    radius: Kirigami.Units.smallSpacing
                    color: colorRole
                    border.color: Qt.darker(colorRole, 1.3)
                    height: Kirigami.Units.gridUnit * 1.4
                    implicitWidth: badgeLabel.implicitWidth + Kirigami.Units.largeSpacing
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing / 2
                        PlasmaComponents3.Label {
                            id: badgeLabel
                            text: label
                            font.pixelSize: Kirigami.Units.smallSpacing * 3
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
            PlasmaComponents3.ToolButton {
                icon.name: "task-complete"
                text: i18n("Done")
                display: PlasmaComponents3.AbstractButton.IconOnly
                visible: hovered && note && note.status !== "DONE"
                onClicked: statusChanged("DONE")
            }
            PlasmaComponents3.ToolButton {
                icon.name: "chronometer"
                text: i18n("Snooze")
                display: PlasmaComponents3.AbstractButton.IconOnly
                visible: hovered
                onClicked: {
                    const snoozeUntil = Date.now() + 60 * 60 * 1000; // 1 hour
                    snoozeRequested(snoozeUntil);
                }
            }
            PlasmaComponents3.ToolButton {
                icon.name: "edit-delete"
                text: i18n("Delete")
                display: PlasmaComponents3.AbstractButton.IconOnly
                visible: hovered
                onClicked: deleteRequested()
            }
        }
    }

    ListModel {
        id: badgesModel
    }

    function refreshBadges() {
        badgesModel.clear();
        if (!note)
            return;

        const priorityColor = note.priority === "HIGH" ? "#c62828" : note.priority === "MED" ? "#ef6c00" : "#2e7d32";
        badgesModel.append({ label: note.priority, colorRole: priorityColor });

        if (note.dueAt && note.dueAt > 0) {
            const label = isOverdue ? "OVERDUE" : ("Due " + new Date(note.dueAt).toLocaleString());
            badgesModel.append({ label: label, colorRole: isOverdue ? "#b71c1c" : "#1565c0" });
        }

        if (snoozed) {
            badgesModel.append({ label: "SNOOZED", colorRole: "#607d8b" });
        }

        if (note.status === "DONE") {
            badgesModel.append({ label: "DONE", colorRole: "#4caf50" });
        } else if (note.status === "ARCHIVED") {
            badgesModel.append({ label: "ARCHIVED", colorRole: "#9e9e9e" });
        }

        if (note.tags && note.tags.length > 0 && !minimized) {
            badgesModel.append({ label: note.tags.join(", "), colorRole: "#5d4037" });
        }
    }

    onNoteChanged: refreshBadges()
    onSnoozedChanged: refreshBadges()
    onIsOverdueChanged: refreshBadges()
    onNowMsChanged: refreshBadges()
    Component.onCompleted: refreshBadges()

    SequentialAnimation {
        id: pulseAnimation
        running: !minimized && (dueSoon24h || dueSoon2h) && !isOverdue
        loops: Animation.Infinite
        NumberAnimation { target: card; property: "pulseScale"; from: 1.0; to: dueSoon2h ? 1.05 : 1.02; duration: dueSoon2h ? 500 : 1000; easing.type: Easing.InOutQuad }
        NumberAnimation { target: card; property: "pulseScale"; from: dueSoon2h ? 1.05 : 1.02; to: 1.0; duration: dueSoon2h ? 500 : 1000; easing.type: Easing.InOutQuad }
        onStopped: card.pulseScale = 1.0
    }

    Timer {
        id: nudgeTimer
        interval: 5 * 60 * 1000
        running: isOverdue
        repeat: true
        onTriggered: shakeAnimation.start()
    }

    NumberAnimation {
        id: shakeAnimation
        target: card
        property: "shakeOffset"
        from: 0
        to: 4
        duration: 60
        easing.type: Easing.InOutQuad
        loops: 3
        onStopped: card.shakeOffset = 0
    }

    Controls.Menu {
        id: contextMenu
        Controls.MenuItem {
            text: i18n("Delete")
            icon.name: "edit-delete"
            onTriggered: deleteRequested()
        }
    }
}
