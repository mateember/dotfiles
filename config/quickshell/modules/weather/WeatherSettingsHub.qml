import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Weather settings hub inside the Weather popup.
ColumnLayout {
    id: root

    signal navigate(string page)
    signal goBack()

    property bool confirmReset: false

    function resetConfirmation() {
        confirmReset = false;
        resetConfirmTimer.stop();
    }

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    Timer {
        id: resetConfirmTimer
        interval: 4000
        onTriggered: root.confirmReset = false
    }

    PopupHeader {
        title: "Weather Settings"
        showBack: true
        backAction: () => {
            root.resetConfirmation();
            root.goBack();
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: navCol.implicitHeight + 8
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: navCol
            anchors.fill: parent
            anchors.margins: 4
            spacing: 0

            ListItem {
                icon: WeatherConfig.autoLocate ? "my_location" : "location_on"
                text: "Location"
                subtext: WeatherConfig.autoLocate
                    ? ("Auto (IP) · " + Weather.displayLocation)
                    : (Weather.displayLocation + " · " + WeatherConfig.latitude.toFixed(2) + "°, " + WeatherConfig.longitude.toFixed(2) + "°")
                onClicked: { root.resetConfirmation(); root.navigate("location"); }
                Icon { icon: "chevron_right"; size: 18; color: Theme.textDim }
            }

            Rectangle { Layout.fillWidth: true; Layout.leftMargin: Theme.spaceXs; Layout.rightMargin: Theme.spaceXs; implicitHeight: 1; color: Theme.divider }

            ListItem {
                icon: "view_agenda"
                text: "Bar Display"
                subtext: WeatherConfig.enabledBarItems.length > 0
                    ? WeatherConfig.enabledBarItems.map(i => i.name).join(", ")
                    : "Icon fallback only"
                onClicked: { root.resetConfirmation(); root.navigate("bar"); }
                Icon { icon: "chevron_right"; size: 18; color: Theme.textDim }
            }

            Rectangle { Layout.fillWidth: true; Layout.leftMargin: Theme.spaceXs; Layout.rightMargin: Theme.spaceXs; implicitHeight: 1; color: Theme.divider }

            ListItem {
                icon: "dashboard_customize"
                text: "Popup Modules"
                subtext: `${WeatherConfig.enabledPopupSections.length} sections · ${WeatherConfig.enabledDetailTiles.length} tiles · ${WeatherConfig.forecastDays}d forecast`
                onClicked: { root.resetConfirmation(); root.navigate("popup"); }
                Icon { icon: "chevron_right"; size: 18; color: Theme.textDim }
            }

            Rectangle { Layout.fillWidth: true; Layout.leftMargin: Theme.spaceXs; Layout.rightMargin: Theme.spaceXs; implicitHeight: 1; color: Theme.divider }

            ListItem {
                icon: "tune"
                text: "Units & Refresh"
                subtext: `°${WeatherConfig.tempUnit} · ${Weather.windUnitLabel()} · ${WeatherConfig.precipUnit} · ${WeatherConfig.pressureUnit} · ${WeatherConfig.refreshMinutes}m`
                onClicked: { root.resetConfirmation(); root.navigate("units"); }
                Icon { icon: "chevron_right"; size: 18; color: Theme.textDim }
            }
        }
    }

    // ---- Data Source Switcher ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: srcCol.implicitHeight + 2 * Theme.spaceXs
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: srcCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon {
                    icon: WeatherConfig.dataSource === "hybrid" ? "sensors" : "public"
                    size: 18
                    color: Theme.accent
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        text: "Data source"
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textDim
                        text: WeatherConfig.dataSource === "openmeteo"
                            ? "Open-Meteo exclusively (global NWP forecast)"
                            : (Weather.activeSource === "hybrid" && Weather.stationName !== ""
                                ? (`HungaroMet · ${Weather.stationName} (${Weather.stationDistanceKm.toFixed(1)} km)`)
                                : (Weather.ready
                                    ? "Hybrid enabled · outside Hungary (using Open-Meteo)"
                                    : "HungaroMet 10m stations (HU) + Open-Meteo"))
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXxs

                Repeater {
                    model: [
                        { id: "hybrid",    label: "HungaroMet + Open-Meteo" },
                        { id: "openmeteo", label: "Open-Meteo only" }
                    ]
                    delegate: Rectangle {
                        id: srcBtn
                        required property var modelData
                        readonly property bool active: WeatherConfig.dataSource === modelData.id
                        Layout.fillWidth: true
                        implicitHeight: 28
                        radius: Theme.radiusS
                        color: active ? Theme.accent
                             : srcMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        StyledText {
                            anchors.centerIn: parent
                            text: srcBtn.modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: srcBtn.active ? Font.DemiBold : Font.Normal
                            color: srcBtn.active ? Theme.fgOnAccent : Theme.text
                        }
                        MouseArea {
                            id: srcMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.resetConfirmation();
                                WeatherConfig.setDataSource(srcBtn.modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }

    ListItem {
        icon: "restart_alt"
        iconColor: root.confirmReset ? Theme.destructive : Theme.text
        text: root.confirmReset ? "Click again to reset" : "Reset weather settings"
        subtext: root.confirmReset
            ? "Restores location, units, bar and popup modules"
            : "Restore defaults from Config.qml"
        subtextColor: root.confirmReset ? Theme.destructive : Theme.textDim
        onClicked: {
            if (root.confirmReset) {
                root.resetConfirmation();
                WeatherConfig.reset();
            } else {
                root.confirmReset = true;
                resetConfirmTimer.restart();
            }
        }
    }
}
