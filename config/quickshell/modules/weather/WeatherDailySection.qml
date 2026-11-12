import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Multi-day forecast list (3, 5, 7, or 10 days).
ColumnLayout {
    id: root

    readonly property var daysModel: Weather.daily.slice(0, WeatherConfig.forecastDays)

    visible: daysModel.length > 0
    Layout.fillWidth: true
    spacing: Theme.spaceXxs

    Repeater {
        model: root.daysModel

        delegate: RowLayout {
            id: dayRow
            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: Theme.spaceXs

            StyledText {
                Layout.preferredWidth: 90
                text: dayRow.index === 0 ? "Today" : Time.locale.toString(dayRow.modelData.date, "dddd")
                elide: Text.ElideRight
            }

            Icon {
                icon: Weather.info(dayRow.modelData.code, true).icon
                filled: true
            }

            StyledText {
                Layout.fillWidth: true
                text: Weather.info(dayRow.modelData.code, true).text
                color: Theme.textDim
                elide: Text.ElideRight
            }

            Row {
                visible: dayRow.modelData.rainChance > 0
                spacing: 2
                Icon {
                    icon: "water_drop"
                    size: Theme.fontSizeSmall
                    color: Theme.textDim
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: dayRow.modelData.rainChance + "%"
                    color: Theme.textDim
                    font.pixelSize: Theme.fontSizeSmall
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: Weather.formatTemp(dayRow.modelData.maxC, false)
                    + " / "
                    + Weather.formatTemp(dayRow.modelData.minC, false)
                font.features: { "tnum": 1 }
            }
        }
    }
}
