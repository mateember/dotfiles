import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Touch-friendly pill button (36px tall) with accent, subtle, or destructive style.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property string variant: "subtle" // "subtle" | "accent" | "danger"
    property bool buttonEnabled: true
    property bool active: false

    signal clicked()

    implicitWidth: Math.max(40, row.implicitWidth + 24)
    implicitHeight: 36
    radius: Theme.radiusS
    opacity: buttonEnabled ? 1.0 : 0.45
    activeFocusOnTab: buttonEnabled

    readonly property bool isAccent: variant === "accent" || active
    readonly property bool isDanger: variant === "danger"

    color: {
        if (isAccent) {
            if (mouse.pressed) return Theme.accentPressed;
            if (mouse.containsMouse) return Theme.accentHover;
            return Theme.accent;
        }
        if (isDanger) {
            if (mouse.pressed) return Theme.alpha(Theme.destructive, 0.35);
            if (mouse.containsMouse) return Theme.alpha(Theme.destructive, 0.26);
            return Theme.alpha(Theme.destructive, 0.16);
        }
        if (mouse.pressed) return Theme.componentPressed;
        if (mouse.containsMouse) return Theme.componentHover;
        return Theme.primaryComponent;
    }

    border.width: activeFocus ? 1.5 : 1
    border.color: activeFocus ? Theme.accent
                : isAccent ? Theme.accent
                : isDanger ? Theme.alpha(Theme.destructive, 0.5)
                : Theme.divider

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Keys.onReturnPressed: if (buttonEnabled) root.clicked()
    Keys.onEnterPressed: if (buttonEnabled) root.clicked()
    Keys.onSpacePressed: if (buttonEnabled) root.clicked()

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            size: 17
            color: root.isAccent ? Theme.fgOnAccent : root.isDanger ? Theme.destructive : Theme.accent
        }

        StyledText {
            visible: root.text !== ""
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            font.weight: root.isAccent ? Font.DemiBold : Font.Medium
            color: root.isAccent ? Theme.fgOnAccent : root.isDanger ? Theme.destructive : Theme.text
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.buttonEnabled
        hoverEnabled: root.buttonEnabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.clicked()
    }
}
