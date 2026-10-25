import QtQuick
import qs

// Round icon-only button for use inside popups.
Rectangle {
    id: root

    property string icon: ""
    property bool filled: false
    property real iconSize: Theme.iconSize
    property bool highlighted: false   // amber background (e.g. "on" state)
    property bool enabled: true
    property string tooltip: ""

    signal clicked()

    implicitWidth: 32
    implicitHeight: 32
    radius: height / 2
    color: highlighted ? (mouse.containsMouse ? Theme.accentHover : Theme.accent)
         : mouse.pressed ? Theme.componentPressed
         : mouse.containsMouse ? Theme.componentHover
         : "transparent"
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        filled: root.filled
        size: root.iconSize
        color: root.highlighted ? Theme.fgOnAccent : Theme.text
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
