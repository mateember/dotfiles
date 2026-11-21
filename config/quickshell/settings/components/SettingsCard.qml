import QtQuick
import QtQuick.Layouts
import qs

// Rounded card container for grouping related settings rows.
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: Theme.spaceXs
    property int spacing: Theme.spaceXxs

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 2 * padding
    radius: Theme.radiusM
    color: Theme.component
    border.width: 1
    border.color: Theme.divider

    ColumnLayout {
        id: inner
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.padding
        }
        spacing: root.spacing
    }
}
