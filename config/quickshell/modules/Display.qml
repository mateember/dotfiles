import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Display: laptop + external brightness, connected monitors, screenshots.
BarButton {
    id: root

    active: pop.open
    onClicked: pop.toggle()
    onScrolled: delta => { if (Brightness.available) Brightness.set(Brightness.value + (delta > 0 ? 0.05 : -0.05)); }

    Icon { icon: "desktop_windows" }

    Popup {
        id: pop
        name: "display"
        anchorItem: root

        onOpenChanged: if (open) Brightness.refreshExternals()

        // Close first and wait, so the popup isn't in the screenshot.
        function shot(mode: string) {
            pop.close();
            Quickshell.execDetached(["sh", "-c", 'sleep 0.4; hyprshot -m "$1" --clipboard-only', "sh", mode]);
        }

        PopupHeader {
            title: "Display"
            AppButton { command: ["cosmic-settings", "displays"] }
        }

        RowLayout {
            visible: Brightness.available
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Icon { icon: "brightness_6" }
            StyledSlider {
                Layout.fillWidth: true
                value: Brightness.value
                onMoved: v => Brightness.set(v)
            }
            StyledText {
                text: Math.round(Brightness.value * 100) + "%"
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight
                font.features: { "tnum": 1 }
            }
        }

        // Keyboard backlight: switch + level buttons (off / 1 / 2 ...).
        RowLayout {
            visible: Brightness.kbdAvailable
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            Icon { icon: "keyboard"; filled: Brightness.kbdLevel > 0; color: Brightness.kbdLevel > 0 ? Theme.accent : Theme.text }
            StyledText { text: "Keyboard"; Layout.fillWidth: true; elide: Text.ElideRight }
            Repeater {
                model: Brightness.kbdMax > 1 ? Brightness.kbdMax : 0
                delegate: Rectangle {
                    id: lvl
                    required property int index
                    readonly property int level: index + 1
                    readonly property bool current: Brightness.kbdLevel === level
                    implicitWidth: lvlText.implicitWidth + 2 * Theme.spaceXs
                    implicitHeight: 26
                    radius: height / 2
                    color: current ? Theme.accent : lvlMouse.containsMouse ? Theme.componentHover : Theme.button
                    StyledText {
                        id: lvlText
                        anchors.centerIn: parent
                        text: Brightness.kbdMax === 2 ? (lvl.level === 1 ? "Low" : "High") : String(lvl.level)
                        font.pixelSize: Theme.fontSizeSmall
                        color: lvl.current ? Theme.fgOnAccent : Theme.text
                    }
                    MouseArea {
                        id: lvlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Brightness.setKbd(lvl.level)
                    }
                }
            }
            Toggle {
                checked: Brightness.kbdLevel > 0
                onToggled: Brightness.toggleKbd()
            }
        }

        Repeater {
            model: Brightness.externals
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2
                StyledText { text: modelData.name; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXs
                    Icon { icon: "monitor" }
                    StyledSlider {
                        Layout.fillWidth: true
                        value: modelData.value
                        onMoved: v => Brightness.setExternal(modelData.bus, v)
                    }
                    StyledText { text: Math.round(modelData.value * 100) + "%"; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
                }
            }
        }

        Separator {}

        StyledText { text: "Monitors"; color: Theme.textDim; font.pixelSize: Theme.fontSizeSmall }
        Repeater {
            model: Hyprland.monitors
            delegate: ListItem {
                required property HyprlandMonitor modelData
                icon: modelData.name.startsWith("eDP") ? "laptop" : "monitor"
                text: modelData.description || modelData.name
                subtext: `${modelData.name} · ${modelData.width}×${modelData.height} · scale ${modelData.scale}`
                highlighted: modelData.focused
            }
        }

        Separator {}

        StyledText { text: "Screenshot / pick color (copied to clipboard)"; color: Theme.textDim; font.pixelSize: Theme.fontSizeSmall }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXxs
            Repeater {
                model: [
                    { mode: "region", icon: "screenshot_region", label: "Region" },
                    { mode: "window", icon: "select_window", label: "Window" },
                    { mode: "output", icon: "fullscreen", label: "Screen" },
                    { mode: "color", icon: "colorize", label: "Color" }
                ]
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: Theme.radiusS
                    color: tileMouse.containsMouse ? Theme.componentHover : Theme.component
                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spaceXxxs
                        Icon { icon: tile.modelData.icon; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: tile.modelData.label; font.pixelSize: Theme.fontSizeSmall; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.modelData.mode === "color" ? ColorPicker.pick() : pop.shot(tile.modelData.mode)
                    }
                }
            }
        }
    }
}
