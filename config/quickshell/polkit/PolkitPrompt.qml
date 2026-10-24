import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs
import qs.components

// Polkit authentication agent (password prompts for pkexec, mounting, system settings, ...).
// Registers for this Hyprland session only, so it doesn't fight agents of other sessions.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    LazyLoader {
        active: agent.isActive && agent.flow !== null

        PanelWindow {
            id: win

            readonly property AuthFlow flow: agent.flow
            property bool busy: false

            screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: Theme.shade

            WlrLayershell.namespace: "hcs-polkit"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            function submit() {
                if (!flow || !flow.isResponseRequired) return;
                busy = true;
                flow.submit(password.text);
                password.text = "";
            }

            Connections {
                target: win.flow
                function onAuthenticationFailed() { win.busy = false; shake.restart(); password.focusInput(); }
                function onIsResponseRequiredChanged() { if (win.flow.isResponseRequired) { win.busy = false; password.focusInput(); } }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 420
                height: col.implicitHeight + 2 * Theme.spaceM
                radius: Theme.radiusM
                color: Theme.popupBg
                border.color: Theme.popupBorder
                border.width: 1

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                    NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 100 }
                    NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }

                ColumnLayout {
                    id: col
                    anchors.fill: parent
                    anchors.margins: Theme.spaceM
                    spacing: Theme.spaceS

                    RowLayout {
                        spacing: Theme.spaceS
                        Icon { icon: "shield_lock"; size: 36; color: Theme.accent; filled: true }
                        StyledText {
                            Layout.fillWidth: true
                            text: "Authentication required"
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.DemiBold
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: win.flow?.message ?? ""
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: win.flow?.supplementaryMessage ?? ""
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: (win.flow?.supplementaryIsError ?? false) ? Theme.destructive : Theme.textDim
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: win.flow?.failed ?? false
                        text: "Wrong password, try again."
                        color: Theme.destructive
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    TextField {
                        id: password
                        Layout.fillWidth: true
                        implicitHeight: 40
                        enabled: !win.busy
                        placeholder: (win.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
                        echoMode: (win.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                        onAccepted: win.submit()
                        input.Keys.onEscapePressed: win.flow.cancelAuthenticationRequest()
                        Component.onCompleted: focusInput()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.spaceXxs
                        spacing: Theme.spaceXs
                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: cancelText.implicitWidth + 2 * Theme.spaceS
                            implicitHeight: 36
                            radius: height / 2
                            color: cancelMouse.containsMouse ? Theme.buttonHover : Theme.button
                            StyledText { id: cancelText; anchors.centerIn: parent; text: "Cancel" }
                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.flow.cancelAuthenticationRequest()
                            }
                        }
                        Rectangle {
                            implicitWidth: okText.implicitWidth + 2 * Theme.spaceS
                            implicitHeight: 36
                            radius: height / 2
                            color: okMouse.containsMouse ? Theme.accentHover : Theme.accent
                            opacity: win.busy ? 0.6 : 1
                            StyledText { id: okText; anchors.centerIn: parent; text: win.busy ? "Checking…" : "Authenticate"; color: Theme.fgOnAccent; font.weight: Font.DemiBold }
                            MouseArea {
                                id: okMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
