import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Touch-friendly segmented pill selector.
// Model entries: { id, label, icon? }
RowLayout {
    id: root

    property var model: []
    property var selectedId: ""
    property bool groupEnabled: true

    signal picked(var id)

    Layout.fillWidth: true
    spacing: 6

    Repeater {
        model: root.model

        delegate: Rectangle {
            id: pill
            required property var modelData
            readonly property bool selected: String(modelData.id) === String(root.selectedId)

            Layout.fillWidth: true
            implicitHeight: 38
            radius: Theme.radiusS
            opacity: root.groupEnabled ? 1.0 : 0.45
            activeFocusOnTab: root.groupEnabled

            color: selected ? Theme.accent
                 : (pillMouse.pressed ? Theme.componentPressed
                  : pillMouse.containsMouse ? Theme.componentHover
                  : Theme.surface1)
            border.width: activeFocus ? 1.5 : 1
            border.color: (selected || activeFocus) ? Theme.accent : Theme.divider

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Keys.onReturnPressed: if (root.groupEnabled) root.picked(pill.modelData.id)
            Keys.onSpacePressed: if (root.groupEnabled) root.picked(pill.modelData.id)

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Icon {
                    visible: Boolean(pill.modelData.icon)
                    icon: pill.modelData.icon || ""
                    size: 16
                    color: pill.selected ? Theme.fgOnAccent : Theme.accent
                }

                StyledText {
                    text: pill.modelData.label || String(pill.modelData.id)
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: pill.selected ? Font.DemiBold : Font.Medium
                    color: pill.selected ? Theme.fgOnAccent : Theme.text
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: pillMouse
                anchors.fill: parent
                enabled: root.groupEnabled
                hoverEnabled: root.groupEnabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.picked(pill.modelData.id)
            }
        }
    }
}
