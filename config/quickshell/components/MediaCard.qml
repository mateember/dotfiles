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
    // Cover (56) + 8 px margin above and below; everything in the row is vertically centered.
    implicitHeight: 56 + 2 * Theme.spaceXxs
    radius: Theme.radiusM
    color: Theme.component

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceXxs
        anchors.rightMargin: Theme.spaceXs
        spacing: Theme.spaceXs

        ClippingRectangle {
            Layout.alignment: Qt.AlignVCenter
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
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || root.player?.identity || ""
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                // Artist, or the player's name when the track has a title but no artist.
                text: root.player?.trackArtist || (root.player?.trackTitle ? root.player?.identity ?? "" : "")
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }

        IconButton { Layout.alignment: Qt.AlignVCenter; icon: "skip_previous"; filled: true; enabled: root.player?.canGoPrevious ?? false; onClicked: Media.previous() }
        IconButton {
            Layout.alignment: Qt.AlignVCenter
            icon: Media.playing ? "pause" : "play_arrow"
            filled: true
            highlighted: true
            implicitWidth: 38
            implicitHeight: 38
            iconSize: 22
            onClicked: Media.togglePlaying()
        }
        IconButton { Layout.alignment: Qt.AlignVCenter; icon: "skip_next"; filled: true; enabled: root.player?.canGoNext ?? false; onClicked: Media.next() }
    }
}
