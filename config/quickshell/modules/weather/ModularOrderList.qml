import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Reorderable + toggleable list of modular weather items (bar parts, popup sections, detail tiles).
ListView {
    id: root

    required property string listKind      // "bar" | "sections" | "tiles"
    property var valueFormatter: null      // optional (id) => string
    property int maxListHeight: 360

    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(contentHeight, maxListHeight)
    clip: true
    spacing: 4
    boundsBehavior: Flickable.StopAtBounds

    delegate: Rectangle {
        id: row
        required property var modelData
        required property int index

        readonly property string previewText: root.valueFormatter ? (root.valueFormatter(modelData.id) ?? "") : ""

        width: ListView.view.width
        height: 48
        radius: Theme.radiusS
        color: Theme.component

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXs
            anchors.rightMargin: Theme.spaceXs
            spacing: Theme.spaceXxs

            Icon {
                icon: row.modelData.icon
                size: 18
                color: row.modelData.enabled ? Theme.accent : Theme.textDim
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXxs
                    StyledText {
                        text: row.modelData.name
                        color: row.modelData.enabled ? Theme.text : Theme.textDim
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    StyledText {
                        visible: row.previewText !== ""
                        Layout.fillWidth: true
                        text: row.previewText
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: { "tnum": 1 }
                        elide: Text.ElideRight
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: row.modelData.subtitle
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "keyboard_arrow_up"
                implicitWidth: 26
                implicitHeight: 26
                iconSize: 16
                enabled: row.index > 0
                onClicked: WeatherConfig.moveListItem(root.listKind, row.modelData.id, -1)
            }

            IconButton {
                icon: "keyboard_arrow_down"
                implicitWidth: 26
                implicitHeight: 26
                iconSize: 16
                enabled: row.index < root.count - 1
                onClicked: WeatherConfig.moveListItem(root.listKind, row.modelData.id, 1)
            }

            Toggle {
                checked: row.modelData.enabled
                onToggled: WeatherConfig.toggleListItem(root.listKind, row.modelData.id)
            }
        }
    }
}
