import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services

// Visual UI for one monitor's lock surface (used inside WlSessionLockSurface in LockScreen.qml).
Item {
    id: stage

    required property var controller
    property string screenName: ""

    focus: true

    readonly property bool isPrimaryScreen: {
        const focused = Hyprland.focusedMonitor?.name ?? "";
        if (focused !== "") return screenName === focused;
        return screenName === (Quickshell.screens[0]?.name ?? "");
    }
    readonly property string wallpaperUrl: Wallpapers.urlForScreen(screenName)
    property bool showPassword: false

    opacity: 0
    Component.onCompleted: {
        fadeIn.start();
        if (stage.isPrimaryScreen) passwordInput.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (!passwordInput.activeFocus) {
            passwordInput.forceActiveFocus();
            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape) {
                passwordInput.insert(passwordInput.cursorPosition, event.text);
                stage.controller.clearError();
                stage.controller.notifyUserActivity();
                event.accepted = true;
            }
        }
    }

    NumberAnimation on opacity {
        id: fadeIn
        from: 0
        to: 1
        duration: Theme.animNormal
        easing.type: Easing.OutCubic
    }

    Connections {
        target: stage.controller
        function onClearInputs(): void {
            passwordInput.text = "";
            stage.showPassword = false;
        }
        function onAuthFailed(): void {
            shake.restart();
            passwordInput.forceActiveFocus();
        }
    }

    // ---- Blurred Bing Wallpaper Background ----
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Image {
        id: wallSource
        anchors.fill: parent
        source: stage.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
        // Fixed decode resolution avoids a 1x1->full re-decode on initial Wayland surface configure
        // and decodes much faster since MultiEffect blurs it heavily anyway.
        sourceSize: Qt.size(1280, 800)
        visible: false
    }

    MultiEffect {
        anchors.fill: wallSource
        source: wallSource
        visible: wallSource.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        brightness: -0.15
        saturation: -0.05
    }

    // Subtle dark scrim for crisp contrast on bright wallpapers
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
    }

    // Clicking anywhere on the surface focuses its password input
    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            passwordInput.forceActiveFocus();
            stage.controller.notifyUserActivity();
            mouse.accepted = false;
        }
    }

    // ---- Upper Block: Clock & Date ----
    Item {
        id: clockGroup
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(Theme.spaceXl, parent.height * 0.17)
        width: Math.max(clockRow.implicitWidth, dateLabel.implicitWidth) + Theme.spaceXl
        height: clockCol.implicitHeight

        ColumnLayout {
            id: clockCol
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.spaceXxs

            Row {
                id: clockRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 0

                StyledText {
                    id: hoursText
                    text: Time.format("HH")
                    font.pixelSize: 104
                    font.weight: Font.Bold
                    color: Theme.text
                }
                Item {
                    width: colonText.implicitWidth
                    height: hoursText.implicitHeight

                    StyledText {
                        id: colonText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -7
                        text: ":"
                        font.pixelSize: 104
                        font.weight: Font.Light
                        color: Theme.accent
                    }
                }
                StyledText {
                    text: Time.format("mm")
                    font.pixelSize: 104
                    font.weight: Font.Light
                    color: Theme.text
                }
            }

            StyledText {
                id: dateLabel
                Layout.alignment: Qt.AlignHCenter
                text: Time.format("dddd, MMMM d")
                font.pixelSize: 19
                font.weight: Font.Normal
                color: Theme.text
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.55
            shadowVerticalOffset: 2
        }
    }

    // ---- Center/Lower Block: Avatar, Greeting & Password Pill ----
    ColumnLayout {
        id: authCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(clockGroup.y + clockGroup.height + Theme.spaceL, parent.height * 0.50)
        spacing: Theme.spaceS

        // Circular amber user initial avatar
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 64
            height: 64
            radius: 32
            color: Theme.accent

            StyledText {
                anchors.centerIn: parent
                text: stage.controller.userInitial
                font.pixelSize: 26
                font.weight: Font.DemiBold
                color: Theme.fgOnAccent
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.38)
                shadowBlur: 0.45
                shadowVerticalOffset: 2
            }
        }

        // Time-of-day greeting ("Good evening, Mate")
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: stage.controller.greetingText
            font.pixelSize: 17
            font.weight: Font.Medium
            color: Theme.text
        }

        // Password Pill Container (shakes on failed authentication)
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spaceXxxs
            width: 316
            height: 46

            Rectangle {
                id: inputPill
                anchors.centerIn: parent
                width: 316
                height: 46
                radius: 23
                color: Qt.rgba(0.16, 0.16, 0.16, 0.88)
                border.width: 2
                border.color: stage.controller.errorText !== "" ? Theme.destructive
                            : (stage.controller.faceScanning || stage.controller.submittingPassword || passwordInput.text.length > 0) ? Theme.accent
                            : Theme.componentDivider

                Behavior on border.color { ColorAnimation { duration: Theme.animNormal } }

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: inputPill; property: "anchors.horizontalCenterOffset"; to: -10; duration: 45 }
                    NumberAnimation { target: inputPill; property: "anchors.horizontalCenterOffset"; to: 10; duration: 90 }
                    NumberAnimation { target: inputPill; property: "anchors.horizontalCenterOffset"; to: 0; duration: 45 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceS
                    anchors.rightMargin: Theme.spaceXxs
                    spacing: Theme.spaceXxs

                    // Left state icon (Face scan pulse / Spinner / Lock)
                    Icon {
                        id: stateIcon
                        icon: stage.controller.submittingPassword ? "hourglass_top"
                            : stage.controller.faceScanning ? "face"
                            : "lock"
                        size: 19
                        color: (stage.controller.faceScanning || stage.controller.submittingPassword) ? Theme.accent : Theme.textDim

                        SequentialAnimation on opacity {
                            running: stage.controller.faceScanning
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.4; duration: 700; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.4; to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                            onRunningChanged: if (!running) stateIcon.opacity = 1.0
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.fgOnAccent
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            echoMode: stage.showPassword ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            clip: true
                            readOnly: stage.controller.submittingPassword

                            onTextEdited: {
                                stage.controller.clearError();
                                stage.controller.notifyUserActivity();
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    event.accepted = true;
                                    if (!event.isAutoRepeat && !stage.controller.submittingPassword) {
                                        stage.controller.submitPassword(passwordInput.text);
                                    }
                                } else if (event.key === Qt.Key_Escape) {
                                    event.accepted = true;
                                    if (stage.controller.submittingPassword) {
                                        stage.controller.cancelSubmit();
                                    } else if (passwordInput.text.length > 0) {
                                        passwordInput.text = "";
                                        stage.showPassword = false;
                                    }
                                    stage.controller.clearError();
                                }
                            }
                        }

                        StyledText {
                            anchors.fill: parent
                            visible: passwordInput.text.length === 0
                            text: stage.controller.sleeping ? "Locked"
                                : stage.controller.submittingPassword ? "Unlocking…"
                                : stage.controller.faceScanning ? "Scanning face…"
                                : "Enter password"
                            color: stage.controller.faceScanning ? Theme.text : Theme.textDim
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                        }
                    }

                    // Show / hide typed password toggle
                    IconButton {
                        visible: passwordInput.text.length > 0 && !stage.controller.submittingPassword
                        implicitWidth: 32
                        implicitHeight: 32
                        icon: stage.showPassword ? "visibility_off" : "visibility"
                        iconSize: 17
                        onClicked: {
                            stage.showPassword = !stage.showPassword;
                            passwordInput.forceActiveFocus();
                        }
                    }

                    // Submit arrow when password typed, or Retry Face Unlock button when Howdy is available
                    IconButton {
                        visible: passwordInput.text.length > 0 || (stage.controller.howdyAvailable && !stage.controller.faceScanning)
                        enabled: !stage.controller.submittingPassword
                        implicitWidth: 34
                        implicitHeight: 34
                        highlighted: passwordInput.text.length > 0
                        icon: passwordInput.text.length > 0 ? "arrow_forward" : "face"
                        iconSize: 18
                        onClicked: {
                            if (passwordInput.text.length > 0) {
                                stage.controller.submitPassword(passwordInput.text);
                            } else {
                                stage.controller.retryFaceScan();
                                passwordInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }

        // Error / Status subtitle under the pill
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 20
            text: stage.controller.errorText !== "" ? stage.controller.errorText
                : (stage.controller.faceScanning && passwordInput.text.length === 0) ? "Looking for you · or type password"
                : ""
            opacity: text !== "" ? 1.0 : 0.0
            color: stage.controller.errorText !== "" ? Theme.destructive : Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        }
    }

    // ---- Bottom Status Bar: MPRIS Now Playing (left) & Battery (right) ----
    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: Theme.spaceM
            rightMargin: Theme.spaceM
            bottomMargin: Theme.spaceM
        }
        spacing: Theme.spaceM

        // Bottom-left: Active MPRIS track + quick playback controls
        Rectangle {
            id: mediaPill
            readonly property var player: Media.active
            readonly property string trackTitle: player?.trackTitle ?? ""
            readonly property string trackArtist: player?.trackArtist ?? ""
            readonly property string labelText: trackArtist !== "" ? `${trackArtist} – ${trackTitle}` : trackTitle

            visible: player !== null && trackTitle !== ""
            implicitWidth: Math.min(440, mediaRow.implicitWidth + 2 * Theme.spaceXs)
            implicitHeight: 32
            radius: 16
            color: Qt.rgba(0.11, 0.11, 0.11, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            RowLayout {
                id: mediaRow
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceXs
                anchors.rightMargin: Theme.spaceXxs
                spacing: Theme.spaceXxs

                Icon {
                    icon: Media.playing ? "music_note" : "pause"
                    size: 16
                    color: Theme.accent
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 320
                    text: mediaPill.labelText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                    elide: Text.ElideRight
                }

                IconButton {
                    visible: Media.active?.canTogglePlaying ?? false
                    implicitWidth: 24
                    implicitHeight: 24
                    icon: Media.playing ? "pause" : "play_arrow"
                    iconSize: 16
                    onClicked: Media.togglePlaying()
                }

                IconButton {
                    visible: Media.active?.canGoNext ?? false
                    implicitWidth: 24
                    implicitHeight: 24
                    icon: "skip_next"
                    iconSize: 16
                    onClicked: Media.next()
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Bottom-right: Battery icon & percentage
        Rectangle {
            visible: Battery.available
            implicitWidth: batRow.implicitWidth + 2 * Theme.spaceXs
            implicitHeight: 32
            radius: 16
            color: Qt.rgba(0.11, 0.11, 0.11, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            RowLayout {
                id: batRow
                anchors.centerIn: parent
                spacing: 6

                Icon {
                    icon: Battery.icon
                    size: 16
                    color: Battery.charging ? Theme.success
                         : Battery.percent < 0.20 ? Theme.warning
                         : Theme.textDim
                }

                StyledText {
                    text: Math.round(Battery.percent * 100) + "%"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
            }
        }
    }
}
