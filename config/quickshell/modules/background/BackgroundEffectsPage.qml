import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "../weather"

// Shared background display effects & reset subpage:
// Fit mode, crossfade duration, dim/blur sliders, Ken Burns motion, multi-monitor sync.
ColumnLayout {
    id: root

    property bool resetArmed: false

    spacing: Theme.spaceXxs

    Timer {
        id: resetDisarmTimer
        interval: 2500
        onTriggered: root.resetArmed = false
    }

    // ---- Fit & Crossfade ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: layoutCardCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: layoutCardCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            OptionPills {
                Layout.fillWidth: true
                label: "Fit Mode"
                options: [
                    { value: "crop",    label: "Fill" },
                    { value: "fit",     label: "Fit" },
                    { value: "stretch", label: "Stretch" },
                    { value: "center",  label: "Center" }
                ]
                currentValue: Wallpapers.fitMode
                onPicked: val => Wallpapers.setFitMode(val)
            }

            OptionPills {
                Layout.fillWidth: true
                label: "Transition"
                options: [
                    { value: 0,    label: "Instant" },
                    { value: 400,  label: "Fast" },
                    { value: 1200, label: "Smooth" },
                    { value: 2000, label: "Slow" }
                ]
                currentValue: Wallpapers.transitionMs
                onPicked: val => Wallpapers.setTransitionMs(val)
            }
        }
    }

    // ---- Dim, Blur & Motion ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: lookCardCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: lookCardCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText { text: "Dim"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim; Layout.preferredWidth: 42 }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 0.0
                    to: 0.70
                    wheelStep: 0.05
                    value: Wallpapers.dimAmount
                    onMoved: v => Wallpapers.setDimAmount(v)
                }
                StyledText {
                    text: Math.round(Wallpapers.dimAmount * 100) + "%"
                    font.pixelSize: 11
                    font.family: Theme.monoFamily
                    color: Theme.text
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText { text: "Blur"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim; Layout.preferredWidth: 42 }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 0.0
                    to: 1.0
                    wheelStep: 0.05
                    value: Wallpapers.blurAmount
                    onMoved: v => Wallpapers.setBlurAmount(v)
                }
                StyledText {
                    text: Math.round(Wallpapers.blurAmount * 100) + "%"
                    font.pixelSize: 11
                    font.family: Theme.monoFamily
                    color: Theme.text
                    Layout.preferredWidth: 38
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: "Ken Burns subtle pan & zoom (static images)"; font.pixelSize: Theme.fontSizeSmall }
                Toggle {
                    checked: Wallpapers.kenBurns
                    onToggled: Wallpapers.setKenBurns(!Wallpapers.kenBurns)
                }
            }

            RowLayout {
                visible: Quickshell.screens.length > 1
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: "Sync image across all monitors"; font.pixelSize: Theme.fontSizeSmall }
                Toggle {
                    checked: Wallpapers.syncScreens
                    onToggled: Wallpapers.setSyncScreens(!Wallpapers.syncScreens)
                }
            }
        }
    }

    // ---- Atmospheric Overlay Shader ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: overlayCardCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: overlayCardCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            OptionPills {
                Layout.fillWidth: true
                label: "Atmosphere"
                options: [
                    { value: "none", label: "None" },
                    { value: "snow", label: "Snow" }
                ]
                currentValue: Wallpapers.overlayEffect
                onPicked: val => Wallpapers.setOverlayEffect(val)
            }

            RowLayout {
                visible: Wallpapers.overlayEffect !== "none"
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText { text: "Density"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim; Layout.preferredWidth: 50 }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 0.2
                    to: 1.5
                    wheelStep: 0.05
                    value: Wallpapers.overlayIntensity
                    onMoved: v => Wallpapers.setOverlayIntensity(v)
                }
                StyledText {
                    text: Math.round(Wallpapers.overlayIntensity * 100) + "%"
                    font.pixelSize: 11
                    font.family: Theme.monoFamily
                    color: Theme.text
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                visible: Wallpapers.overlayEffect !== "none"
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText { text: "Speed"; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim; Layout.preferredWidth: 50 }
                StyledSlider {
                    Layout.fillWidth: true
                    from: 0.25
                    to: 2.0
                    wheelStep: 0.1
                    value: Wallpapers.overlaySpeed
                    onMoved: v => Wallpapers.setOverlaySpeed(v)
                }
                StyledText {
                    text: Wallpapers.overlaySpeed.toFixed(2) + "x"
                    font.pixelSize: 11
                    font.family: Theme.monoFamily
                    color: Theme.text
                    Layout.preferredWidth: 40
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }

    // ---- Two-Click Destructive Reset ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 36
        radius: Theme.radiusS
        color: root.resetArmed ? Qt.rgba(1.0, 0.35, 0.35, 0.20)
             : resetMouse.containsMouse ? Theme.componentHover
             : Theme.surface1
        border.width: 1
        border.color: root.resetArmed ? Theme.destructive : Theme.componentDivider
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "restart_alt"
                size: 16
                color: root.resetArmed ? Theme.destructive : Theme.text
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.resetArmed ? "Click again to confirm reset" : "Reset background settings"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: root.resetArmed ? Font.DemiBold : Font.Normal
                color: root.resetArmed ? Theme.destructive : Theme.text
            }
        }

        MouseArea {
            id: resetMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (!root.resetArmed) {
                    root.resetArmed = true;
                    resetDisarmTimer.restart();
                    return;
                }
                resetDisarmTimer.stop();
                root.resetArmed = false;
                Wallpapers.reset();
            }
        }
    }
}
