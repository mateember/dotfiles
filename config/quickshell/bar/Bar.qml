import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.modules
import qs.services

// Top panel for one screen. COSMIC panel look: floating pill with a 4 px gap
// (anchor_gap), 0.66 opacity background, XS size.
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

    // ---- left ----
    RowLayout {
        id: left
        anchors {
            left: parent.left
            leftMargin: Theme.barPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.spaceXxxs

        Workspaces { screen: root.screen }
        ClipboardModule {}
        NightLightModule {}
        Caffeine {}
        Stats {}
    }

    // ---- center ----
    RowLayout {
        id: center
        anchors.centerIn: parent
        spacing: Theme.spaceXxxs

        WeatherModule {}
        Clock {}
    }

    // ---- right ----
    RowLayout {
        id: right
        anchors {
            right: parent.right
            rightMargin: Theme.barPadding
            verticalCenter: parent.verticalCenter
        }
        spacing: 0

        Tray {}
        Display {}
        TilingLayout {}
        MediaModule {}
        Volume {}
        BluetoothModule {}
        NetworkModule {}
        BatteryModule {}
        NotificationsButton {}
        PowerButton {}
    }
}
