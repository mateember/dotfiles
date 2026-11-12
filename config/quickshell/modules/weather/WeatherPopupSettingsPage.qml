import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Modular popup customization: reorder/toggle sections, range options, and detail tiles.
ColumnLayout {
    id: root

    signal goBack()
    property string activeTab: "sections"   // "sections" | "tiles"

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    PopupHeader {
        title: "Popup Modules"
        showBack: true
        backAction: () => root.goBack()
    }

    // ---- Section / Tile Tab Switcher ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        Repeater {
            model: [
                { id: "sections", label: "Sections (" + WeatherConfig.enabledPopupSections.length + ")" },
                { id: "tiles",    label: "Detail Tiles (" + WeatherConfig.enabledDetailTiles.length + ")" }
            ]
            delegate: Rectangle {
                id: tabBtn
                required property var modelData
                readonly property bool active: root.activeTab === modelData.id
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusS
                color: active ? Theme.accent
                     : tabMouse.containsMouse ? Theme.componentHover
                     : Theme.component
                StyledText {
                    anchors.centerIn: parent
                    text: tabBtn.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: tabBtn.active ? Font.DemiBold : Font.Normal
                    color: tabBtn.active ? Theme.fgOnAccent : Theme.text
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = tabBtn.modelData.id
                }
            }
        }
    }

    // ---- Tab 1: Popup Sections + Range Options ----
    ColumnLayout {
        visible: root.activeTab === "sections"
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        ModularOrderList {
            listKind: "sections"
            model: WeatherConfig.popupSections
            maxListHeight: 265
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: secOpts.implicitHeight + 2 * Theme.spaceXs
            radius: Theme.radiusM
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: Theme.divider

            ColumnLayout {
                id: secOpts
                anchors.fill: parent
                anchors.margins: Theme.spaceXs
                spacing: Theme.spaceXs

                OptionPills {
                    label: "Hourly range"
                    currentValue: WeatherConfig.hourlyHours
                    options: [
                        { value: 12, label: "12h" },
                        { value: 24, label: "24h" }
                    ]
                    onPicked: val => WeatherConfig.setHourlyHours(val)
                }

                Separator {}

                OptionPills {
                    label: "Forecast days"
                    currentValue: WeatherConfig.forecastDays
                    options: [
                        { value: 3,  label: "3d" },
                        { value: 5,  label: "5d" },
                        { value: 7,  label: "7d" },
                        { value: 10, label: "10d" }
                    ]
                    onPicked: val => WeatherConfig.setForecastDays(val)
                }

                Separator {}

                OptionPills {
                    label: "Detail tile grid"
                    currentValue: WeatherConfig.detailColumns
                    options: [
                        { value: 2, label: "2 col" },
                        { value: 3, label: "3 col" }
                    ]
                    onPicked: val => WeatherConfig.setDetailColumns(val)
                }
            }
        }
    }

    // ---- Tab 2: Detail Tiles ----
    ModularOrderList {
        visible: root.activeTab === "tiles"
        listKind: "tiles"
        model: WeatherConfig.detailTiles
        maxListHeight: 430
        valueFormatter: id => Weather.ready ? Weather.tileData(id).value : ""
    }
}
