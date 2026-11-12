import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Modular grid of enabled weather detail tiles.
GridLayout {
    id: root

    visible: WeatherConfig.enabledDetailTiles.length > 0
    Layout.fillWidth: true
    columns: WeatherConfig.detailColumns
    columnSpacing: Theme.spaceXxs
    rowSpacing: Theme.spaceXxs

    Repeater {
        model: WeatherConfig.enabledDetailTiles

        delegate: Rectangle {
            id: tile
            required property var modelData
            readonly property var info: Weather.tileData(modelData.id)

            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            implicitHeight: tileCol.implicitHeight + 2 * Theme.spaceXxs
            radius: Theme.radiusS
            color: Theme.component

            ColumnLayout {
                id: tileCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spaceXxs
                spacing: 2

                RowLayout {
                    spacing: Theme.spaceXxxs
                    Icon {
                        icon: tile.info.icon
                        size: Theme.fontSize
                        color: Theme.textDim
                        rotation: tile.info.iconRotation ?? 0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: tile.info.label
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: tile.info.value
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: tile.info.sub
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }
        }
    }
}
