import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Weather icon + bold temperature. Click for today's details (rain, humidity, wind, UV, pressure, sun)
// and the 5-day forecast. Hidden until data exists.
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
        contentWidth: 340

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

        // Today's details: 3×2 tiles
        GridLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceXxs
            columns: 3
            columnSpacing: Theme.spaceXxs
            rowSpacing: Theme.spaceXxs

            component Tile: Rectangle {
                id: tile
                property string icon: ""
                property string label: ""
                property string value: ""
                property string sub: ""
                property real iconRotation: 0
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
                        Icon { icon: tile.icon; size: Theme.fontSize; color: Theme.textDim; rotation: tile.iconRotation }
                        StyledText { text: tile.label; color: Theme.textDim; font.pixelSize: Theme.fontSizeSmall }
                    }
                    StyledText { text: tile.value; font.weight: Font.DemiBold; font.features: { "tnum": 1 } }
                    StyledText {
                        visible: text !== ""
                        Layout.fillWidth: true
                        text: tile.sub
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }
            }

            Tile {
                icon: "rainy"; label: "Rain"
                value: Weather.rainChance + "%"
                sub: Weather.rainToday.toFixed(1) + " mm today"
            }
            Tile {
                icon: "humidity_percentage"; label: "Humidity"
                value: Math.round(Weather.humidity) + "%"
            }
            Tile {
                // arrow points where the wind blows to
                icon: "navigation"; label: "Wind"; iconRotation: Weather.windDir + 180
                value: Math.round(Weather.wind) + " km/h"
                sub: Weather.compass(Weather.windDir) + " · gusts " + Math.round(Weather.gusts)
            }
            Tile {
                icon: "light_mode"; label: "UV"
                value: Weather.uvMax.toFixed(0)
                sub: Weather.uvMax < 3 ? "low" : Weather.uvMax < 6 ? "moderate" : Weather.uvMax < 8 ? "high" : "very high"
            }
            Tile {
                icon: "compress"; label: "Pressure"
                value: Math.round(Weather.pressure) + " hPa"
            }
            Tile {
                icon: "wb_twilight"; label: "Sun"
                value: Time.locale.toString(Weather.sunrise, "HH:mm")
                sub: "sets " + Time.locale.toString(Weather.sunset, "HH:mm")
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
                Row {
                    visible: modelData.rainChance > 0
                    spacing: 2
                    Icon { icon: "water_drop"; size: Theme.fontSizeSmall; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    StyledText {
                        text: modelData.rainChance + "%"
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: { "tnum": 1 }
                        anchors.verticalCenter: parent.verticalCenter
                    }
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
