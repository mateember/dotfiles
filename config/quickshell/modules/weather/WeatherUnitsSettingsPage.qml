import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Unit preferences (Metric/Imperial preset + individual overrides) and auto-refresh interval.
ColumnLayout {
    id: root

    signal goBack()

    readonly property bool isMetric: WeatherConfig.tempUnit === "C"
        && WeatherConfig.windUnit === "kmh"
        && WeatherConfig.precipUnit === "mm"
        && WeatherConfig.pressureUnit === "hPa"
        && WeatherConfig.visibilityUnit === "km"

    readonly property bool isImperial: WeatherConfig.tempUnit === "F"
        && WeatherConfig.windUnit === "mph"
        && WeatherConfig.precipUnit === "in"
        && WeatherConfig.pressureUnit === "inHg"
        && WeatherConfig.visibilityUnit === "mi"

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    PopupHeader {
        title: "Units & Refresh"
        showBack: true
        backAction: () => root.goBack()
    }

    // ---- Metric / Imperial Quick Presets ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        Repeater {
            model: [
                { id: "metric",   label: "Metric (°C, km/h, mm)", active: root.isMetric },
                { id: "imperial", label: "Imperial (°F, mph, in)", active: root.isImperial }
            ]
            delegate: Rectangle {
                id: sysBtn
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusS
                color: modelData.active ? Theme.accent
                     : sysMouse.containsMouse ? Theme.componentHover
                     : Theme.component
                StyledText {
                    anchors.centerIn: parent
                    text: sysBtn.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: sysBtn.modelData.active ? Font.DemiBold : Font.Normal
                    color: sysBtn.modelData.active ? Theme.fgOnAccent : Theme.text
                }
                MouseArea {
                    id: sysMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WeatherConfig.applyUnitSystem(sysBtn.modelData.id)
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: unitsCol.implicitHeight + 2 * Theme.spaceXs
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: unitsCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            OptionPills {
                label: "Temperature"
                currentValue: WeatherConfig.tempUnit
                options: [
                    { value: "C", label: "°C" },
                    { value: "F", label: "°F" }
                ]
                onPicked: val => WeatherConfig.setTempUnit(val)
            }

            Separator {}

            OptionPills {
                label: "Wind"
                currentValue: WeatherConfig.windUnit
                options: [
                    { value: "kmh", label: "km/h" },
                    { value: "ms",  label: "m/s" },
                    { value: "mph", label: "mph" },
                    { value: "kn",  label: "kn" }
                ]
                onPicked: val => WeatherConfig.setWindUnit(val)
            }

            Separator {}

            OptionPills {
                label: "Rain"
                currentValue: WeatherConfig.precipUnit
                options: [
                    { value: "mm", label: "mm" },
                    { value: "in", label: "in" }
                ]
                onPicked: val => WeatherConfig.setPrecipUnit(val)
            }

            Separator {}

            OptionPills {
                label: "Pressure"
                currentValue: WeatherConfig.pressureUnit
                options: [
                    { value: "hPa",  label: "hPa" },
                    { value: "inHg", label: "inHg" },
                    { value: "mmHg", label: "mmHg" }
                ]
                onPicked: val => WeatherConfig.setPressureUnit(val)
            }

            Separator {}

            OptionPills {
                label: "Visibility"
                currentValue: WeatherConfig.visibilityUnit
                options: [
                    { value: "km", label: "km" },
                    { value: "mi", label: "mi" }
                ]
                onPicked: val => WeatherConfig.setVisibilityUnit(val)
            }

            Separator {}

            OptionPills {
                label: "Clock"
                currentValue: WeatherConfig.timeFormat
                options: [
                    { value: "24h", label: "24h" },
                    { value: "12h", label: "12h" }
                ]
                onPicked: val => WeatherConfig.setTimeFormat(val)
            }

            Separator {}

            OptionPills {
                label: "Refresh"
                currentValue: WeatherConfig.refreshMinutes
                options: [
                    { value: 5,  label: "5m" },
                    { value: 10, label: "10m" },
                    { value: 15, label: "15m" },
                    { value: 30, label: "30m" },
                    { value: 60, label: "60m" }
                ]
                onPicked: val => WeatherConfig.setRefreshMinutes(val)
            }
        }
    }
}
