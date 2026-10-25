import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Bar screen recording pill. Only visible while recording is active.
// Left click stops & saves the recording; right/middle click opens the Capture Overlay.
BarButton {
    id: root

    visible: Recorder.recording
    onClicked: button => {
        if (button === Qt.LeftButton) Recorder.stopRecording();
        else Recorder.openOverlay("record");
    }

    RowLayout {
        spacing: 6

        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: Theme.danger

            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.25; duration: 650; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.25; to: 1.0; duration: 650; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            text: "REC " + Recorder.formattedTime
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.danger
            font.features: { "tnum": 1 }
        }
    }
}
