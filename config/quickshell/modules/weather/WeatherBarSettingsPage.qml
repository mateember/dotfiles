import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Modular bar display customization: live preview, presets, toggles, and reorderable items.
ColumnLayout {
    id: root

    signal goBack()

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    PopupHeader {
        title: "Bar Display"
        showBack: true
        backAction: () => root.goBack()
    }

    // ---- Live bar pill preview ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 46
        radius: Theme.radiusM
        color: Qt.rgba(1, 1, 1, 0.04)
        border.width: 1
        border.color: Theme.divider

        Rectangle {
            readonly property bool barIcons: true
            anchors.centerIn: parent
            implicitWidth: Math.min(parent.width - 2 * Theme.spaceXs, previewBar.implicitWidth + 2 * Theme.spaceXs)
            implicitHeight: Theme.barHeight - 4
            radius: height / 2
            color: Theme.barBg
            border.width: 1
            border.color: Theme.divider
            clip: true

            WeatherBarContent {
                id: previewBar
                anchors.centerIn: parent
            }
        }
    }

    // ---- Quick Presets ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        Repeater {
            model: [
                { id: "default",  label: "Default" },
                { id: "icon",     label: "Icon" },
                { id: "compact",  label: "Compact" },
                { id: "detailed", label: "Detailed" }
            ]
            delegate: Rectangle {
                id: presetBtn
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 28
                radius: Theme.radiusS
                color: presetMouse.pressed ? Theme.componentPressed
                     : presetMouse.containsMouse ? Theme.componentHover
                     : Theme.component
                StyledText {
                    anchors.centerIn: parent
                    text: presetBtn.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                }
                MouseArea {
                    id: presetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WeatherConfig.applyBarPreset(presetBtn.modelData.id)
                }
            }
        }
    }

    // ---- Bar Options ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: optsCol.implicitHeight + 2 * Theme.spaceXs
        radius: Theme.radiusS
        color: Theme.component

        ColumnLayout {
            id: optsCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: "Show unit symbol (°C / °F)" }
                Toggle {
                    checked: WeatherConfig.barShowUnit
                    onToggled: WeatherConfig.setBarShowUnit(!WeatherConfig.barShowUnit)
                }
            }

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.divider }

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: "Filled condition icon" }
                Toggle {
                    checked: WeatherConfig.barFilledIcon
                    onToggled: WeatherConfig.setBarFilledIcon(!WeatherConfig.barFilledIcon)
                }
            }
        }
    }

    StyledText {
        text: "Bar modules (toggle & reorder)"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textDim
    }

    ModularOrderList {
        listKind: "bar"
        model: WeatherConfig.barItems
        maxListHeight: 300
        valueFormatter: id => Weather.barItemText(id)
    }
}
