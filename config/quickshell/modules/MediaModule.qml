import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// MPRIS media. Click opens the player popup, right or middle click toggles play/pause.
BarButton {
    id: root

    active: pop.open
    opacity: Media.active ? 1 : 0.5
    onClicked: button => button === Qt.LeftButton ? pop.toggle() : Media.togglePlaying()

    Icon { icon: Media.playing ? "pause" : "play_arrow"; filled: true }

    Popup {
        id: pop
        name: "media"
        anchorItem: root
        contentWidth: 340

        readonly property MprisPlayer player: Media.active

        // MPRIS position isn't pushed; poll while visible.
        Timer {
            interval: 1000
            repeat: true
            running: pop.open && Media.playing
            onTriggered: pop.player?.positionChanged()
        }

        StyledText {
            visible: !pop.player
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Nothing is playing"
            color: Theme.textDim
        }

        RowLayout {
            visible: !!pop.player
            Layout.fillWidth: true
            spacing: Theme.spaceS

            ClippingRectangle {
                implicitWidth: 72
                implicitHeight: 72
                radius: Theme.radiusS
                color: Theme.component
                Image {
                    anchors.fill: parent
                    source: pop.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 144
                    sourceSize.height: 144
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !(pop.player?.trackArtUrl)
                    icon: "music_note"
                    size: 32
                    color: Theme.textDim
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: pop.player?.trackTitle || pop.player?.identity || "Nothing is playing"
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: pop.player?.trackArtist || ""
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: pop.player?.identity ?? ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            visible: !!pop.player && (pop.player?.lengthSupported ?? false) && pop.player.length > 0
            Layout.fillWidth: true
            spacing: 0
            StyledSlider {
                Layout.fillWidth: true
                to: Math.max(1, pop.player?.length ?? 1)
                value: pop.player?.position ?? 0
                enabled: pop.player?.canSeek ?? false
                onMoved: v => { if (pop.player) pop.player.position = v; }
            }
            RowLayout {
                Layout.fillWidth: true
                StyledText { text: Media.formatTime(pop.player?.position ?? 0); font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                Item { Layout.fillWidth: true }
                StyledText { text: Media.formatTime(pop.player?.length ?? 0); font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
            }
        }

        RowLayout {
            visible: !!pop.player
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spaceS
            IconButton { icon: "skip_previous"; filled: true; enabled: pop.player?.canGoPrevious ?? false; onClicked: Media.previous() }
            IconButton {
                icon: Media.playing ? "pause" : "play_arrow"
                filled: true
                highlighted: true
                implicitWidth: 44
                implicitHeight: 44
                iconSize: 26
                onClicked: Media.togglePlaying()
            }
            IconButton { icon: "skip_next"; filled: true; enabled: pop.player?.canGoNext ?? false; onClicked: Media.next() }
        }

        ListItem {
            visible: pop.player?.canRaise ?? false
            icon: "open_in_new"
            text: "Open " + (pop.player?.identity ?? "player")
            onClicked: { pop.player.raise(); pop.close(); }
        }

        Separator { visible: Media.players.length > 1 }

        Repeater {
            model: Media.players.length > 1 ? Media.players : []
            delegate: ListItem {
                required property MprisPlayer modelData
                icon: modelData.isPlaying ? "graphic_eq" : "music_note"
                text: modelData.identity
                subtext: modelData.trackTitle
                highlighted: modelData === Media.active
                onClicked: Media.selected = modelData
            }
        }
    }
}
