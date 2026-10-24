import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Weather icon + bold temperature. Click for the 5-day forecast. Hidden until data exists.
BarButton {
    id: root

    visible: Weather.ready
    active: pop.open
    onClicked: pop.toggle()

    Row {
        spacing: Theme.spaceXxs
        Icon {
            icon: Weather.icon
            filled: true
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: Math.round(Weather.temp) + "°C"
            font.pixelSize: Theme.barFontSize
            font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Popup {
        id: pop
        name: "weather"
        anchorItem: root

        onOpenChanged: if (open) Weather.refresh()

        PopupHeader { title: Config.weatherAutoLocate ? "Weather" : Config.weatherLocation }

        RowLayout {
            spacing: Theme.spaceS
            Icon { icon: Weather.icon; filled: true; size: 44; color: Theme.accent }
            ColumnLayout {
                spacing: 0
                StyledText { text: Math.round(Weather.temp) + "°C"; font.pixelSize: Theme.fontSizeTitle; font.weight: Font.Bold }
                StyledText { text: Weather.description + " · feels like " + Math.round(Weather.feelsLike) + "°"; color: Theme.textDim }
            }
        }

        Separator {}

        Repeater {
            model: Weather.daily
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Theme.spaceXs
                StyledText {
                    Layout.preferredWidth: 90
                    text: index === 0 ? "Today" : Time.locale.toString(modelData.date, "dddd")
                }
                Icon { icon: Weather.info(modelData.code, true).icon; filled: true }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.info(modelData.code, true).text
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
                StyledText {
                    text: Math.round(modelData.max) + "° / " + Math.round(modelData.min) + "°"
                    font.features: { "tnum": 1 }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Theme.fontSizeSmall
            color: Weather.stale ? Theme.warning : Theme.textDim
            text: (Weather.stale ? "Offline, showing data from " : "Updated ")
                  + Time.locale.toString(Weather.updated, "HH:mm") + " · Open-Meteo"
        }
    }
}
