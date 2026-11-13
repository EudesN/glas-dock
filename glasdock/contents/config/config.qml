import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Appearance"
        icon: "preferences-desktop-color"
        source: "ConfigAppearance.qml"
    }
    ConfigCategory {
        name: "Behavior"
        icon: "preferences-desktop-mouse"
        source: "ConfigBehavior.qml"
    }
    ConfigCategory {
        name: "Launcher"
        icon: "start-here-kde"
        source: "ConfigLauncher.qml"
    }
    ConfigCategory {
        name: "Widgets"
        icon: "view-media-artist"
        source: "ConfigWidgets.qml"
    }
}
