import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs
import qs.components
import qs.services
import qs.wallpaper

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
    // Same backdrop as the desktop (from the bar instance); random folder image if the bar didn't answer.
    readonly property var wallpaperInfo: controller.wallpaperInfo ?? ({})
    readonly property string wallpaperMode: String(wallpaperInfo.mode ?? "folder")
    readonly property bool useSceneBackdrop: controller.wallpaperReady && (
        wallpaperMode === "solid"
        || wallpaperMode === "animated"
        || String(wallpaperInfo.overlayEffect ?? "none") !== "none"
        || (wallpaperMode === "image" && (Boolean(wallpaperInfo.singleImageIsApng) || Wallpapers.isApngPath(wallpaperUrl)) && Wallpapers.hasVideoBackend)
    )
    readonly property string wallpaperUrl: !controller.wallpaperReady ? ""
        : (controller.wallpaperFor(screenName) || Wallpapers.urlForScreen(screenName))
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

    // ---- Background Wallpaper ----
    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Item {
        id: wallSource
        anchors.fill: parent
        visible: false
        readonly property bool readyForEffect: stage.useSceneBackdrop ? true : (wallImage.status === Image.Ready)

        Image {
            id: wallImage
            anchors.fill: parent
            visible: !stage.useSceneBackdrop
            source: stage.useSceneBackdrop ? "" : stage.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: false
            // Fixed decode resolution avoids a 1x1->full re-decode on initial Wayland surface configure
            // and decodes much faster since MultiEffect blurs it heavily anyway.
            sourceSize: Qt.size(1280, 800)
        }

        Loader {
            anchors.fill: parent
            active: stage.useSceneBackdrop
            sourceComponent: WallpaperScene {
                readonly property var info: stage.wallpaperInfo
                mode: String(info.mode ?? "solid")
                imageUrl: stage.wallpaperUrl
                fitMode: String(info.fitMode ?? "crop")
                animatedKind: String(info.animatedKind ?? "scene")
                isApngMedia: (mode === "animated" && Boolean(info.animatedFileIsApng))
                          || (mode === "image" && Boolean(info.singleImageIsApng))
                sceneId: String(info.sceneId ?? "aurora")
                paletteBg: info.paletteBg ?? "#111114"
                paletteC1: info.paletteC1 ?? "#FFAD00"
                paletteC2: info.paletteC2 ?? "#E06D1F"
                paletteC3: info.paletteC3 ?? "#4A588A"
                animSpeed: Number(info.animSpeed ?? 1.0)
                animIntensity: Number(info.animIntensity ?? 1.0)
                solidColor: String(info.solidColor ?? "#1B1B1B")
                solidVignette: info.solidVignette !== undefined ? Boolean(info.solidVignette) : true
                overlayEffect: String(info.overlayEffect ?? "none")
                overlayIntensity: Number(info.overlayIntensity ?? 0.85)
                overlaySpeed: Number(info.overlaySpeed ?? 1.0)
                blurAmount: 0
                dimAmount: 0
                paused: stage.controller.sleeping
            }
        }
    }

    MultiEffect {
        anchors.fill: wallSource
        source: wallSource
        visible: wallSource.readyForEffect
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 1.0
        brightness: -0.15
        saturation: -0.05
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.22)
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => {
            passwordInput.forceActiveFocus();
            stage.controller.notifyUserActivity();
            mouse.accepted = false;
        }
    }

    // ---- Clock & Date ----
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

    // ---- Avatar, Greeting & Password Pill ----
    ColumnLayout {
        id: authCol
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(clockGroup.y + clockGroup.height + Theme.spaceL, parent.height * 0.50)
        spacing: Theme.spaceS

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

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: stage.controller.greetingText
            font.pixelSize: 17
            font.weight: Font.Medium
            color: Theme.text
        }

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

    // ---- Bottom Bar: MPRIS & Battery ----
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

        // Active MPRIS track (pause/stop only while locked)
        Rectangle {
            id: mediaPill
            readonly property var player: Media.active
            readonly property string trackTitle: player?.trackTitle ?? ""
            readonly property string trackArtist: player?.trackArtist ?? ""
            readonly property string labelText: trackArtist !== "" ? `${trackArtist} – ${trackTitle}` : trackTitle
            readonly property bool canStopMedia: Media.playing && Boolean(player?.canPause || player?.canControl)

            visible: player !== null && trackTitle !== ""
            implicitWidth: Math.min(440, mediaRow.implicitWidth + Theme.spaceXs + (canStopMedia ? Theme.spaceXxs : Theme.spaceXs))
            implicitHeight: 32
            radius: 16
            color: Qt.rgba(0.11, 0.11, 0.11, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.10)

            RowLayout {
                id: mediaRow
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceXs
                anchors.rightMargin: mediaPill.canStopMedia ? Theme.spaceXxs : Theme.spaceXs
                spacing: Theme.spaceXxs

                Icon {
                    icon: Media.playing ? "music_note" : "pause"
                    size: 16
                    color: Media.playing ? Theme.accent : Theme.textDim
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 340
                    text: mediaPill.labelText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Media.playing ? Theme.text : Theme.textDim
                    elide: Text.ElideRight
                }

                IconButton {
                    visible: mediaPill.canStopMedia
                    implicitWidth: 24
                    implicitHeight: 24
                    icon: "pause"
                    iconSize: 16
                    onClicked: Media.pause()
                }
            }
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: Theme.spaceXxs

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

            Rectangle {
                id: suspendPill
                implicitWidth: suspendRow.implicitWidth + 2 * Theme.spaceXs
                implicitHeight: 32
                radius: 16
                color: suspendMouse.pressed ? Qt.rgba(1, 1, 1, 0.22)
                     : suspendMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                     : Qt.rgba(0.11, 0.11, 0.11, 0.62)
                border.width: 1
                border.color: suspendMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.10)

                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    id: suspendRow
                    anchors.centerIn: parent
                    spacing: 6

                    Icon {
                        icon: "bedtime"
                        size: 16
                        color: suspendMouse.containsMouse ? Theme.accent : Theme.text
                    }

                    StyledText {
                        text: "Suspend"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                }

                MouseArea {
                    id: suspendMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stage.controller.suspendSystem()
                }
            }
        }
    }
}
