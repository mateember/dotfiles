import QtQuick
import qs
import qs.components
import qs.services

// CPU %, CPU package temperature and used RAM (like COSMIC's minimon applet).
Row {
    id: root

    spacing: Theme.spaceXs
    leftPadding: Theme.spaceXxs
    rightPadding: Theme.spaceXxs

    component Stat: Row {
        property string icon
        property string value
        property color valueColor: Theme.text
        spacing: Theme.spaceXxxs
        height: Theme.barHeight
        Icon { icon: parent.icon; anchors.verticalCenter: parent.verticalCenter }
        StyledText {
            text: parent.value
            color: parent.valueColor
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: Theme.fontSize
            font.features: { "tnum": 1 }
        }
    }

    Stat {
        icon: "memory"
        value: Math.round(SystemStats.cpu * 100) + "%"
    }
    Stat {
        icon: "device_thermostat"
        value: Math.round(SystemStats.tempC) + "°C"
        valueColor: SystemStats.tempC >= 90 ? Theme.destructive : SystemStats.tempC >= 80 ? Theme.warning : Theme.text
    }
    Stat {
        icon: "memory_alt"
        value: SystemStats.memUsedGiB.toFixed(2) + " GB"
    }
}
