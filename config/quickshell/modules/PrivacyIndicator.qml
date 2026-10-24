import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Privacy indicator pill on the bar: appears automatically whenever any app is capturing
// your microphone, webcam, or screen via PipeWire / V4L2.
BarButton {
    id: root

    visible: Privacy.active || pop.open
    active: pop.open
    onClicked: pop.toggle()

    Rectangle {
        implicitWidth: pillRow.implicitWidth + 12
        implicitHeight: 22
        radius: 11
        color: Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.22)
        border.color: Theme.warning
        border.width: 1

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 4

            Icon {
                visible: Privacy.micActive
                icon: "mic"
                size: 14
                color: Theme.warning
            }
            Icon {
                visible: Privacy.cameraActive
                icon: "videocam"
                size: 14
                color: Theme.warning
            }
            Icon {
                visible: Privacy.screenActive
                icon: "screen_share"
                size: 14
                color: Theme.warning
            }
        }
    }

    Popup {
        id: pop
        name: "privacy"
        anchorItem: root

        onOpenChanged: if (open) Privacy.refresh()

        PopupHeader {
            title: "Privacy & Active Streams"
        }

        StyledText {
            visible: !Privacy.active
            text: "No apps are currently using your microphone, camera, or screen."
            color: Theme.textDim
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        // Microphone active section
        ColumnLayout {
            visible: Privacy.micActive
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "mic"; color: Theme.warning; size: 18 }
                StyledText {
                    Layout.fillWidth: true
                    text: "Microphone in use"
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    implicitWidth: muteTxt.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: muteMouse.containsMouse ? Theme.componentHover : Theme.button
                    StyledText {
                        id: muteTxt
                        anchors.centerIn: parent
                        text: Audio.micMuted ? "Unmute Mic" : "Mute Mic"
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Audio.toggleMicMute()
                    }
                }
            }
            Repeater {
                model: Privacy.micApps
                delegate: ListItem {
                    required property string modelData
                    icon: "graphic_eq"
                    text: modelData
                    subtext: "Capturing audio input"
                    highlighted: true
                }
            }
        }

        // Camera active section
        ColumnLayout {
            visible: Privacy.cameraActive
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "videocam"; color: Theme.warning; size: 18 }
                StyledText {
                    Layout.fillWidth: true
                    text: "Camera in use"
                    font.weight: Font.DemiBold
                }
            }
            Repeater {
                model: Privacy.cameraApps
                delegate: ListItem {
                    required property string modelData
                    icon: "photo_camera"
                    text: modelData
                    subtext: "Capturing video device"
                    highlighted: true
                }
            }
        }

        // Screen share / recording active section
        ColumnLayout {
            visible: Privacy.screenActive
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "screen_share"; color: Theme.warning; size: 18 }
                StyledText {
                    Layout.fillWidth: true
                    text: "Screen being shared / recorded"
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    visible: Recorder.recording
                    implicitWidth: stopRecTxt.implicitWidth + 16
                    implicitHeight: 24
                    radius: 12
                    color: Theme.danger
                    StyledText {
                        id: stopRecTxt
                        anchors.centerIn: parent
                        text: "Stop Recording"
                        font.pixelSize: Theme.fontSizeSmall
                        color: "#000000"
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Recorder.stopRecording()
                    }
                }
            }
            Repeater {
                model: Privacy.screenApps
                delegate: ListItem {
                    required property string modelData
                    icon: "cast"
                    text: modelData
                    subtext: "Capturing display stream"
                    highlighted: true
                }
            }
        }
    }
}
