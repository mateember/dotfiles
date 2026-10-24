import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Removable USB / SD storage bar module & eject menu.
// Auto-hides on the bar when no removable drives are plugged in (still accessible via `!drives`).
BarButton {
    id: root

    visible: Storage.count > 0 || pop.open
    active: pop.open
    onClicked: pop.toggle()

    Icon {
        icon: "usb"
        color: Storage.mountedCount > 0 ? Theme.accent : Theme.text
    }

    StyledText {
        visible: Storage.count > 1
        text: String(Storage.count)
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.DemiBold
    }

    Popup {
        id: pop
        name: "storage"
        anchorItem: root

        onOpenChanged: if (open) Storage.refresh()

        PopupHeader {
            title: "Removable Drives"
            IconButton {
                icon: "refresh"
                onClicked: Storage.refresh()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Icon { icon: "hdr_auto"; size: 18; color: Theme.textDim }
            StyledText {
                Layout.fillWidth: true
                text: "Automount new drives"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
            Toggle {
                checked: Storage.autoMount
                onToggled: Storage.autoMount = !Storage.autoMount
            }
        }

        Separator {}

        StyledText {
            visible: Storage.count === 0
            text: "No removable USB or SD drives connected"
            color: Theme.textDim
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: Storage.count > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: Storage.drives
                delegate: Rectangle {
                    id: drvRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 54
                    radius: Theme.radiusS
                    color: drvMouse.containsMouse ? Theme.componentHover : Theme.component

                    MouseArea {
                        id: drvMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drvRow.modelData.mounted ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (drvRow.modelData.mounted) {
                                pop.close();
                                Storage.openInFiles(drvRow.modelData.mountpoint);
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceXs
                        anchors.rightMargin: Theme.spaceXs
                        spacing: Theme.spaceXs

                        Icon {
                            icon: drvRow.modelData.tran === "mmc" ? "sd_card" : "usb"
                            color: drvRow.modelData.mounted ? Theme.accent : Theme.textDim
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            StyledText {
                                Layout.fillWidth: true
                                text: drvRow.modelData.label
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: `${drvRow.modelData.size} · ${drvRow.modelData.fstype}` +
                                      (drvRow.modelData.mounted ? ` · ${drvRow.modelData.mountpoint}` : " · Unmounted")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textDim
                                elide: Text.ElideRight
                            }
                        }

                        // Mount / Unmount button
                        IconButton {
                            icon: drvRow.modelData.mounted ? "folder_open" : "play_arrow"
                            visible: !drvRow.modelData.mounted
                            onClicked: Storage.mount(drvRow.modelData.path, false)
                        }

                        // Safe Eject button
                        IconButton {
                            icon: "eject"
                            onClicked: Storage.eject(drvRow.modelData.path, drvRow.modelData.diskPath)
                        }
                    }
                }
            }
        }
    }
}
