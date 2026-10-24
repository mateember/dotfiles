import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Bar customization app (launched from the Launcher's `!` Quickshell apps list or via
// `qs ipc call barsettings toggle`). Real Wayland window (FloatingWindow), floated and
// centered by Hyprland window rules.
Scope {
    id: root

    LazyLoader {
        active: BarConfig.settingsOpen

        FloatingWindow {
            id: win

            title: "HCS — Bar Settings"
            implicitWidth: 560
            implicitHeight: 620
            minimumSize: Qt.size(560, 620)
            maximumSize: Qt.size(560, 620)
            color: "transparent"

            onClosed: BarConfig.settingsOpen = false

            property string filterSection: "all"   // "all" | "left" | "center" | "right"

            readonly property var filteredItems: {
                if (filterSection === "all") return BarConfig.items;
                return BarConfig.items.filter(i => i.section === filterSection);
            }

            function sectionList(sec: string): var {
                return sec === "left" ? BarConfig.leftIds
                     : sec === "center" ? BarConfig.centerIds
                     : BarConfig.rightIds;
            }

            function canMoveUp(item: var): bool {
                const ids = sectionList(item.section);
                return ids.indexOf(item.id) > 0;
            }

            function canMoveDown(item: var): bool {
                const ids = sectionList(item.section);
                const idx = ids.indexOf(item.id);
                return idx >= 0 && idx < ids.length - 1;
            }

            Rectangle {
                id: card
                anchors.fill: parent
                color: Theme.popupBg
                focus: true
                Component.onCompleted: card.forceActiveFocus()
                Keys.onEscapePressed: BarConfig.settingsOpen = false

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: Theme.spaceS
                    spacing: Theme.spaceXs

                    // ---- Header ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXs

                        Icon {
                            icon: "view_agenda"
                            size: 24
                            color: Theme.accent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                text: "Bar Settings"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                            }
                            StyledText {
                                text: "Toggle modules on/off, reorder with ↑/↓, or click section badge"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.textDim
                            }
                        }
                        Rectangle {
                            implicitWidth: resetLabel.implicitWidth + 2 * Theme.spaceXs
                            implicitHeight: 30
                            radius: 15
                            color: resetMouse.pressed ? Theme.componentPressed
                                 : resetMouse.containsMouse ? Theme.componentHover
                                 : Theme.component
                            StyledText {
                                id: resetLabel
                                anchors.centerIn: parent
                                text: "Reset"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.text
                            }
                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: BarConfig.reset()
                            }
                        }
                        IconButton {
                            icon: "close"
                            onClicked: BarConfig.settingsOpen = false
                        }
                    }

                    // ---- Section filter tabs ----
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceXxs

                        Repeater {
                            model: [
                                { id: "all",    label: "All (" + BarConfig.items.length + ")" },
                                { id: "left",   label: "Left (" + BarConfig.leftIds.length + ")" },
                                { id: "center", label: "Center (" + BarConfig.centerIds.length + ")" },
                                { id: "right",  label: "Right (" + BarConfig.rightIds.length + ")" }
                            ]
                            delegate: Rectangle {
                                id: tab
                                required property var modelData
                                readonly property bool active: win.filterSection === modelData.id
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: Theme.radiusS
                                color: active ? Theme.accent
                                     : tabMouse.containsMouse ? Theme.componentHover
                                     : Theme.component
                                StyledText {
                                    anchors.centerIn: parent
                                    text: tab.modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: tab.active ? Font.DemiBold : Font.Normal
                                    color: tab.active ? Theme.fgOnAccent : Theme.text
                                }
                                MouseArea {
                                    id: tabMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.filterSection = tab.modelData.id
                                }
                            }
                        }
                    }

                    Separator {}

                    // ---- Module list ----
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: win.filteredItems

                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            width: ListView.view.width
                            height: 52
                            radius: Theme.radiusS
                            color: Theme.component

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spaceXs
                                anchors.rightMargin: Theme.spaceXs
                                spacing: Theme.spaceXs

                                Icon {
                                    icon: row.modelData.icon
                                    size: 20
                                    color: row.modelData.enabled ? Theme.accent : Theme.textDim
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.modelData.name
                                        color: row.modelData.enabled ? Theme.text : Theme.textDim
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        text: row.modelData.subtitle
                                        color: Theme.textDim
                                        font.pixelSize: Theme.fontSizeSmall
                                        elide: Text.ElideRight
                                    }
                                }

                                // Section badge (click cycles Left -> Center -> Right)
                                Rectangle {
                                    implicitWidth: 58
                                    implicitHeight: 26
                                    radius: 13
                                    color: secMouse.pressed ? Theme.primaryPressed
                                         : secMouse.containsMouse ? Theme.primaryHover
                                         : Theme.primaryComponent
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: row.modelData.section === "left" ? "Left"
                                            : row.modelData.section === "center" ? "Center" : "Right"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.text
                                    }
                                    MouseArea {
                                        id: secMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: BarConfig.cycleSection(row.modelData.id)
                                    }
                                }

                                IconButton {
                                    icon: "keyboard_arrow_up"
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    iconSize: 18
                                    enabled: win.canMoveUp(row.modelData)
                                    onClicked: BarConfig.move(row.modelData.id, -1)
                                }

                                IconButton {
                                    icon: "keyboard_arrow_down"
                                    implicitWidth: 28
                                    implicitHeight: 28
                                    iconSize: 18
                                    enabled: win.canMoveDown(row.modelData)
                                    onClicked: BarConfig.move(row.modelData.id, 1)
                                }

                                Toggle {
                                    checked: row.modelData.enabled
                                    onToggled: BarConfig.toggle(row.modelData.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
