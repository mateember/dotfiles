import QtQuick
import QtQuick.Layouts
import qs

// A row in a popup list: icon, title, optional subtitle, optional trailing items.
// highlighted = selected/active (amber text, like COSMIC's selected_text).
Rectangle {
    id: root

    property string icon: ""
    property bool iconFilled: false
    property string text: ""
    property string subtext: ""
    property bool highlighted: false
    property bool enabled: true
    default property alias trailing: trail.data

    signal clicked(int button)

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + 2 * Theme.spaceXs
    implicitHeight: subtext !== "" ? 48 : 38
    radius: Theme.radiusS
    color: mouse.pressed ? Theme.componentPressed
         : mouse.containsMouse && enabled ? Theme.componentHover
         : "transparent"
    opacity: enabled ? 1 : 0.5
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => root.clicked(e.button)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceXs
        anchors.rightMargin: Theme.spaceXs
        spacing: Theme.spaceXs

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            filled: root.iconFilled
            color: root.highlighted ? Theme.accent : Theme.text
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.text
                elide: Text.ElideRight
                color: root.highlighted ? Theme.accent : Theme.text
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.subtext !== ""
                text: root.subtext
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
        }

        Row {
            id: trail
            spacing: Theme.spaceXxxs
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
