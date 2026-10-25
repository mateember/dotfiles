import QtQuick
import qs

// COSMIC toggle switch. `checked` is display-only; clicking emits toggled().
Item {
    id: root

    property bool checked: false
    property bool enabled: true
    signal toggled()

    implicitWidth: 40
    implicitHeight: 22
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.button
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.fgOnAccent : Theme.textStrong
            Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
