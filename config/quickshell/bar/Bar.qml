import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs
import qs.modules
import qs.services

// Top panel for one screen. COSMIC panel look: floating pill with a 4 px gap
// (anchor_gap), 0.66 opacity background, XS size.
// Modules, their visibility and their order come from services/BarConfig.qml.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Theme.panelMargin
        left: Theme.panelMargin
        right: Theme.panelMargin
    }
    implicitHeight: Theme.barHeight
    color: "transparent"

    WlrLayershell.namespace: "hcs-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Caffeine: the inhibitor needs a visible surface, so every bar carries one.
    IdleInhibitor {
        window: root
        enabled: Idle.caffeine
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Math.min(Theme.radiusXl, height / 2)
        color: Theme.panelBg
    }

    Component { id: compWorkspaces; Workspaces { screen: root.screen } }
    Component { id: compClipboard; ClipboardModule {} }
    Component { id: compNightLight; NightLightModule {} }
    Component { id: compCaffeine; Caffeine {} }
    Component { id: compStats; Stats {} }
    Component { id: compWeather; WeatherModule {} }
    Component { id: compClock; Clock {} }
    Component { id: compRecorder; RecorderIndicator {} }
    Component { id: compPrivacy; PrivacyIndicator {} }
    Component { id: compStorage; StorageModule {} }
    Component { id: compTray; Tray {} }
    Component { id: compDisplay; Display {} }
    Component { id: compLayout; TilingLayout {} }
    Component { id: compMedia; MediaModule {} }
    Component { id: compVolume; Volume {} }
    Component { id: compBluetooth; BluetoothModule {} }
    Component { id: compNetwork; NetworkModule {} }
    Component { id: compBattery; BatteryModule {} }
    Component { id: compNotifications; NotificationsButton {} }
    Component { id: compQuickSettings; QuickSettingsButton {} }
    Component { id: compPower; PowerButton {} }

    function moduleComponent(id: string): Component {
        switch (id) {
            case "workspaces": return compWorkspaces;
            case "clipboard": return compClipboard;
            case "nightlight": return compNightLight;
            case "caffeine": return compCaffeine;
            case "stats": return compStats;
            case "weather": return compWeather;
            case "clock": return compClock;
            case "recorder": return compRecorder;
            case "privacy": return compPrivacy;
            case "storage": return compStorage;
            case "tray": return compTray;
            case "display": return compDisplay;
            case "layout": return compLayout;
            case "media": return compMedia;
            case "volume": return compVolume;
            case "bluetooth": return compBluetooth;
            case "network": return compNetwork;
            case "battery": return compBattery;
            case "notifications": return compNotifications;
            case "quicksettings": return compQuickSettings;
            case "power": return compPower;
            default: return null;
        }
    }

    function moduleAvailable(id: string): bool {
        if (id === "nightlight") return NightLight.available;
        if (id === "weather") return Weather.ready;
        if (id === "tray") return SystemTray.items.values.length > 0;
        if (id === "bluetooth") return Bt.available;
        if (id === "battery") return Battery.available;
        return true;
    }

    component BarSection: Repeater {
        delegate: Loader {
            required property string modelData
            readonly property bool barIcons: true
            visible: (BarConfig.enabledMap[modelData] ?? true) && root.moduleAvailable(modelData)
            sourceComponent: root.moduleComponent(modelData)
        }
    }

    // ---- left ----
    RowLayout {
        id: left
        readonly property bool barIcons: true   // icons inside use Theme.barIconSize
        anchors {
            left: parent.left
            leftMargin: Theme.barPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.spaceXxxs

        BarSection { model: BarConfig.leftIds }
    }

    // ---- center ----
    RowLayout {
        id: center
        readonly property bool barIcons: true   // icons inside use Theme.barIconSize
        anchors.centerIn: parent
        spacing: Theme.spaceXxxs

        BarSection { model: BarConfig.centerIds }
    }

    // ---- right ----
    RowLayout {
        id: right
        readonly property bool barIcons: true   // icons inside use Theme.barIconSize
        anchors {
            right: parent.right
            rightMargin: Theme.barPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: 0

        BarSection { model: BarConfig.rightIds }
    }
}
