import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Clipboard history (cliphist) with pinned favorite snippets (preserved across Wipe),
// Pause History toggle, and Bitwarden / password-manager secret hygiene.
BarButton {
    id: root

    active: pop.open
    tooltip: Clipboard.paused ? "Clipboard · History Paused" : (`Clipboard (${Clipboard.entries.length} items` + (Clipboard.pins.length > 0 ? `, ${Clipboard.pins.length} pinned)` : ")"))
    tooltipSubtext: "Middle-click to pause/resume · SUPER+SHIFT+C"
    onClicked: button => button === Qt.MiddleButton ? Clipboard.togglePaused() : pop.toggle()

    Icon {
        icon: Clipboard.paused ? "content_paste_off" : "content_paste"
        color: Clipboard.paused ? Theme.warning : Theme.text
    }

    Popup {
        id: pop
        name: "clipboard"
        anchorItem: root
        contentWidth: 400

        onOpenChanged: {
            if (open) {
                search.text = "";
                Clipboard.refresh();
                search.focusInput();
            }
        }

        readonly property string qLower: search.text.trim().toLowerCase()
        readonly property var filteredPins: Clipboard.pins.filter(p =>
            qLower === "" || p.text.toLowerCase().includes(qLower))
        readonly property var filtered: Clipboard.entries.filter(e =>
            qLower === "" || e.text.toLowerCase().includes(qLower))

        function copyAt(i: int) {
            const e = filtered[i];
            if (!e) return;
            Clipboard.copy(e.id);
            pop.close();
        }

        PopupHeader {
            title: Clipboard.paused ? "Clipboard · Paused" : "Clipboard"

            IconButton {
                icon: Clipboard.paused ? "play_arrow" : "pause"
                highlighted: Clipboard.paused
                onClicked: Clipboard.togglePaused()
            }
            IconButton {
                icon: Clipboard.skipPasswordManagers ? "verified_user" : "shield"
                highlighted: Clipboard.skipPasswordManagers
                onClicked: Clipboard.toggleSkipPasswordManagers()
            }
            IconButton {
                icon: "delete_sweep"
                enabled: Clipboard.entries.length > 0
                onClicked: Clipboard.wipe()
            }
        }

        // Status strip for Pause / Secret Hygiene
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXxs

            Rectangle {
                visible: Clipboard.paused
                implicitWidth: pauseLbl.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                color: Theme.alpha(Theme.warning, 0.22)
                border.width: 1
                border.color: Theme.alpha(Theme.warning, 0.6)
                StyledText {
                    id: pauseLbl
                    anchors.centerIn: parent
                    text: "History paused"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.warning
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Clipboard.skipPasswordManagers
                    ? "Auto-skipping password managers (Bitwarden, KeePassXC…)"
                    : "Recording all apps (secret filter off)"
                font.pixelSize: 11
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }

        TextField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search pinned & clipboard history"
            onTextChanged: list.currentIndex = 0
            onAccepted: {
                if (pop.filtered.length > 0) pop.copyAt(list.currentIndex);
                else if (pop.filteredPins.length > 0) {
                    Clipboard.copyPin(pop.filteredPins[0].text);
                    pop.close();
                }
            }
            input.Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
            input.Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
            input.Keys.onEscapePressed: pop.back()
        }

        // ---- Pinned Snippets (preserved across Wipe) ----
        ColumnLayout {
            visible: pop.filteredPins.length > 0
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Icon { icon: "push_pin"; size: 14; color: Theme.accent }
                StyledText {
                    text: "Pinned (" + pop.filteredPins.length + ")"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }
            }

            Repeater {
                model: pop.filteredPins.slice(0, 6)
                delegate: ListItem {
                    id: pinItem
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 38
                    highlighted: true
                    icon: "push_pin"
                    text: modelData.text.replace(/\s+/g, " ").trim()
                    onClicked: {
                        Clipboard.copyPin(pinItem.modelData.text);
                        pop.close();
                    }

                    IconButton {
                        icon: "close"
                        iconSize: 16
                        implicitWidth: 26
                        implicitHeight: 26
                        onClicked: Clipboard.unpin(pinItem.modelData.id)
                    }
                }
            }

            Separator {}
        }

        StyledText {
            visible: pop.filtered.length === 0 && pop.filteredPins.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Clipboard.loading ? "Loading…" : "Nothing here"
            color: Theme.textDim
            Layout.topMargin: Theme.spaceXs
            Layout.bottomMargin: Theme.spaceXs
        }

        ListView {
            id: list
            visible: count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            clip: true
            spacing: 2
            model: pop.filtered
            boundsBehavior: Flickable.StopAtBounds

            delegate: ListItem {
                id: item
                required property var modelData
                required property int index
                readonly property bool pinned: !modelData.isImage && Clipboard.isPinnedPreview(modelData.text)

                width: ListView.view.width
                implicitHeight: modelData.isImage ? 72 : 38
                highlighted: index === list.currentIndex
                icon: modelData.isImage ? "image" : "notes"
                text: modelData.isImage ? "Image" : modelData.text
                onClicked: pop.copyAt(index)

                // Image entries: decode once into the cache dir and show a thumbnail.
                Image {
                    visible: item.modelData.isImage
                    height: 60
                    width: 120
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: thumb.ready ? "file://" + thumb.file : ""
                }

                IconButton {
                    visible: !item.modelData.isImage
                    icon: "push_pin"
                    iconSize: 15
                    highlighted: item.pinned
                    implicitWidth: 26
                    implicitHeight: 26
                    onClicked: Clipboard.pinEntry(item.modelData)
                }

                IconButton {
                    icon: "close"
                    iconSize: 16
                    implicitWidth: 26
                    implicitHeight: 26
                    onClicked: Clipboard.remove(item.modelData.id)
                }

                QtObject {
                    id: thumb
                    property bool ready: false
                    readonly property string file: Quickshell.cachePath("clipboard/" + item.modelData.id + ".png")
                }
                Process {
                    running: item.modelData.isImage
                    command: ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] || cliphist decode "$1" > "$2"', "sh", item.modelData.id, thumb.file]
                    onExited: code => thumb.ready = code === 0
                }
            }
        }
    }
}
