import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Titled settings section wrapping a SettingsCard.
ColumnLayout {
    id: root

    property string title: ""
    property string description: ""
    default property alias content: card.content
    property int cardPadding: Theme.spaceXs
    property int cardSpacing: 2

    Layout.fillWidth: true
    spacing: Theme.spaceXxs

    ColumnLayout {
        visible: root.title !== "" || root.description !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 2

        StyledText {
            visible: root.title !== ""
            Layout.fillWidth: true
            text: root.title
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }

        StyledText {
            visible: root.description !== ""
            Layout.fillWidth: true
            text: root.description
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textDim
            wrapMode: Text.WordWrap
        }
    }

    SettingsCard {
        id: card
        padding: root.cardPadding
        spacing: root.cardSpacing
    }
}
