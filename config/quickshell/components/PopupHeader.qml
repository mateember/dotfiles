import QtQuick
import QtQuick.Layouts
import qs

// Popup section header: title on the left, optional controls on the right.
RowLayout {
    id: root

    property string title: ""
    default property alias trailing: trail.data

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }
    Row {
        id: trail
        spacing: Theme.spaceXxs
        Layout.alignment: Qt.AlignVCenter
    }
}
