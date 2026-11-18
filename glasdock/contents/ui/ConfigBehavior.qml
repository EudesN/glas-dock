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
            Kirigami.FormData.label: i18n("Hover")
        }
        QQC2.CheckBox {
            id: showPreviews
            Kirigami.FormData.label: i18n("Previews:")
            text: i18n("Show live window previews")
        }
        QQC2.SpinBox {
            id: previewWidth
            Kirigami.FormData.label: i18n("Preview size:")
            enabled: showPreviews.checked
            from: 140; to: 480; stepSize: 20; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox {
            id: showLabels
            Kirigami.FormData.label: i18n("Names:")
            text: i18n("Show the app name")
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Zoom")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Maximum zoom:")
            QQC2.Slider { id: maxZoom; from: 1.0; to: 2.5; stepSize: 0.05 }
            QQC2.Label { text: maxZoom.value.toFixed(2) + "×" }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Zoom reach:")
            QQC2.Slider { id: zoomRange; from: 1.0; to: 5.0; stepSize: 0.1 }
            QQC2.Label { text: i18n("%1 icons", zoomRange.value.toFixed(1)) }
        }
        QQC2.CheckBox {
            id: centeredZoom
            text: i18n("Keep the dock centered while zooming")
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Notifications")
        }
        QQC2.CheckBox {
            id: showBadges
            Kirigami.FormData.label: i18n("Badges:")
            text: i18n("Show a badge on apps with unread notifications")
        }
        QQC2.CheckBox {
            id: badgeUseAccent
            enabled: showBadges.checked
            text: i18n("Use the system accent color (otherwise red)")
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Apps")
        }
        QQC2.CheckBox {
            id: allowReorder
            Kirigami.FormData.label: i18n("Icons:")
            text: i18n("Drag icons to reorder them")
        }
        QQC2.CheckBox {
            id: onlyCurrentDesktop
            text: i18n("Only show windows from the current desktop")
        }
    }
}
