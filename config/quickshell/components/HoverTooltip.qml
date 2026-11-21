import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// Single floating themed tooltip surface anchored cleanly to whichever BarButton or
// IconButton is currently hovered (via TooltipState). Click-through and non-focusing.
PopupWindow {
    id: root

    readonly property bool active: TooltipState.shown && TooltipState.anchorItem !== null && TooltipState.text !== ""

    visible: active
    color: "transparent"
    mask: Region {}

    anchor.item: TooltipState.anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip

    implicitWidth: Math.min(320, Math.ceil(box.implicitWidth))
    implicitHeight: Math.ceil(box.implicitHeight)

    Rectangle {
        id: box
        anchors.fill: parent
        implicitWidth: col.implicitWidth + 20
        implicitHeight: col.implicitHeight + 12
        radius: Theme.radiusS
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.popupBorder

        opacity: root.active ? 1 : 0
        y: root.active ? 0 : -4
        Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        ColumnLayout {
            id: col
            anchors.centerIn: parent
            width: Math.min(300, Math.max(titleTxt.implicitWidth, subTxt.visible ? subTxt.implicitWidth : 0))
            spacing: 2

            StyledText {
                id: titleTxt
                Layout.fillWidth: true
                text: TooltipState.text
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.textStrong
                elide: Text.ElideRight
            }

            StyledText {
                id: subTxt
                visible: TooltipState.subtext !== ""
                Layout.fillWidth: true
                text: TooltipState.subtext
                font.pixelSize: 11
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }
    }
}
