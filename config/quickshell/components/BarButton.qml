import QtQuick
import qs

// COSMIC-style icon/text button for the bar: transparent until hovered,
// pill-shaped, with icon_button hover/pressed colors.
// Put content inside; it is centered. Emits clicked(button) and scrolled(deltaY).
Item {
    id: root

    default property alias content: inner.data
    property bool active: false          // e.g. popup open
    property int horizontalPadding: Theme.spaceXxs
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed

    signal clicked(int button)
    signal scrolled(real deltaY)

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
        onClicked: e => root.clicked(e.button)
        onWheel: e => stepper.feed(e)
    }
}
