import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string tab: "defaults"      // "defaults" | "autostart" | "services"
    property string expandedRole: ""
    property string svcFilter: ""

    readonly property var allApps: {
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay)
            .slice()
            .sort((a, b) => a.name.localeCompare(b.name));
    }

    readonly property var filteredServices: {
        const q = root.svcFilter.trim().toLowerCase();
        return SystemManager.userServices.filter(u => {
            if (!q) return true;
            return u.unit.toLowerCase().includes(q)
                || u.description.toLowerCase().includes(q)
                || u.active.toLowerCase().includes(q);
        });
    }

    function appNameForDesktop(desktopFile: string): string {
        if (!desktopFile) return "Not set";
        const clean = desktopFile.replace(/\.desktop$/i, "");
        const match = DesktopEntries.byId(clean) || DesktopEntries.byId(desktopFile);
        return match ? match.name : desktopFile;
    }

    Component.onCompleted: {
        SystemManager.refreshDefaultApps();
        SystemManager.refreshAutostart();
        SystemManager.refreshUserServices();
    }

    SettingsPageHeader {
        icon: "apps"
        title: "Apps, Autostart & Services"
        subtitle: "Manage default applications (xdg-mime), startup entries, and user systemd units"

        SettingsActionButton {
            icon: "refresh"
            text: "Refresh"
            onClicked: {
                SystemManager.refreshDefaultApps();
                SystemManager.refreshAutostart();
                SystemManager.refreshUserServices();
            }
        }
    }

    SettingsPillGroup {
        selectedId: root.tab
        model: [
            { id: "defaults",  label: "Default Apps",   icon: "star" },
            { id: "autostart", label: "Autostart",      icon: "rocket_launch" },
            { id: "services",  label: "User Services",  icon: "memory" }
        ]
        onPicked: id => root.tab = id
    }

    // ---- Default Applications ----
    SettingsSection {
        visible: root.tab === "defaults"
        title: "Default Applications"
        description: "Tap a category to pick its default handler via xdg-mime"

        Repeater {
            model: SystemManager.defaultRoles
            delegate: ColumnLayout {
                id: roleCol
                required property var modelData
                readonly property string curDesktop: SystemManager.defaultAppMap[modelData.id] || ""
                readonly property bool expanded: root.expandedRole === modelData.id

                Layout.fillWidth: true
                spacing: 4

                SettingsRow {
                    icon: roleCol.modelData.icon
                    highlighted: roleCol.expanded
                    clickable: true
                    title: roleCol.modelData.label
                    subtitle: root.appNameForDesktop(roleCol.curDesktop) + "  (" + roleCol.modelData.mime + ")"
                    onClicked: root.expandedRole = roleCol.expanded ? "" : roleCol.modelData.id

                    Icon {
                        icon: roleCol.expanded ? "expand_less" : "expand_more"
                        color: Theme.textDim
                    }
                }

                // Inline searchable picker
                ColumnLayout {
                    visible: roleCol.expanded
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.spaceM
                    Layout.rightMargin: Theme.spaceXs
                    Layout.bottomMargin: 8
                    spacing: 6

                    TextField {
                        id: appSearch
                        Layout.fillWidth: true
                        implicitHeight: 36
                        placeholder: "Filter installed applications…"
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: {
                                const q = appSearch.text.trim().toLowerCase();
                                return root.allApps
                                    .filter(e => !q || e.name.toLowerCase().includes(q) || e.id.toLowerCase().includes(q))
                                    .slice(0, 18);
                            }
                            delegate: SettingsActionButton {
                                required property var modelData
                                active: roleCol.curDesktop.replace(/\.desktop$/, "") === modelData.id.replace(/\.desktop$/, "")
                                text: modelData.name
                                onClicked: {
                                    SystemManager.setDefaultApp(roleCol.modelData.id, modelData.id);
                                    root.expandedRole = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- XDG Autostart ----
    SettingsSection {
        visible: root.tab === "autostart"
        title: "XDG Autostart Entries"
        description: "Toggle startup applications in ~/.config/autostart and /etc/xdg/autostart"

        StyledText {
            visible: SystemManager.autostartApps.length === 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceS
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textDim
            text: SystemManager.autostartLoading ? "Scanning autostart directories…" : "No XDG autostart entries found"
        }

        Repeater {
            model: SystemManager.autostartApps
            delegate: SettingsRow {
                required property var modelData
                icon: modelData.enabled ? "play_circle" : "pause_circle"
                highlighted: modelData.enabled
                title: modelData.name
                subtitle: (modelData.system ? "System · " : "User · ") + modelData.file

                Toggle {
                    checked: modelData.enabled
                    onToggled: SystemManager.setAutostartEnabled(modelData.file, modelData.name, modelData.exec, !modelData.enabled)
                }
            }
        }
    }

    // ---- User Systemd Services ----
    SettingsSection {
        visible: root.tab === "services"
        title: "User Systemd Services (" + root.filteredServices.length + ")"
        description: "Inspect and control systemctl --user services"

        TextField {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            implicitHeight: 38
            placeholder: "Filter user units (e.g. hypridle, pipewire, portal, kwallet)…"
            text: root.svcFilter
            onTextChanged: root.svcFilter = text
        }

        Repeater {
            model: root.filteredServices.slice(0, 40)
            delegate: SettingsRow {
                required property var modelData
                readonly property bool isActive: modelData.active === "active"
                readonly property bool isFailed: modelData.active === "failed"

                icon: isFailed ? "error" : isActive ? "check_circle" : "radio_button_unchecked"
                iconColor: isFailed ? Theme.destructive : isActive ? Theme.success : Theme.textDim
                title: modelData.unit
                subtitle: modelData.active + " (" + modelData.sub + ")" + (modelData.description ? (" · " + modelData.description) : "")

                SettingsActionButton {
                    icon: "article"
                    text: "Logs"
                    onClicked: SystemManager.loadServiceJournal(modelData.unit)
                }
                SettingsActionButton {
                    icon: "restart_alt"
                    text: "Restart"
                    onClicked: SystemManager.controlUserService(modelData.unit, "restart")
                }
                SettingsActionButton {
                    variant: isActive ? "danger" : "accent"
                    text: isActive ? "Stop" : "Start"
                    onClicked: SystemManager.controlUserService(modelData.unit, isActive ? "stop" : "start")
                }
            }
        }
    }

    // Live Journal Tail Preview
    SettingsSection {
        visible: root.tab === "services" && SystemManager.serviceJournalUnit !== ""
        title: "Journal: " + SystemManager.serviceJournalUnit

        Rectangle {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            implicitHeight: Math.min(240, jTxt.implicitHeight + 16)
            radius: Theme.radiusS
            color: Theme.bg
            border.width: 1
            border.color: Theme.divider
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: jTxt.implicitHeight
                clip: true

                StyledText {
                    id: jTxt
                    width: parent.width
                    text: SystemManager.serviceJournalText
                    font.family: Theme.monoFamily
                    font.pixelSize: 11
                    color: Theme.textDim
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}
