import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Modular bar display for WeatherModule (and live preview in Bar Display settings).
RowLayout {
    id: root

    property int fontSize: Theme.barFontSize
    spacing: Theme.spaceXxs

    // Fallback if all bar items are turned off so the bar button stays visible and clickable.
    Icon {
        visible: WeatherConfig.enabledBarItems.length === 0
        icon: Weather.ready ? Weather.icon : (Weather.loading ? "cloud_sync" : "cloud_off")
        filled: WeatherConfig.barFilledIcon
        Layout.alignment: Qt.AlignVCenter
    }

    Repeater {
        model: WeatherConfig.enabledBarItems

        delegate: RowLayout {
            id: part
            required property var modelData
            readonly property string itemId: modelData.id
            readonly property string labelText: Weather.barItemText(itemId)

            visible: itemId === "icon" || labelText !== ""
            spacing: 3
            Layout.alignment: Qt.AlignVCenter

            Icon {
                visible: part.itemId === "icon"
                icon: Weather.ready ? Weather.icon : (Weather.loading ? "cloud_sync" : "cloud_off")
                filled: WeatherConfig.barFilledIcon
                Layout.alignment: Qt.AlignVCenter
            }

            Icon {
                visible: part.itemId === "rain" || part.itemId === "wind" || part.itemId === "humidity"
                icon: part.itemId === "rain" ? "water_drop"
                    : part.itemId === "wind" ? "air"
                    : "humidity_percentage"
                size: Theme.fontSize
                color: Theme.textDim
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                visible: part.itemId !== "icon" && part.labelText !== ""
                text: part.labelText
                font.pixelSize: part.itemId === "temp" ? root.fontSize : Math.max(Theme.fontSizeSmall, root.fontSize - 2)
                font.weight: part.itemId === "temp" ? Font.Bold : Font.Normal
                font.features: { "tnum": 1 }
                color: (part.itemId === "condition" || part.itemId === "feelsLike" || part.itemId === "highLow")
                    ? Theme.textDim : Theme.text
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
