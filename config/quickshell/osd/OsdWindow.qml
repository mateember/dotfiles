import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// OSD pill at the bottom center of the focused monitor. Click-through (empty input mask).
PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: Osd.visible || pill.opacity > 0
    color: "transparent"

    anchors.bottom: true
    margins.bottom: Math.round((screen?.height ?? 900) * 0.12)
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    implicitWidth: 320
    implicitHeight: 56
    mask: Region {}

    WlrLayershell.namespace: "hcs-osd"
    WlrLayershell.layer: WlrLayer.Overlay

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: Theme.osdBg
        border.color: Theme.popupBorder
        border.width: 1
        opacity: Osd.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceS
            anchors.rightMargin: Theme.spaceS
            spacing: Theme.spaceXs

            Rectangle {
                visible: Osd.swatch.a > 0
                implicitWidth: 24
                implicitHeight: 24
                radius: 12
                color: Osd.swatch
                border.color: Theme.componentBorder
                border.width: 1
            }
            Icon {
                visible: Osd.swatch.a === 0
                icon: Osd.icon
                filled: true
                size: 22
                color: Theme.accent
            }

            StyledText {
                visible: Osd.value < 0
                Layout.fillWidth: true
                text: Osd.label
                elide: Text.ElideRight
            }

            Rectangle {
                visible: Osd.value >= 0
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.componentHover
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, Osd.value / Osd.max))
                    height: parent.height
                    radius: parent.radius
                    color: Osd.value > 1.0001 ? Theme.warning : Theme.accent   // above 100 % volume
                    Behavior on width { NumberAnimation { duration: Theme.animFast } }
                }
            }
            StyledText {
                visible: Osd.value >= 0
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: Math.round(Osd.value * 100) + "%"
                font.features: { "tnum": 1 }
            }
        }
    }
}
