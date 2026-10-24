import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.services

// Compact now-playing card: cover, title, artist, previous / play-pause / next.
// Used in the quick settings panel and the notification center. Hidden without a player.
Rectangle {
    id: root

    readonly property MprisPlayer player: Media.active

    visible: !!player
    Layout.fillWidth: true
    implicitHeight: 72
    radius: Theme.radiusM
    color: Theme.component

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceXs
        spacing: Theme.spaceXs

        ClippingRectangle {
            implicitWidth: 56
            implicitHeight: 56
            radius: Theme.radiusS
            color: Theme.componentHover
            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 112
                sourceSize.height: 112
            }
            Icon {
                anchors.centerIn: parent
                visible: !(root.player?.trackArtUrl)
                icon: "music_note"
                size: 26
                color: Theme.textDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || root.player?.identity || ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || root.player?.identity || ""
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        IconButton { icon: "skip_previous"; filled: true; enabled: root.player?.canGoPrevious ?? false; onClicked: Media.previous() }
        IconButton {
            icon: Media.playing ? "pause" : "play_arrow"
            filled: true
            highlighted: true
            implicitWidth: 38
            implicitHeight: 38
            iconSize: 22
            onClicked: Media.togglePlaying()
        }
        IconButton { icon: "skip_next"; filled: true; enabled: root.player?.canGoNext ?? false; onClicked: Media.next() }
    }
}
