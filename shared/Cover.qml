/*
 * Glasdock — rounded album cover with the player's icon as fallback.
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: cover

    property var player: null
    readonly property string art: player ? (player.artUrl || "").toString() : ""

    Rectangle {
        anchors.fill: parent
        radius: Math.round(width * 0.18)
        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)
        visible: img.status !== Image.Ready
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.56
            height: width
            opacity: 0.75
            source: cover.player && cover.player.iconName ? cover.player.iconName : "media-album-cover"
        }
    }

    Image {
        id: img
        visible: false
        source: cover.art
        // Fixed sourceSize so layout changes never abort/restart loading and
        // MprisSource's background prefetcher shares the same QQuickPixmapCache entry
        sourceSize: Qt.size(256, 256)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    Kirigami.ShadowedTexture {
        anchors.fill: parent
        opacity: img.status === Image.Ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        radius: Math.round(width * 0.18)
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        shadow.size: cover.width > 60 ? 16 : 0
        shadow.yOffset: cover.width > 60 ? 4 : 0
        shadow.color: Qt.rgba(0, 0, 0, 0.35)
        source: img
    }
}
