import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Touch- and keyboard-friendly settings row (min height 52px).
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: highlighted ? Theme.accent : Theme.text
    property bool iconFilled: false
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.textDim
    property bool clickable: false
    property bool highlighted: false
    property bool rowEnabled: true
    default property alias trailing: trailingRow.data

    signal clicked(int button)

    Layout.fillWidth: true
    implicitHeight: Math.max(52, mainRow.implicitHeight + 16)
    radius: Theme.radiusS
    opacity: rowEnabled ? 1.0 : 0.45
    color: {
        if (clickable && rowEnabled && mouse.pressed) return Theme.componentPressed;
        if (highlighted) return Theme.alpha(Theme.accent, 0.14);
        if (clickable && rowEnabled && (mouse.containsMouse || activeFocus)) return Theme.componentHover;
        return "transparent";
    }
    border.width: activeFocus ? 1.5 : (highlighted ? 1 : 0)
    border.color: activeFocus ? Theme.accent : Theme.alpha(Theme.accent, 0.4)

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    activeFocusOnTab: clickable && rowEnabled
    Keys.onReturnPressed: if (clickable && rowEnabled) root.clicked(Qt.LeftButton)
    Keys.onEnterPressed: if (clickable && rowEnabled) root.clicked(Qt.LeftButton)
    Keys.onSpacePressed: if (clickable && rowEnabled) root.clicked(Qt.LeftButton)

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.clickable && root.rowEnabled
        hoverEnabled: root.clickable && root.rowEnabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: e => root.clicked(e.button)
    }

    RowLayout {
        id: mainRow
        anchors {
            fill: parent
            leftMargin: Theme.spaceXs
            rightMargin: Theme.spaceXs
            topMargin: 8
            bottomMargin: 8
        }
        spacing: Theme.spaceXs

        Rectangle {
            visible: root.icon !== ""
            implicitWidth: 36
            implicitHeight: 36
            radius: Theme.radiusS
            color: root.highlighted ? Theme.alpha(Theme.accent, 0.22) : Theme.surface1

            Icon {
                anchors.centerIn: parent
                icon: root.icon
                filled: root.iconFilled
                size: 20
                color: root.iconColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.Medium
                color: root.highlighted ? Theme.textStrong : Theme.text
                wrapMode: Text.WordWrap
            }

            StyledText {
                visible: root.subtitle !== ""
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: Theme.fontSizeSmall
                color: root.subtitleColor
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            id: trailingRow
            spacing: Theme.spaceXxs
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
