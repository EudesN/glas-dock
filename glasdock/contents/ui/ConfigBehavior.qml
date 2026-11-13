import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Glasdock settings — Behavior
KCM.SimpleKCM {
    property alias cfg_maxZoom: maxZoom.value
    property alias cfg_zoomRange: zoomRange.value
    property alias cfg_centeredZoom: centeredZoom.checked
    property alias cfg_showPreviews: showPreviews.checked
    property alias cfg_previewWidth: previewWidth.value
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_showBadges: showBadges.checked
    property alias cfg_badgeUseAccent: badgeUseAccent.checked
    property alias cfg_allowReorder: allowReorder.checked
    property alias cfg_onlyCurrentDesktop: onlyCurrentDesktop.checked

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Hover"
        }
        QQC2.CheckBox {
            id: showPreviews
            Kirigami.FormData.label: "Previews:"
            text: "Show live window previews"
        }
        QQC2.SpinBox {
            id: previewWidth
            Kirigami.FormData.label: "Preview size:"
            enabled: showPreviews.checked
            from: 140; to: 480; stepSize: 20
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox {
            id: showLabels
            Kirigami.FormData.label: "Names:"
            text: "Show the app name"
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Zoom"
        }
        RowLayout {
            Kirigami.FormData.label: "Maximum zoom:"
            QQC2.Slider { id: maxZoom; from: 1.0; to: 2.5; stepSize: 0.05 }
            QQC2.Label { text: maxZoom.value.toFixed(2) + "×" }
        }
        RowLayout {
            Kirigami.FormData.label: "Zoom reach:"
            QQC2.Slider { id: zoomRange; from: 1.0; to: 5.0; stepSize: 0.1 }
            QQC2.Label { text: zoomRange.value.toFixed(1) + " icons" }
        }
        QQC2.CheckBox {
            id: centeredZoom
            text: "Keep the dock centered while zooming"
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Zoom and names are off in the Blur style (see Appearance)."
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Notifications"
        }
        QQC2.CheckBox {
            id: showBadges
            Kirigami.FormData.label: "Badges:"
            text: "Show a badge on apps with unread notifications"
        }
        QQC2.CheckBox {
            id: badgeUseAccent
            enabled: showBadges.checked
            text: "Use the system accent color (otherwise red)"
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Apps"
        }
        QQC2.CheckBox {
            id: allowReorder
            Kirigami.FormData.label: "Icons:"
            text: "Drag icons to reorder them"
        }
        QQC2.CheckBox {
            id: onlyCurrentDesktop
            text: "Only show windows from the current desktop"
        }
    }
}
