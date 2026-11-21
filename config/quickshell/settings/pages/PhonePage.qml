import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    Component.onCompleted: KdeConnect.refresh()

    SettingsPageHeader {
        icon: "smartphone"
        title: "Phone & Continuity"
        subtitle: "KDE Connect paired devices, battery, ring phone, and quick sharing"

        SettingsActionButton {
            icon: "refresh"
            text: KdeConnect.loading ? "Refreshing…" : "Refresh"
            buttonEnabled: !KdeConnect.loading
            onClicked: KdeConnect.refresh()
        }
        SettingsActionButton {
            icon: "tune"
            text: "KDE Connect"
            onClicked: KdeConnect.openSettings()
        }
    }

    SettingsSection {
        visible: !KdeConnect.available && !KdeConnect.loading
        title: "KDE Connect Unavailable"

        SettingsRow {
            icon: "error_outline"
            title: "kdeconnect-cli not found"
            subtitle: "Install kdePackages.kdeconnect-kde and keep kdeconnect-indicator running"
        }
    }

    SettingsSection {
        visible: KdeConnect.available
        title: "Devices"
        description: KdeConnect.devices.length > 0
            ? "Devices discovered on the local network"
            : "Open the KDE Connect app on your phone on the same Wi-Fi network"

        StyledText {
            visible: KdeConnect.devices.length === 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceS
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textDim
            text: KdeConnect.loading ? "Searching for KDE Connect devices…" : "No phones found yet"
        }

        Repeater {
            model: KdeConnect.devices
            delegate: ColumnLayout {
                id: devBlock
                required property var modelData
                Layout.fillWidth: true
                spacing: 6

                SettingsRow {
                    icon: "smartphone"
                    highlighted: devBlock.modelData.reachable && devBlock.modelData.paired
                    title: devBlock.modelData.name
                    subtitle: {
                        const parts = [];
                        parts.push(devBlock.modelData.paired ? "Paired" : "Not paired");
                        parts.push(devBlock.modelData.reachable ? "Online" : "Offline");
                        if (devBlock.modelData.battery >= 0) {
                            parts.push("Battery " + devBlock.modelData.battery + "%" + (devBlock.modelData.charging ? " (Charging)" : ""));
                        }
                        return parts.join(" · ");
                    }

                    SettingsActionButton {
                        visible: !devBlock.modelData.paired && devBlock.modelData.reachable
                        variant: "accent"
                        icon: "link"
                        text: "Pair"
                        onClicked: KdeConnect.pair(devBlock.modelData.id)
                    }

                    SettingsActionButton {
                        visible: devBlock.modelData.paired
                        variant: "subtle"
                        icon: "link_off"
                        text: "Unpair"
                        onClicked: KdeConnect.unpair(devBlock.modelData.id)
                    }
                }

                // Quick continuity actions when paired & online
                Flow {
                    visible: devBlock.modelData.paired && devBlock.modelData.reachable
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spaceXs
                    Layout.rightMargin: Theme.spaceXs
                    Layout.bottomMargin: 8
                    spacing: Theme.spaceXxs

                    SettingsActionButton {
                        icon: "notifications_active"
                        text: "Ring Phone"
                        onClicked: KdeConnect.ring(devBlock.modelData.id)
                    }
                    SettingsActionButton {
                        icon: "content_paste_go"
                        text: "Send Clipboard"
                        onClicked: KdeConnect.sendClipboard(devBlock.modelData.id)
                    }
                    SettingsActionButton {
                        icon: "upload_file"
                        text: "Send File…"
                        onClicked: KdeConnect.sendFile(devBlock.modelData.id)
                    }
                    SettingsActionButton {
                        icon: "waving_hand"
                        text: "Ping"
                        onClicked: KdeConnect.ping(devBlock.modelData.id)
                    }
                }
            }
        }
    }

    StyledText {
        visible: KdeConnect.lastMessage !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 4
        text: KdeConnect.lastMessage
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.accent
    }
}
