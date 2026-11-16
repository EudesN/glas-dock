/*
 * Glasdock — applies Dark (1) or Light (2) palette overrides to an Item
 * subtree, or inherits Plasma's system palette when themeMode === 0 (Follow system).
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: scope

    property Item target: parent
    // 0 = Follow system, 1 = Dark, 2 = Light
    property int themeMode: 0

    // Read from SystemPalette rather than Kirigami.Theme on this hidden item:
    // Kirigami.Theme on a visible:false (or unattached) Item defaults to #000000.
    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    readonly property bool systemDark: Kirigami.ColorUtils.brightnessForColor(
        systemPalette.window) === Kirigami.ColorUtils.Dark
    readonly property bool isDark: themeMode === 0 ? systemDark : (themeMode === 1)
    readonly property color accent: isDark
        && Kirigami.ColorUtils.brightnessForColor(systemPalette.highlight) === Kirigami.ColorUtils.Dark
        ? Qt.lighter(systemPalette.highlight, 1.5) : systemPalette.highlight

    visible: false
    width: 0
    height: 0

    Binding {
        target: scope.target
        property: "Kirigami.Theme.inherit"
        value: false
        when: scope.target !== null && scope.themeMode !== 0
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: scope.target
        property: "Kirigami.Theme.textColor"
        value: scope.themeMode === 1 ? "#f2f2f7" : "#1d1d1f"
        when: scope.target !== null && scope.themeMode !== 0
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: scope.target
        property: "Kirigami.Theme.backgroundColor"
        value: scope.themeMode === 1 ? "#1c1c1e" : "#f2f2f7"
        when: scope.target !== null && scope.themeMode !== 0
        restoreMode: Binding.RestoreBindingOrValue
    }
}
