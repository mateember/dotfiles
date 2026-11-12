import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Row with a label on the left and selectable pill buttons on the right.
RowLayout {
    id: root

    property string label: ""
    property var options: []      // [{ value, label }]
    property var currentValue: null
    signal picked(var val)

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    StyledText {
        Layout.fillWidth: true
        text: root.label
        elide: Text.ElideRight
    }

    Row {
        spacing: Theme.spaceXxxs
        Repeater {
            model: root.options
            delegate: Rectangle {
                id: pill
                required property var modelData
                readonly property bool active: root.currentValue === modelData.value
                implicitWidth: Math.max(36, lbl.implicitWidth + 16)
                implicitHeight: 26
                radius: 13
                color: active ? Theme.accent
                     : mouse.pressed ? Theme.componentPressed
                     : mouse.containsMouse ? Theme.componentHover
                     : Theme.component
                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                StyledText {
                    id: lbl
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: pill.active ? Font.DemiBold : Font.Normal
                    color: pill.active ? Theme.fgOnAccent : Theme.text
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked(pill.modelData.value)
                }
            }
        }
    }
}
