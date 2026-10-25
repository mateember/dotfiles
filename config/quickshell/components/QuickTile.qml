import QtQuick
import QtQuick.Layouts
import qs

// Quick settings tile (COSMIC style): icon + title + status line, amber when on.
// Click toggles (clicked); the chevron (when `detail` is true) opens the full menu (detailClicked).
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property bool detail: false
    property bool enabled: true

    signal clicked()
    signal detailClicked()

    Layout.fillWidth: true
    implicitHeight: 56
    radius: Theme.radiusM
    opacity: enabled ? 1 : 0.45
    color: checked ? (mainMouse.containsMouse ? Theme.accentHover : Theme.accent)
                   : (mainMouse.containsMouse ? Theme.componentHover : Theme.component)
    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    readonly property color fg: checked ? Theme.fgOnAccent : Theme.text

    MouseArea {
        id: mainMouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceXs
        anchors.rightMargin: Theme.spaceXxs
        spacing: Theme.spaceXs

        Icon {
            icon: root.icon
            filled: root.checked
            size: 22
            color: root.fg
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.title
                color: root.fg
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: root.fg
                opacity: 0.75
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
        }
        Rectangle {
            visible: root.detail
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            color: detailMouse.containsMouse ? Qt.rgba(0, 0, 0, root.checked ? 0.15 : 0) : "transparent"
            border.width: detailMouse.containsMouse && !root.checked ? 1 : 0
            border.color: Theme.componentDivider
            Icon {
                anchors.centerIn: parent
                icon: "chevron_right"
                size: 18
                color: root.fg
            }
            MouseArea {
                id: detailMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.detailClicked()
            }
        }
    }
}
