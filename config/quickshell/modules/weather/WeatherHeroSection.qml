import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Current weather hero card: big icon, temperature, condition, feels like, and today's high/low.
RowLayout {
    id: root

    Layout.fillWidth: true
    spacing: Theme.spaceS

    Icon {
        icon: Weather.icon
        filled: true
        size: 44
        color: Theme.accent
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs
            StyledText {
                text: Weather.formatTemp(Weather.tempC, true)
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
            StyledText {
                visible: Weather.daily.length > 0
                text: Weather.daily.length > 0
                    ? ("↑ " + Weather.formatTemp(Weather.daily[0].maxC, false)
                       + "  ↓ " + Weather.formatTemp(Weather.daily[0].minC, false))
                    : ""
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Weather.description + " · feels like " + Weather.formatTemp(Weather.feelsLikeC, false)
            color: Theme.textDim
            elide: Text.ElideRight
        }

        StyledText {
            visible: Weather.displayRegion !== ""
            Layout.fillWidth: true
            text: Weather.displayRegion + (WeatherConfig.autoLocate ? " · Auto" : "")
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }
}
