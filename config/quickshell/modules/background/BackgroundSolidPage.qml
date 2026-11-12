import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Solid color backdrop tab: curated dark palette swatches, custom hex field,
// hyprpicker eyedropper integration, and optional subtle radial vignette.
ColumnLayout {
    id: root

    property bool returnAsWindow: false
    property string returnScreen: ""

    spacing: Theme.spaceXxs

    // Curated Dark Swatches
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 6
        rowSpacing: 6

        Repeater {
            model: Wallpapers.solidSwatches
            delegate: Rectangle {
                required property var modelData
                readonly property bool selected: Wallpapers.solidColor.toUpperCase() === modelData.hex.toUpperCase()

                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.radiusS
                color: selected ? Theme.surface2
                     : swatchMouse.containsMouse ? Theme.componentHover
                     : Theme.surface1
                border.width: selected ? 1.5 : 1
                border.color: selected ? Theme.accent : Theme.componentDivider
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceXxs
                    anchors.rightMargin: Theme.spaceXxs
                    spacing: Theme.spaceXxs

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
                        color: modelData.hex
                        border.width: 1
                        border.color: Theme.componentBorder

                        Icon {
                            visible: selected
                            anchors.centerIn: parent
                            icon: "check"
                            size: 13
                            color: Theme.accent
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: selected ? Font.DemiBold : Font.Normal
                        color: selected ? Theme.textStrong : Theme.text
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: swatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpapers.setSolidColor(modelData.hex)
                }
            }
        }
    }

    // Custom Hex + Eyedropper Card
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: customSolidCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: customSolidCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXxs

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: Wallpapers.solidColor
                    border.width: 1
                    border.color: Theme.componentBorder
                }

                TextField {
                    id: hexInput
                    Layout.fillWidth: true
                    text: Wallpapers.solidColor
                    placeholder: "#1B1B1B"
                    onAccepted: Wallpapers.setSolidColor(text)
                }

                Rectangle {
                    implicitHeight: 30
                    implicitWidth: applyLbl.implicitWidth + 18
                    radius: Theme.radiusXl
                    color: applyMouse.containsMouse ? Theme.componentHover : Theme.component
                    border.width: 1
                    border.color: Theme.componentDivider

                    StyledText {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: "Apply"
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.setSolidColor(hexInput.text)
                    }
                }

                IconButton {
                    icon: "colorize"
                    implicitWidth: 30
                    implicitHeight: 30
                    iconSize: 16
                    onClicked: {
                        const scr = root.returnScreen;
                        const asWin = root.returnAsWindow;
                        ColorPicker.pickWith(hex => {
                            Wallpapers.setSolidColor(hex);
                            if (asWin) Popups.openWindow("background@" + scr);
                            else Popups.open("background@" + scr);
                        });
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: "Subtle radial vignette"
                    font.pixelSize: Theme.fontSizeSmall
                }
                Toggle {
                    checked: Wallpapers.solidVignette
                    onToggled: Wallpapers.setSolidVignette(!Wallpapers.solidVignette)
                }
            }
        }
    }
}
