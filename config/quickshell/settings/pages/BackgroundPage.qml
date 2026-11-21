import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "../../modules/background"
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property bool showEffects: false
    property string targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    SettingsPageHeader {
        icon: "photo_library"
        title: root.showEffects ? "Background Effects" : "Background & Wallpaper"
        subtitle: "Folder slideshows, single images, live GPU shaders, video loops, and atmospheric overlays"

        SettingsActionButton {
            visible: !root.showEffects && Wallpapers.mode === "folder" && Wallpapers.count > 1
            icon: "skip_next"
            text: "Next"
            onClicked: Wallpapers.next()
        }
        SettingsActionButton {
            icon: "ac_unit"
            text: "Snow"
            active: Wallpapers.overlayEffect === "snow"
            buttonEnabled: Wallpapers.overlayAllowed || Wallpapers.overlayEffect !== "none"
            onClicked: Wallpapers.toggleSnow()
        }
        SettingsActionButton {
            icon: root.showEffects ? "arrow_back" : "tune"
            text: root.showEffects ? "Back to Modes" : "Effects"
            active: root.showEffects
            onClicked: root.showEffects = !root.showEffects
        }
    }

    // Effects view
    SettingsCard {
        visible: root.showEffects
        BackgroundEffectsPage { Layout.fillWidth: true }
    }

    // Main Background controls
    ColumnLayout {
        visible: !root.showEffects
        Layout.fillWidth: true
        spacing: Theme.spaceM

        SettingsCard {
            BackgroundHeroPreview {
                Layout.fillWidth: true
                targetScreen: root.targetScreen
                popupOpen: SettingsState.open && SettingsState.activePage === "background" && !root.showEffects
                onScreenPicked: sn => root.targetScreen = sn
            }
        }

        SettingsPillGroup {
            selectedId: Wallpapers.mode
            model: [
                { id: "folder",   label: "Folder",   icon: "photo_library" },
                { id: "image",    label: "Image",    icon: "image" },
                { id: "animated", label: "Animated", icon: "animation" },
                { id: "solid",    label: "Solid",    icon: "palette" }
            ]
            onPicked: id => {
                if (id === "animated" && !Wallpapers.animatedAllowed) return;
                Wallpapers.setMode(id);
            }
        }

        // Performance mode hint when animated is locked
        SettingsCard {
            visible: !Wallpapers.animatedAllowed
            SettingsRow {
                icon: "bolt"
                title: "Animated & Snow require Performance mode"
                subtitle: "Currently on " + PowerProfile.label + " power profile"
                SettingsActionButton {
                    variant: "accent"
                    text: "Switch to Performance"
                    onClicked: PowerProfile.setMode("performance")
                }
            }
        }

        SettingsCard {
            BackgroundFolderPage {
                visible: Wallpapers.mode === "folder"
                Layout.fillWidth: true
                targetScreen: root.targetScreen
                popupOpen: SettingsState.open
                isCurrentPage: SettingsState.open && SettingsState.activePage === "background" && !root.showEffects && Wallpapers.mode === "folder"
            }

            BackgroundImagePage {
                visible: Wallpapers.mode === "image"
                Layout.fillWidth: true
                popupOpen: SettingsState.open
                isCurrentPage: SettingsState.open && SettingsState.activePage === "background" && !root.showEffects && Wallpapers.mode === "image"
            }

            BackgroundAnimatedPage {
                visible: Wallpapers.mode === "animated"
                Layout.fillWidth: true
                popupOpen: SettingsState.open
                isCurrentPage: SettingsState.open && SettingsState.activePage === "background" && !root.showEffects && Wallpapers.mode === "animated"
                returnAsWindow: true
                returnScreen: root.targetScreen
            }

            BackgroundSolidPage {
                visible: Wallpapers.mode === "solid"
                Layout.fillWidth: true
                returnAsWindow: true
                returnScreen: root.targetScreen
            }
        }
    }
}
