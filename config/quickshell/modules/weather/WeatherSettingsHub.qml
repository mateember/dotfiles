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
        color: Qt.rgba(1, 1, 1, 0.04)
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
