import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services

// Clipboard history (cliphist). Type to filter, ↑/↓ to select, Enter to copy.
BarButton {
    id: root

    active: pop.open
    onClicked: pop.toggle()

    Icon { icon: "content_paste" }

    Popup {
        id: pop
        name: "clipboard"
        anchorItem: root
        contentWidth: 380

        onOpenChanged: {
            if (open) {
                search.text = "";
                Clipboard.refresh();
                search.focusInput();
            }
        }

        readonly property var filtered: Clipboard.entries.filter(e =>
            search.text === "" || e.text.toLowerCase().includes(search.text.toLowerCase()))

        function copyAt(i: int) {
            const e = filtered[i];
            if (!e) return;
            Clipboard.copy(e.id);
            pop.close();
        }

        PopupHeader {
            title: "Clipboard"
            IconButton {
                icon: "delete_sweep"
                enabled: Clipboard.entries.length > 0
                onClicked: Clipboard.wipe()
            }
        }

        TextField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search clipboard"
            onTextChanged: list.currentIndex = 0
            onAccepted: pop.copyAt(list.currentIndex)
            input.Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
            input.Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
            input.Keys.onEscapePressed: pop.close()
        }

        StyledText {
            visible: pop.filtered.length === 0
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
            Layout.preferredHeight: Math.min(contentHeight, 400)
            clip: true
            spacing: 2
            model: pop.filtered
            boundsBehavior: Flickable.StopAtBounds

            delegate: ListItem {
                id: item
                required property var modelData
                required property int index
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
