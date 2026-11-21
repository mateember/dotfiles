import QtQuick
import qs
import qs.services

// COSMIC-style icon/text button for the bar: transparent until hovered,
// pill-shaped, with icon_button hover/pressed colors and optional hover tooltip.
// Put content inside; it is centered. Emits clicked(button) and scrolled(deltaY).
Item {
    id: root

    default property alias content: inner.data
    property bool active: false          // e.g. popup open
    property int horizontalPadding: Theme.spaceXxs
    property string tooltip: ""
    property string tooltipSubtext: ""
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed

    signal clicked(int button)
    signal scrolled(real deltaY)

    onTooltipChanged: if (mouse.containsMouse) TooltipState.updateText(root, root.tooltip, root.tooltipSubtext)
    onTooltipSubtextChanged: if (mouse.containsMouse) TooltipState.updateText(root, root.tooltip, root.tooltipSubtext)
    onActiveChanged: if (active) TooltipState.hide(root)
    Component.onDestruction: TooltipState.hide(root)

    implicitHeight: Theme.barHeight - 4
    implicitWidth: Math.max(implicitHeight, inner.childrenRect.width + 2 * horizontalPadding)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: mouse.pressed ? Theme.iconButtonPressed
             : (mouse.containsMouse || root.active) ? Theme.componentHover
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }

    Item {
        id: inner
        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    // scrolled() fires once per mouse notch, also for touchpad scrolling (see ScrollStepper).
    ScrollStepper {
        id: stepper
        onStepped: dir => root.scrolled(dir * 120)
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.tooltip !== "" && !root.active) TooltipState.requestShow(root, root.tooltip, root.tooltipSubtext)
        onExited: TooltipState.hide(root)
        onPressed: TooltipState.hide(root)
        onClicked: e => root.clicked(e.button)
        onWheel: e => stepper.feed(e)
    }
}
