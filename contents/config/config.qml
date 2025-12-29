import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami 2.20 as Kirigami

Kirigami.FormLayout {
    id: root
    anchors.fill: parent

    property alias cfg_fadePreset: fadePreset.value
    property alias cfg_defaultPriority: defaultPriority.value
    property alias cfg_enableNotifications: notifications.checked
    property alias cfg_defaultLayout: defaultLayout.value

    PlasmaComponents3.ComboBox {
        id: fadePreset
        Kirigami.FormData.label: i18n("Fade aggressiveness")
        model: [
            { text: i18n("Gentle"), value: "gentle" },
            { text: i18n("Medium"), value: "medium" },
            { text: i18n("Bold"), value: "bold" }
        ]
        textRole: "text"
        valueRole: "value"
        property string value: model[currentIndex].value
        onActivated: value = model[currentIndex].value
        onValueChanged: {
            for (var i = 0; i < model.length; ++i) {
                if (model[i].value === value) {
                    currentIndex = i;
                    break;
                }
            }
        }
    }

    PlasmaComponents3.ComboBox {
        id: defaultPriority
        Kirigami.FormData.label: i18n("Default priority")
        model: [
            { text: "LOW", value: "LOW" },
            { text: "MED", value: "MED" },
            { text: "HIGH", value: "HIGH" }
        ]
        textRole: "text"
        valueRole: "value"
        property string value: model[currentIndex].value
        onActivated: value = model[currentIndex].value
        onValueChanged: {
            for (var i = 0; i < model.length; ++i) {
                if (model[i].value === value) {
                    currentIndex = i;
                    break;
                }
            }
        }
    }

    PlasmaComponents3.ComboBox {
        id: defaultLayout
        Kirigami.FormData.label: i18n("Default layout")
        model: [
            { text: i18n("Grid"), value: "grid" },
            { text: i18n("Free"), value: "free" }
        ]
        textRole: "text"
        valueRole: "value"
        property string value: model[currentIndex].value
        onActivated: value = model[currentIndex].value
        onValueChanged: {
            for (var i = 0; i < model.length; ++i) {
                if (model[i].value === value) {
                    currentIndex = i;
                    break;
                }
            }
        }
    }

    PlasmaComponents3.CheckBox {
        id: notifications
        Kirigami.FormData.label: i18n("Notifications")
        text: i18n("Enable due notifications")
        checked: true
    }
}
