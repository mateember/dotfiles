import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
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
    readonly property bool wallpaperSettled: stage.useSceneBackdrop
        || (controller.wallpaperReady && (stage.wallpaperUrl === "" || wallImage.status === Image.Ready || wallImage.status === Image.Error))
    property bool showPassword: false

    opacity: 0
    Component.onCompleted: {
        fadeIn.start();
        if (stage.isPrimaryScreen) passwordInput.forceActiveFocus();
    }

    Keys.onPressed: event => {
        if (!passwordInput.activeFocus) {
            passwordInput.forceActiveFocus();
            const hasMod = (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== 0;
            if (!hasMod && event.text && event.text.length > 0
                && !/[\x00-\x1f\x7f]/.test(event.text)
                && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape) {
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

            // Privacy-safe glanceability chips: ONLY upcoming event time (never title) & unread count
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.spaceXxs
                spacing: Theme.spaceXxs
                visible: nextEventChip.visible || notifCountChip.visible

                Rectangle {
                    id: nextEventChip
                    readonly property var ev: CalendarEvents.nextUp
                    readonly property string whenText: {
                        if (!ev) return "";
                        const now = Time.date;
                        const hm = d => Time.locale.toString(d, "HH:mm");
                        const sameDay = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
                        if (ev.start <= now && ev.kind !== "task") return "Event until " + hm(ev.end);
                        const mins = Math.round((ev.start - now) / 60000);
                        if (mins < 60) return "Next event in " + Math.max(mins, 1) + " min";
                        if (sameDay(ev.start, now)) return "Next event at " + hm(ev.start);
                        const tom = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
                        if (sameDay(ev.start, tom)) return "Next event tomorrow " + hm(ev.start);
                        return "Next event " + Time.locale.toString(ev.start, "ddd, MMM d") + " " + hm(ev.start);
                    }
                    visible: LockConfig.showNextEvent && ev !== null && whenText !== ""
                    implicitWidth: evChipRow.implicitWidth + 18
                    implicitHeight: 28
                    radius: 14
                    color: Qt.rgba(0.11, 0.11, 0.11, 0.56)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    RowLayout {
                        id: evChipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { icon: "event_upcoming"; size: 15; color: Theme.accent }
                        StyledText { text: nextEventChip.whenText; font.pixelSize: Theme.fontSizeSmall; color: Theme.text }
                    }
                }

                Rectangle {
                    id: notifCountChip
                    visible: LockConfig.showNotifCount && stage.controller.unreadNotifCount > 0
                    implicitWidth: ncRow.implicitWidth + 18
                    implicitHeight: 28
                    radius: 14
                    color: Qt.rgba(0.11, 0.11, 0.11, 0.56)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.12)

                    RowLayout {
                        id: ncRow
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { icon: "notifications_unread"; size: 15; color: Theme.accent }
                        StyledText {
                            text: stage.controller.unreadNotifCount + (stage.controller.unreadNotifCount === 1 ? " notification" : " notifications")
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }
                    }
                }
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
            id: avatarBadge
            property bool useFallback: false
            readonly property string targetSource: {
                if (!stage.wallpaperSettled || !LockConfig.avatarPath) return "";
                return useFallback ? LockConfig.avatarFallbackUrl : LockConfig.avatarThumbUrl;
            }
            Connections {
                target: LockConfig
                function onAvatarPathChanged() { avatarBadge.useFallback = false; }
                function onAvatarThumbUrlChanged() { avatarBadge.useFallback = false; }
            }

            Layout.alignment: Qt.AlignHCenter
            width: 68
            height: 68
            radius: 34
            color: Theme.accent

            ClippingRectangle {
                anchors.fill: parent
                radius: 34
                color: "transparent"
                visible: avatarImg.status === Image.Ready
                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: avatarBadge.targetSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    cache: false
                    sourceSize: Qt.size(136, 136)
                    onStatusChanged: {
                        if (status === Image.Error && !avatarBadge.useFallback && LockConfig.avatarFallbackUrl !== "") {
                            avatarBadge.useFallback = true;
                        }
                    }
                }
            }

            StyledText {
                visible: avatarImg.status !== Image.Ready
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
                            selectByMouse: false
                            readOnly: stage.controller.submittingPassword

                            onActiveFocusChanged: if (!activeFocus) stage.showPassword = false

                            onTextEdited: {
                                stage.controller.clearError();
                                stage.controller.notifyUserActivity();
                            }

                            Keys.onPressed: event => {
                                // Block clipboard paste/copy/cut on the lock screen to prevent
                                // clipboard exfiltration while locked or leaking the password to cliphist.
                                const isCtrlShiftV = (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_V;
                                const isShiftIns = (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_Insert;
                                if (event.matches(StandardKey.Paste)
                                    || event.matches(StandardKey.Copy)
                                    || event.matches(StandardKey.Cut)
                                    || isCtrlShiftV
                                    || isShiftIns) {
                                    event.accepted = true;
                                    return;
                                }
                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    event.accepted = true;
                                    if (!event.isAutoRepeat && !stage.controller.submittingPassword) {
                                        stage.controller.submitPassword(passwordInput.text);
                                    }
                                } else if (event.key === Qt.Key_Escape) {
                                    event.accepted = true;
                                    if (stage.controller.submittingPassword) {
                                        stage.controller.cancelSubmit();
                                    } else {
                                        stage.controller.clearInputs();
                                    }
                                    stage.controller.clearError();
                                }
                            }

                            // Swallow middle-click primary-selection paste without blocking left clicks.
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.MiddleButton
                                onPressed: mouse => mouse.accepted = true
                            }
                        }

                        Timer {
                            id: showPasswordTimer
                            interval: 5000
                            repeat: false
                            running: stage.showPassword
                            onTriggered: stage.showPassword = false
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
                        visible: passwordInput.text.length > 0 || (stage.controller.effectiveHowdy && !stage.controller.faceScanning)
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

        // Caps Lock & Keyboard Layout badges
        RowLayout {
            visible: LockConfig.showCapsAndLayout && (HyprSettings.capsLockOn || HyprSettings.activeKeymap !== "")
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spaceXxs

            Rectangle {
                visible: HyprSettings.capsLockOn
                implicitWidth: capsRow.implicitWidth + 16
                implicitHeight: 26
                radius: 13
                color: Theme.alpha(Theme.warning, 0.22)
                border.width: 1
                border.color: Theme.warning
                RowLayout {
                    id: capsRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon { icon: "keyboard_capslock"; size: 15; color: Theme.warning }
                    StyledText { text: "Caps Lock is ON"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.warning }
                }
            }

            Rectangle {
                visible: HyprSettings.activeKeymap !== ""
                implicitWidth: kbRow.implicitWidth + 16
                implicitHeight: 26
                radius: 13
                color: Qt.rgba(0.11, 0.11, 0.11, 0.62)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                RowLayout {
                    id: kbRow
                    anchors.centerIn: parent
                    spacing: 4
                    Icon { icon: "language"; size: 14; color: Theme.textDim }
                    StyledText { text: HyprSettings.activeKeymap; font.pixelSize: Theme.fontSizeSmall; color: Theme.textDim }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: HyprSettings.switchNextKeyboardLayout()
                }
            }
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
                visible: LockConfig.showWeather && Weather.ready
                implicitWidth: lockWxRow.implicitWidth + 2 * Theme.spaceXs
                implicitHeight: 32
                radius: 16
                color: Qt.rgba(0.11, 0.11, 0.11, 0.62)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)
                RowLayout {
                    id: lockWxRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { icon: Weather.icon || "partly_cloudy_day"; size: 16; color: Theme.accent }
                    StyledText { text: Weather.formatTemp(Weather.tempC, true) + (Weather.description ? (" · " + Weather.description) : ""); font.pixelSize: Theme.fontSizeSmall; color: Theme.text }
                }
            }

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

            Rectangle {
                id: rebootPill
                visible: LockConfig.showPowerActions
                property bool armed: false
                implicitWidth: rebootRow.implicitWidth + 2 * Theme.spaceXs
                implicitHeight: 32
                radius: 16
                color: armed ? Theme.alpha(Theme.warning, 0.30)
                     : rebootMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                     : Qt.rgba(0.11, 0.11, 0.11, 0.62)
                border.width: 1
                border.color: armed ? Theme.warning : Qt.rgba(1, 1, 1, 0.10)
                RowLayout {
                    id: rebootRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { icon: "restart_alt"; size: 16; color: rebootPill.armed ? Theme.warning : Theme.text }
                    StyledText { text: rebootPill.armed ? "Confirm Reboot" : "Reboot"; font.pixelSize: Theme.fontSizeSmall; color: Theme.text }
                }
                Timer {
                    id: rebootDisarmTimer
                    interval: 5000
                    repeat: false
                    running: rebootPill.armed
                    onTriggered: rebootPill.armed = false
                }
                MouseArea {
                    id: rebootMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rebootPill.armed) Quickshell.execDetached(["systemctl", "reboot"]);
                        else { poweroffPill.armed = false; rebootPill.armed = true; }
                    }
                }
            }

            Rectangle {
                id: poweroffPill
                visible: LockConfig.showPowerActions
                property bool armed: false
                implicitWidth: poRow.implicitWidth + 2 * Theme.spaceXs
                implicitHeight: 32
                radius: 16
                color: armed ? Theme.alpha(Theme.destructive, 0.30)
                     : poMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14)
                     : Qt.rgba(0.11, 0.11, 0.11, 0.62)
                border.width: 1
                border.color: armed ? Theme.destructive : Qt.rgba(1, 1, 1, 0.10)
                RowLayout {
                    id: poRow
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { icon: "power_settings_new"; size: 16; color: poweroffPill.armed ? Theme.destructive : Theme.text }
                    StyledText { text: poweroffPill.armed ? "Confirm Shut Down" : "Shut Down"; font.pixelSize: Theme.fontSizeSmall; color: Theme.text }
                }
                Timer {
                    id: poweroffDisarmTimer
                    interval: 5000
                    repeat: false
                    running: poweroffPill.armed
                    onTriggered: poweroffPill.armed = false
                }
                MouseArea {
                    id: poMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (poweroffPill.armed) Quickshell.execDetached(["systemctl", "poweroff"]);
                        else { rebootPill.armed = false; poweroffPill.armed = true; }
                    }
                }
            }
        }
    }
}
