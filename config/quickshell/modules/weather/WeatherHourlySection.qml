import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Scrollable hourly forecast strip (12h or 24h).
Rectangle {
    id: root

    readonly property var hoursModel: Weather.hourly.slice(0, WeatherConfig.hourlyHours)

    visible: hoursModel.length > 0
    Layout.fillWidth: true
    implicitHeight: 96
    radius: Theme.radiusS
    color: Theme.component

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.spaceXxs
        orientation: ListView.Horizontal
        spacing: 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.hoursModel

        delegate: Item {
            id: cell
            required property var modelData
            required property int index

            width: 54
            height: ListView.view.height

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.formatHourLabel(cell.modelData.isoTime, cell.index)
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: cell.index === 0 ? Font.DemiBold : Font.Normal
                    color: cell.index === 0 ? Theme.accent : Theme.textDim
                }

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: Weather.info(cell.modelData.code, cell.modelData.isDay).icon
                    filled: true
                    size: 18
                    color: cell.index === 0 ? Theme.accent : Theme.text
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.formatTemp(cell.modelData.tempC, false)
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 1
                    opacity: cell.modelData.rainChance > 0 ? 1 : 0
                    Icon {
                        icon: "water_drop"
                        size: 10
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: cell.modelData.rainChance + "%"
                        font.pixelSize: 10
                        font.features: { "tnum": 1 }
                        color: Theme.textDim
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // Allow vertical mouse wheel / touchpad scroll to pan horizontally.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
                ? event.angleDelta.x : event.angleDelta.y;
            const maxX = Math.max(0, list.contentWidth - list.width);
            list.contentX = Math.max(0, Math.min(maxX, list.contentX - delta * 0.5));
        }
    }
}
