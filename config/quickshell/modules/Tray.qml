import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.components

// StatusNotifierItem tray. Left click activates, right click (or menu-only items) opens the menu,
// middle click is the secondary action, scroll is forwarded to the app.
Row {
    id: root

    spacing: 0
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: BarButton {
            id: btn
            required property SystemTrayItem modelData

            onClicked: button => {
                if (button === Qt.RightButton || modelData.onlyMenu) {
                    if (modelData.hasMenu) menu.open();
                } else if (button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else {
                    modelData.activate();
                }
            }
            onScrolled: delta => modelData.scroll(delta, false)

            IconImage {
                implicitSize: Theme.iconSize
                source: btn.modelData.icon
                asynchronous: true
            }

            QsMenuAnchor {
                id: menu
                menu: btn.modelData.menu
                anchor.item: btn
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
                anchor.rect.width: btn.width
                anchor.rect.height: btn.height + Theme.popupGap
            }
        }
    }
}
