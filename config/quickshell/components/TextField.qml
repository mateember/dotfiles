import QtQuick
import qs

// Single-line text input in COSMIC style.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property alias echoMode: input.echoMode
    property alias input: input
    signal accepted()

    function focusInput() { input.forceActiveFocus(); }

    implicitWidth: 200
    implicitHeight: 36
    radius: Theme.radiusS
    color: Theme.component
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : "transparent"

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceXs
        anchors.rightMargin: Theme.spaceXs
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.fgOnAccent
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        clip: true
        onAccepted: root.accepted()
    }

    StyledText {
        anchors.fill: input
        visible: input.text === ""
        text: root.placeholder
        color: Theme.textDim
    }
}
