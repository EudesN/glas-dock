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
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: img.status !== Image.Ready
        Kirigami.Icon {
            anchors.centerIn: parent
            width: parent.width * 0.6
            height: width
            source: cover.player && cover.player.iconName ? cover.player.iconName : "media-album-cover"
        }
    }

    Image {
        id: img
        visible: false
        source: cover.art
        sourceSize.width: cover.width * 2
        sourceSize.height: cover.height * 2
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    Kirigami.ShadowedTexture {
        anchors.fill: parent
        visible: img.status === Image.Ready
        radius: Math.round(width * 0.18)
        color: "transparent"
        source: img
    }
}
