import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    Component.onCompleted: {
        Hypr.refreshLayout();
        HyprSettings.refreshLiveOptions();
    }

    SettingsPageHeader {
        icon: "view_column"
        title: "Desktop & Windowing"
        subtitle: "Hyprland layout, spacing, borders, blur, and animations (persisted in hypr-overrides.lua)"

        SettingsActionButton {
            icon: "restart_alt"
            text: "Reset Overrides"
            onClicked: HyprSettings.resetVisualOverrides()
        }
    }

    // ---- Window Layout ----
    SettingsSection {
        title: "Tiling Layout"
        description: "Switch between scrolling columns, dwindle splits, master-stack, or monocle"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            SettingsPillGroup {
                selectedId: Hypr.layout
                model: [
                    { id: "scrolling", label: "Scrolling", icon: "view_column" },
                    { id: "dwindle",   label: "Dwindle",   icon: "view_quilt" },
                    { id: "master",    label: "Master",    icon: "view_sidebar" },
                    { id: "monocle",   label: "Monocle",   icon: "crop_square" }
                ]
                onPicked: id => HyprSettings.setDesktopLayout(id)
            }
        }
    }

    // ---- Window Geometry & Borders ----
    SettingsSection {
        title: "Gaps, Borders & Corners"

        SettingsSliderRow {
            icon: "space_bar"
            title: "Inner Gaps"
            valueText: HyprSettings.gapsIn + " px"
            from: 0
            to: 24
            step: 1
            value: HyprSettings.gapsIn
            onMoved: v => HyprSettings.setGapsIn(Math.round(v))
        }

        SettingsSliderRow {
            icon: "padding"
            title: "Outer Gaps"
            valueText: HyprSettings.gapsOut + " px"
            from: 0
            to: 32
            step: 1
            value: HyprSettings.gapsOut
            onMoved: v => HyprSettings.setGapsOut(Math.round(v))
        }

        SettingsSliderRow {
            icon: "border_outer"
            title: "Window Border Width"
            valueText: HyprSettings.borderSize + " px"
            from: 0
            to: 6
            step: 1
            value: HyprSettings.borderSize
            onMoved: v => HyprSettings.setBorderSize(Math.round(v))
        }

        SettingsSliderRow {
            icon: "rounded_corner"
            title: "Window Corner Rounding"
            valueText: HyprSettings.rounding + " px"
            from: 0
            to: 20
            step: 1
            value: HyprSettings.rounding
            onMoved: v => HyprSettings.setRounding(Math.round(v))
        }

        SettingsSliderRow {
            icon: "opacity"
            title: "Inactive Window Opacity"
            valueText: Math.round(HyprSettings.inactiveOpacity * 100) + "%"
            from: 0.45
            to: 1.0
            step: 0.05
            value: HyprSettings.inactiveOpacity
            onMoved: v => HyprSettings.setInactiveOpacity(v)
        }
    }

    // ---- Blur & Animations ----
    SettingsSection {
        title: "Visual Effects & Motion"

        SettingsRow {
            icon: "blur_on"
            highlighted: HyprSettings.blurEnabled
            title: "Compositor Blur"
            subtitle: "Frosted glass backdrop behind translucent windows and Quickshell layers"
            Toggle {
                checked: HyprSettings.blurEnabled
                onToggled: HyprSettings.setBlurEnabled(!HyprSettings.blurEnabled)
            }
        }

        SettingsSliderRow {
            visible: HyprSettings.blurEnabled
            icon: "grain"
            title: "Blur Radius"
            valueText: String(HyprSettings.blurSize)
            from: 1
            to: 12
            step: 1
            value: HyprSettings.blurSize
            onMoved: v => HyprSettings.setBlurSize(Math.round(v))
        }

        SettingsSliderRow {
            visible: HyprSettings.blurEnabled
            icon: "layers"
            title: "Blur Passes"
            subtitle: "Higher passes look smoother at slightly higher GPU cost"
            valueText: String(HyprSettings.blurPasses)
            from: 1
            to: 4
            step: 1
            value: HyprSettings.blurPasses
            onMoved: v => HyprSettings.setBlurPasses(Math.round(v))
        }

        SettingsRow {
            icon: "animation"
            highlighted: HyprSettings.animationsEnabled
            title: "Window & Workspace Animations"
            subtitle: "Smooth compositor transitions for windows, borders, and workspaces"
            Toggle {
                checked: HyprSettings.animationsEnabled
                onToggled: HyprSettings.setAnimationsEnabled(!HyprSettings.animationsEnabled)
            }
        }
    }
}
