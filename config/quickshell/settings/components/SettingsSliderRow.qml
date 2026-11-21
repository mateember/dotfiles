import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Touch- and keyboard-friendly slider row with optional -/+ step buttons for precision taps.
ColumnLayout {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string valueText: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0.05
    property bool showStepperButtons: true
    property bool sliderEnabled: true

    signal moved(real newValue)

    Layout.fillWidth: true
    Layout.leftMargin: Theme.spaceXs
    Layout.rightMargin: Theme.spaceXs
    Layout.topMargin: 6
    Layout.bottomMargin: 6
    spacing: 6
    opacity: sliderEnabled ? 1.0 : 0.45

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        Icon {
            visible: root.icon !== ""
            icon: root.icon
            size: 18
            color: Theme.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            StyledText {
                visible: root.subtitle !== ""
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.valueText !== ""
            text: root.valueText
            font.weight: Font.DemiBold
            color: Theme.accent
            font.features: { "tnum": 1 }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        IconButton {
            visible: root.showStepperButtons
            icon: "remove"
            iconSize: 16
            implicitWidth: 32
            implicitHeight: 32
            enabled: root.sliderEnabled && root.value > root.from + 0.0001
            onClicked: root.moved(Math.max(root.from, root.value - root.step))
        }

        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: 32
            from: root.from
            to: root.to
            wheelStep: root.step
            value: root.value
            enabled: root.sliderEnabled
            onMoved: v => root.moved(v)
        }

        IconButton {
            visible: root.showStepperButtons
            icon: "add"
            iconSize: 16
            implicitWidth: 32
            implicitHeight: 32
            enabled: root.sliderEnabled && root.value < root.to - 0.0001
            onClicked: root.moved(Math.min(root.to, root.value + root.step))
        }
    }
}
