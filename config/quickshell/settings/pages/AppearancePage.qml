import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "../../bar/theme"
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string tab: "profiles" // "profiles" | "colors" | "surfaces" | "shape" | "type" | "sync"
    property bool quickSaveOpen: false
    property bool showPreview: true

    Component.onCompleted: applySubTab(SettingsState.activeSubTab)

    Connections {
        target: SettingsState
        function onActiveSubTabChanged() {
            if (SettingsState.activePage === "appearance")
                root.applySubTab(SettingsState.activeSubTab);
        }
    }

    function applySubTab(s: string) {
        if (s === "opacity" || s === "surfaces") root.tab = "surfaces";
        else if (s === "colors") root.tab = "colors";
        else if (s === "shape" || s === "bar") root.tab = "shape";
        else if (s === "type" || s === "motion") root.tab = "type";
        else if (s === "sync") root.tab = "sync";
        else if (s === "profiles") root.tab = "profiles";
    }

    SettingsPageHeader {
        icon: "palette"
        title: "Appearance & Theme"
        subtitle: ThemeConfig.activeProfile.name + (ThemeConfig.isDirty ? " · Modified" : "")

        SettingsActionButton {
            visible: !ThemeConfig.activeIsBuiltin && ThemeConfig.isDirty
            variant: "accent"
            icon: "save"
            text: "Save"
            onClicked: ThemeConfig.saveToActiveProfile()
        }
        SettingsActionButton {
            icon: "bookmark_add"
            text: "Save As…"
            active: root.quickSaveOpen
            onClicked: {
                root.quickSaveOpen = !root.quickSaveOpen;
                if (root.quickSaveOpen) Qt.callLater(() => quickNameField.focusInput());
            }
        }
        SettingsActionButton {
            visible: ThemeConfig.isDirty || ThemeConfig.activeProfileId !== "default"
            text: ThemeConfig.isDirty ? "Revert" : "Default"
            onClicked: ThemeConfig.isDirty ? ThemeConfig.revertToActiveProfile() : ThemeConfig.resetToDefault()
        }
        IconButton {
            icon: root.showPreview ? "visibility" : "visibility_off"
            highlighted: root.showPreview
            implicitWidth: 36
            implicitHeight: 36
            onClicked: root.showPreview = !root.showPreview
        }
    }

    // Inline Quick-Save New Profile bar
    SettingsCard {
        visible: root.quickSaveOpen

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXxs

            TextField {
                id: quickNameField
                Layout.fillWidth: true
                implicitHeight: 38
                placeholder: "New profile name (e.g. Late Night, Daylight)"
                onAccepted: {
                    ThemeConfig.createProfile(text.trim(), "");
                    text = "";
                    root.quickSaveOpen = false;
                }
            }
            SettingsActionButton {
                variant: "accent"
                text: "Save Profile"
                onClicked: {
                    ThemeConfig.createProfile(quickNameField.text.trim(), "");
                    quickNameField.text = "";
                    root.quickSaveOpen = false;
                }
            }
        }
    }

    // Collapsible Live Theme Preview Strip
    SettingsCard {
        visible: root.showPreview
        padding: Theme.spaceXxs
        ThemePreviewStrip { Layout.fillWidth: true }
    }

    // Sub-tabs
    SettingsPillGroup {
        selectedId: root.tab
        model: [
            { id: "profiles", label: "Profiles", icon: "style" },
            { id: "colors",   label: "Colors",   icon: "palette" },
            { id: "surfaces", label: "Surfaces", icon: "opacity" },
            { id: "shape",    label: "Shape",    icon: "rounded_corner" },
            { id: "type",     label: "Type",     icon: "text_fields" },
            { id: "sync",     label: "OS Sync",  icon: "sync" }
        ]
        onPicked: id => root.tab = id
    }

    // ---- Existing Theme Pages (reused directly) ----
    ThemeProfilesPage   { visible: root.tab === "profiles"; Layout.fillWidth: true }
    ThemeColorsPage     { visible: root.tab === "colors";   Layout.fillWidth: true }

    // Surfaces + Opacity Presets & Live Test buttons
    ColumnLayout {
        visible: root.tab === "surfaces"
        Layout.fillWidth: true
        spacing: Theme.spaceM

        SettingsSection {
            title: "Opacity Presets & Live Preview"
            description: "Quickly apply opacity profiles and preview Notifications or OSD toasts"

            SettingsPillGroup {
                Layout.margins: Theme.spaceXxs
                selectedId: {
                    if (Math.abs(OpacityConfig.widgetsOpacity - 0.96) < 0.01 && Math.abs(OpacityConfig.barOpacity - 0.66) < 0.01) return "default";
                    if (Math.abs(OpacityConfig.widgetsOpacity - 0.72) < 0.01 && Math.abs(OpacityConfig.barOpacity - 0.50) < 0.01) return "frosted";
                    if (Math.abs(OpacityConfig.widgetsOpacity - 0.45) < 0.01 && Math.abs(OpacityConfig.barOpacity - 0.00) < 0.01) return "clear";
                    if (Math.abs(OpacityConfig.widgetsOpacity - 1.00) < 0.01 && Math.abs(OpacityConfig.barOpacity - 1.00) < 0.01) return "solid";
                    return "";
                }
                model: [
                    { id: "default", label: "Default" },
                    { id: "frosted", label: "Frosted Glass" },
                    { id: "clear",   label: "Clear" },
                    { id: "solid",   label: "Solid" }
                ]
                onPicked: id => {
                    if (id === "default") OpacityConfig.applyPreset(0.96, 0.66, 0.96, 0.96);
                    else if (id === "frosted") OpacityConfig.applyPreset(0.72, 0.50, 0.75, 0.75);
                    else if (id === "clear") OpacityConfig.applyPreset(0.45, 0.00, 0.55, 0.50);
                    else if (id === "solid") OpacityConfig.applyPreset(1.00, 1.00, 1.00, 1.00);
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spaceXxs
                spacing: Theme.spaceXxs

                SettingsActionButton {
                    icon: "notifications"
                    text: "Test Notification"
                    onClicked: Quickshell.execDetached([
                        "notify-send", "-e",
                        "-h", "string:x-canonical-private-synchronous:hcs-opacity-preview",
                        "-a", "Appearance",
                        "Notification opacity: " + Math.round(OpacityConfig.notificationsOpacity * 100) + "%",
                        "Adjust Surfaces sliders below to preview live."
                    ])
                }
                SettingsActionButton {
                    icon: "volume_up"
                    text: "Test OSD Toast"
                    onClicked: Osd.show("opacity", "Toast opacity", OpacityConfig.osdOpacity, 1)
                }
            }
        }

        ThemeSurfacePage { Layout.fillWidth: true }
    }

    ThemeLayoutPage     { visible: root.tab === "shape"; Layout.fillWidth: true }
    ThemeTypographyPage { visible: root.tab === "type";  Layout.fillWidth: true }

    // ---- Full Desktop Theme Sync & Match Wallpaper Accent ----
    ColumnLayout {
        visible: root.tab === "sync"
        Layout.fillWidth: true
        spacing: Theme.spaceM

        SettingsSection {
            title: "Wallpaper Accent Extraction"
            description: "Sample a vibrant accent color from your current wallpaper using native QML Canvas"

            SettingsRow {
                icon: "colorize"
                title: "Match Accent to Current Wallpaper"
                subtitle: ThemeSync.lastExtractedHex !== ""
                    ? ("Last extracted: " + ThemeSync.lastExtractedHex.toUpperCase())
                    : "Reads your active wallpaper image, shader palette, or solid color"

                Rectangle {
                    visible: ThemeSync.lastExtractedHex !== ""
                    width: 24; height: 24; radius: 12
                    color: ThemeSync.lastExtractedHex || "transparent"
                    border.width: 1; border.color: Theme.divider
                }

                SettingsActionButton {
                    variant: "accent"
                    icon: "auto_awesome"
                    text: ThemeSync.extractingAccent ? "Sampling…" : "Match Now"
                    buttonEnabled: !ThemeSync.extractingAccent
                    onClicked: ThemeSync.requestWallpaperAccent()
                }
            }

            SettingsRow {
                icon: "autorenew"
                title: "Auto-Match When Wallpaper Changes"
                subtitle: "Automatically update the accent color whenever the slideshow advances"

                Toggle {
                    checked: ThemeSync.autoWallpaperAccent
                    onToggled: ThemeSync.setAutoWallpaperAccent(!ThemeSync.autoWallpaperAccent)
                }
            }
        }

        SettingsSection {
            title: "Full Desktop Theme Sync"
            description: "Keep Hyprland, GTK, and Qt/KDE apps aligned when switching Theme Profiles"

            SettingsRow {
                icon: "border_style"
                title: "Sync Hyprland Borders & Rounding"
                subtitle: "Updates active/inactive window borders and corner radius live & in hypr-overrides.lua"

                Toggle {
                    checked: ThemeSync.syncHyprland
                    onToggled: ThemeSync.setSyncHyprland(!ThemeSync.syncHyprland)
                }
            }

            SettingsRow {
                icon: "contrast"
                title: "Sync GTK Dark / Light Scheme"
                subtitle: "Updates org.gnome.desktop.interface color-scheme via gsettings"

                Toggle {
                    checked: ThemeSync.syncGtk
                    onToggled: ThemeSync.setSyncGtk(!ThemeSync.syncGtk)
                }
            }

            SettingsRow {
                icon: "widgets"
                title: "Sync Qt6, KDE & Kvantum Theme"
                subtitle: "Regenerates CosmicShell palette with make-cosmic-shell-theme.py"

                Toggle {
                    checked: ThemeSync.syncQt
                    onToggled: ThemeSync.setSyncQt(!ThemeSync.syncQt)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Theme.spaceXs
                spacing: Theme.spaceXs

                SettingsActionButton {
                    variant: "accent"
                    icon: "sync"
                    text: ThemeSync.syncing ? "Syncing…" : "Sync All Now"
                    buttonEnabled: !ThemeSync.syncing
                    onClicked: ThemeSync.forceSyncAll()
                }

                StyledText {
                    Layout.fillWidth: true
                    text: ThemeSync.lastSyncStatus
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }
        }
    }
}
