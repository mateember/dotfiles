import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Tiling layout. Left click toggles scrolling (niri) ↔ dwindle; right click lists all layouts.
BarButton {
    id: root

    readonly property var icons: ({ dwindle: "view_quilt", master: "view_sidebar", scrolling: "view_column", monocle: "crop_square" })

    active: pop.open
    onClicked: button => button === Qt.RightButton ? pop.toggle() : Hypr.toggleLayout()

    Icon { icon: root.icons[Hypr.layout] ?? "dashboard" }

    Popup {
        id: pop
        name: "layout"
        anchorItem: root
        contentWidth: 240

        PopupHeader { title: "Tiling layout" }

        Repeater {
            model: Hypr.layouts
            delegate: ListItem {
                required property string modelData
                icon: root.icons[modelData]
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                highlighted: Hypr.layout === modelData
                onClicked: Hypr.setLayout(modelData)
            }
        }

        Separator {}

        ListItem {
            icon: "view_column"
            text: "Cycle column width"
            subtext: "scrolling only (SUPER R)"
            enabled: Hypr.layout === "scrolling"
            onClicked: Hypr.layoutMsg("colresize +conf")
        }
        ListItem {
            icon: "fit_screen"
            text: "Center column"
            subtext: "scrolling only (SUPER CTRL C)"
            enabled: Hypr.layout === "scrolling"
            onClicked: Hypr.layoutMsg("center")
        }
        ListItem {
            icon: "swap_horiz"
            text: "Toggle split"
            subtext: "dwindle only (SUPER J)"
            enabled: Hypr.layout === "dwindle"
            onClicked: Hypr.layoutMsg("togglesplit")
        }

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            text: "Applies to all workspaces until the Hyprland config is reloaded."
        }
    }
}
