import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Caffeine: keeps the screen awake (Wayland idle inhibitor, see Bar.qml).
//   - Left click: toggles indefinitely on, or turns off if currently active (timed or indefinite).
//   - Right / middle click: opens dropdown menu to pick a fixed interval (15m, 30m, 1h, 2h, 4h, or Indefinitely).
BarButton {
    id: root

    active: Idle.caffeine || pop.open
    onClicked: button => button === Qt.LeftButton ? Idle.toggle() : pop.toggle()

    RowLayout {
        spacing: 4

        Icon {
            icon: "coffee"
            filled: Idle.caffeine
            color: Idle.caffeine ? Theme.accent : Theme.text
        }

        StyledText {
            visible: Idle.caffeine && Idle.endTimeMs > 0
            text: Idle.shortRemainingText
            font.pixelSize: Theme.barFontSize - 2
            font.features: { "tnum": 1 }
            color: Theme.accent
        }
    }

    Popup {
        id: pop
        name: "caffeine"
        anchorItem: root
        contentWidth: 250

        readonly property var intervals: [
            { minutes: 0,   label: "Indefinitely", icon: "all_inclusive" },
            { minutes: 15,  label: "15 minutes",   icon: "schedule" },
            { minutes: 30,  label: "30 minutes",   icon: "schedule" },
            { minutes: 60,  label: "1 hour",       icon: "schedule" },
            { minutes: 120, label: "2 hours",      icon: "schedule" },
            { minutes: 240, label: "4 hours",      icon: "schedule" }
        ]

        // Header row with status and master toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Icon {
                icon: "coffee"
                filled: Idle.caffeine
                color: Idle.caffeine ? Theme.accent : Theme.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: "Caffeine"
                    font.weight: Font.DemiBold
                }
                StyledText {
                    text: Idle.caffeine
                        ? (Idle.endTimeMs > 0 ? ("Active · " + Idle.remainingText + " left") : "Active indefinitely")
                        : "Off · screen can sleep"
                    font.pixelSize: Theme.fontSizeSmall
                    font.features: { "tnum": 1 }
                    color: Idle.caffeine ? Theme.accent : Theme.textDim
                }
            }

            // Master switch
            Rectangle {
                implicitWidth: 42
                implicitHeight: 24
                radius: 12
                color: Idle.caffeine ? Theme.accent : Theme.component

                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    x: Idle.caffeine ? parent.width - width - 3 : 3
                    color: Idle.caffeine ? Theme.accentText : Theme.text
                    Behavior on x { NumberAnimation { duration: Theme.animFast } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Idle.toggle()
                }
            }
        }

        Separator {}

        Repeater {
            model: pop.intervals

            delegate: ListItem {
                required property var modelData
                readonly property bool isCurrent: Idle.caffeine && Idle.durationMinutes === modelData.minutes
                icon: modelData.icon
                text: modelData.label
                subtext: isCurrent && modelData.minutes > 0 ? Idle.remainingText : ""
                highlighted: isCurrent
                onClicked: Idle.enableFor(modelData.minutes)
            }
        }
    }
}
