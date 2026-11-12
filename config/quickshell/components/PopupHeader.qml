import QtQuick
import QtQuick.Layouts
import qs
import qs.services

// Popup section header: optional back button on the left, title, optional controls on the right.
RowLayout {
    id: root

    property string title: ""
    property bool showBack: root.parent?.popupRoot
        ? Boolean(root.parent.popupRoot.canGoBack)
        : (Popups.current !== "" && WidgetHistory.canGoBack)
    property var backAction: null
    default property alias trailing: trail.data

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    IconButton {
        visible: root.showBack
        icon: "arrow_back"
        implicitWidth: 28
        implicitHeight: 28
        iconSize: 18
        onClicked: {
            if (root.backAction) root.backAction();
            else if (root.parent?.popupRoot) root.parent.popupRoot.back();
            else WidgetHistory.backFromPopup();
        }
    }

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
