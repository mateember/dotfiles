import QtQuick
import QtQuick.Layouts
import qs
import qs.components

// Labeled slider row with tabular value readout and optional reset-to-default button.
ColumnLayout {
    id: root

    property string label: ""
    property string subtitle: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real wheelStep: 1
    property string valueText: String(value)
    property real defaultValue: NaN
    property int labelWidth: 150

    signal moved(real value)
    signal resetClicked()

    readonly property bool modifiedFromDefault: !isNaN(defaultValue) && Math.abs(value - defaultValue) > 0.005

    Layout.fillWidth: true
    spacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        ColumnLayout {
            Layout.preferredWidth: root.labelWidth
            Layout.fillWidth: root.labelWidth <= 0
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.text
                elide: Text.ElideRight
            }
            StyledText {
                visible: root.subtitle !== ""
                Layout.fillWidth: true
                text: root.subtitle
                font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                color: Theme.textDim
                elide: Text.ElideRight
            }
        }

        StyledSlider {
            Layout.fillWidth: true
            from: root.from
            to: root.to
            wheelStep: root.wheelStep
            value: root.value
            onMoved: v => root.moved(v)
        }

        StyledText {
            Layout.preferredWidth: 56
            horizontalAlignment: Text.AlignRight
            text: root.valueText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            color: root.modifiedFromDefault ? Theme.accent : Theme.text
        }

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22

            IconButton {
                anchors.fill: parent
                visible: root.modifiedFromDefault
                icon: "restart_alt"
                iconSize: 14
                onClicked: root.resetClicked()
            }
        }
    }
}
