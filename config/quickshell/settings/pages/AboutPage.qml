import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string configErrorsText: ""
    property bool checkingErrors: false

    Component.onCompleted: {
        SystemManager.refreshAbout();
        Storage.refresh();
    }

    Process {
        id: errCheckProc
        command: ["timeout", "4", "hyprctl", "configerrors"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checkingErrors = false;
                const t = text.trim();
                root.configErrorsText = t === "" ? "No Hyprland config errors detected." : t;
            }
        }
        onExited: root.checkingErrors = false
    }

    SettingsPageHeader {
        icon: "info"
        title: "About & System"
        subtitle: "Hardware specifications, NixOS version, removable storage, and shell maintenance"

        SettingsActionButton {
            icon: "content_copy"
            text: "Copy Info"
            onClicked: SystemManager.copyAboutSummary()
        }
    }

    // ---- Hero OS Card ----
    SettingsCard {
        padding: Theme.spaceS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceS

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: Theme.radiusM
                color: Theme.alpha(Theme.accent, 0.18)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.4)

                Icon {
                    anchors.centerIn: parent
                    icon: "computer"
                    size: 30
                    color: Theme.accent
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: SystemManager.hostname || "NixOS Workstation"
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.Bold
                    color: Theme.textStrong
                }
                StyledText {
                    text: SystemManager.osName + (SystemManager.nixosGeneration ? (" · " + SystemManager.nixosGeneration) : "")
                    color: Theme.accent
                    font.weight: Font.Medium
                }
                StyledText {
                    visible: SystemManager.uptimeText !== ""
                    text: "Uptime: " + SystemManager.uptimeText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
            }
        }
    }

    // ---- Hardware & Software Specs ----
    SettingsSection {
        title: "Hardware & Environment"

        Repeater {
            model: [
                { icon: "memory",          label: "Processor",  val: SystemManager.cpuModel || "…" },
                { icon: "videogame_asset", label: "Graphics",   val: SystemManager.gpuModel || "…" },
                { icon: "sd_storage",      label: "Memory",     val: SystemManager.ramTotal || "…" },
                { icon: "hard_drive",      label: "Root Disk",  val: SystemManager.diskUsage || "…" },
                { icon: "terminal",        label: "Kernel",     val: SystemManager.kernel || "…" },
                { icon: "window",          label: "Hyprland",   val: SystemManager.hyprlandVersion || "…" },
                { icon: "widgets",         label: "Quickshell", val: SystemManager.quickshellVersion || "…" }
            ]
            delegate: SettingsRow {
                required property var modelData
                icon: modelData.icon
                title: modelData.label
                subtitle: modelData.val
            }
        }
    }

    // ---- Removable Drives ----
    SettingsSection {
        title: "Removable Drives"
        description: Storage.count > 0 ? "Mounted USB & SD media" : "No removable drives currently connected"

        Repeater {
            model: Storage.drives
            delegate: SettingsRow {
                required property var modelData
                icon: modelData.tran === "mmc" ? "sd_card" : "usb"
                highlighted: modelData.mounted
                title: modelData.label
                subtitle: modelData.size + " · " + modelData.fstype + (modelData.mounted ? (" · " + modelData.mountpoint) : " · Unmounted")

                SettingsActionButton {
                    visible: modelData.mounted
                    icon: "folder_open"
                    text: "Open"
                    onClicked: Storage.openInFiles(modelData.mountpoint)
                }
                SettingsActionButton {
                    icon: "eject"
                    text: "Eject"
                    onClicked: Storage.eject(modelData.path, modelData.diskPath)
                }
            }
        }
    }

    // ---- Shell Maintenance Tools ----
    SettingsSection {
        title: "Shell & Compositor Maintenance"

        Flow {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            SettingsActionButton {
                icon: "refresh"
                text: "Reload Hyprland"
                onClicked: Quickshell.execDetached(["hyprctl", "reload"])
            }
            SettingsActionButton {
                icon: "restart_alt"
                text: "Restart Shell"
                onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/restart-shell.sh"])
            }
            SettingsActionButton {
                icon: "fact_check"
                text: root.checkingErrors ? "Checking…" : "Check Config Errors"
                onClicked: {
                    root.checkingErrors = true;
                    errCheckProc.running = true;
                }
            }
            SettingsActionButton {
                icon: "terminal"
                text: "View Shell Logs"
                onClicked: Quickshell.execDetached(["kitty", "-e", "sh", "-c", "qs log; read -p 'Press Enter to close…'"])
            }
        }

        StyledText {
            visible: root.configErrorsText !== ""
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            text: root.configErrorsText
            font.family: Theme.monoFamily
            font.pixelSize: Theme.fontSizeSmall
            color: root.configErrorsText.includes("No Hyprland") ? Theme.success : Theme.warning
            wrapMode: Text.Wrap
        }
    }
}
