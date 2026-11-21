import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Header strip at the top of each settings page.
RowLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    default property alias actions: actionsRow.data

    Layout.fillWidth: true
    Layout.bottomMargin: Theme.spaceXs
    spacing: Theme.spaceXs

    Rectangle {
        visible: root.icon !== ""
        implicitWidth: 44
        implicitHeight: 44
        radius: Theme.radiusS
        color: Theme.alpha(Theme.accent, 0.18)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.35)

        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: 24
            color: Theme.accent
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.fontSizeTitle
            font.weight: Font.Bold
            color: Theme.textStrong
            elide: Text.ElideRight
        }

        StyledText {
            visible: root.subtitle !== ""
            Layout.fillWidth: true
            text: root.subtitle
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            wrapMode: Text.WordWrap
        }
    }

    RowLayout {
        id: actionsRow
        spacing: Theme.spaceXxs
        Layout.alignment: Qt.AlignVCenter
    }
}
