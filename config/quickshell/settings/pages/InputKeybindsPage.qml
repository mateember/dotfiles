import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string bindQuery: ""
    property string bindCategory: "All"

    readonly property var bindCategories: [
        "All", "Desktop Shell", "Windows & Layout", "Workspaces",
        "Screenshots & Capture", "Media & Hardware", "Applications"
    ]

    readonly property var filteredBinds: {
        const q = root.bindQuery.trim().toLowerCase();
        return HyprSettings.keybinds.filter(b => {
            if (root.bindCategory !== "All" && b.category !== root.bindCategory) return false;
            if (!q) return true;
            return b.combo.toLowerCase().includes(q)
                || b.description.toLowerCase().includes(q)
                || b.category.toLowerCase().includes(q)
                || b.arg.toLowerCase().includes(q);
        });
    }

    Component.onCompleted: {
        HyprSettings.refreshDevices();
        HyprSettings.refreshLiveOptions();
        HyprSettings.refreshKeybinds();
    }

    SettingsPageHeader {
        icon: "keyboard"
        title: "Input & Keybindings"
        subtitle: "Touchpad, mouse, multi-layout keyboard switching, and searchable shortcut reference"

        SettingsActionButton {
            icon: "restart_alt"
            text: "Reset Input"
            onClicked: HyprSettings.resetInputOverrides()
        }
    }

    // ---- Keyboard Layouts & Lock OSD ----
    SettingsSection {
        title: "Keyboard Layout"
        description: "Active layout: " + (HyprSettings.activeKeymap || HyprSettings.kbLayouts.join(", "))

        SettingsRow {
            icon: "language"
            highlighted: true
            title: "Active Layouts (" + HyprSettings.kbLayouts.join(", ").toUpperCase() + ")"
            subtitle: "Enable multiple layouts to switch between them anytime"

            SettingsActionButton {
                variant: "accent"
                icon: "swap_horiz"
                text: "Switch Now"
                buttonEnabled: HyprSettings.kbLayouts.length > 1
                onClicked: HyprSettings.switchNextKeyboardLayout()
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            Repeater {
                model: [
                    { code: "hu", label: "Hungarian (HU)" },
                    { code: "us", label: "English US (US)" },
                    { code: "de", label: "German (DE)" },
                    { code: "gb", label: "English UK (GB)" },
                    { code: "fr", label: "French (FR)" }
                ]
                delegate: SettingsActionButton {
                    required property var modelData
                    active: HyprSettings.kbLayouts.indexOf(modelData.code) >= 0
                    text: modelData.label
                    onClicked: HyprSettings.toggleKeyboardLayout(modelData.code)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: 6

            StyledText { text: "Layout Switch Shortcut"; font.weight: Font.Medium }
            SettingsPillGroup {
                selectedId: HyprSettings.currentKbToggleOption()
                model: [
                    { id: "",                    label: "None" },
                    { id: "grp:alt_shift_toggle", label: "Alt + Shift" },
                    { id: "grp:win_space_toggle", label: "Super + Space" },
                    { id: "grp:caps_toggle",      label: "Caps Lock" }
                ]
                onPicked: id => HyprSettings.setKeyboardToggleOption(id)
            }
        }

        SettingsRow {
            icon: "keyboard_capslock"
            title: "Caps Lock, Num Lock & Layout OSD"
            subtitle: "Show an on-screen toast when switching keyboard layout or lock keys"
            Toggle {
                checked: HyprSettings.capsOsdEnabled
                onToggled: HyprSettings.setCapsOsdEnabled(!HyprSettings.capsOsdEnabled)
            }
        }
    }

    // ---- Touchpad & Mouse ----
    SettingsSection {
        title: "Touchpad & Mouse"

        SettingsRow {
            icon: "touch_app"
            title: "Touchpad Natural Scrolling"
            subtitle: "Content follows finger movement direction"
            Toggle {
                checked: HyprSettings.touchpadNaturalScroll
                onToggled: HyprSettings.setTouchpadNaturalScroll(!HyprSettings.touchpadNaturalScroll)
            }
        }

        SettingsRow {
            icon: "ads_click"
            title: "Touchpad Tap-to-Click"
            subtitle: "Tap the touchpad lightly to click"
            Toggle {
                checked: HyprSettings.touchpadTapToClick
                onToggled: HyprSettings.setTouchpadTapToClick(!HyprSettings.touchpadTapToClick)
            }
        }

        SettingsSliderRow {
            icon: "swipe"
            title: "Touchpad Sensitivity"
            subtitle: HyprSettings.touchpadName
            valueText: HyprSettings.touchpadSensitivity.toFixed(2)
            from: -1.0
            to: 1.0
            step: 0.05
            value: HyprSettings.touchpadSensitivity
            onMoved: v => HyprSettings.setTouchpadSensitivity(v)
        }

        SettingsSliderRow {
            icon: "mouse"
            title: "Mouse Sensitivity"
            valueText: HyprSettings.mouseSensitivity.toFixed(2)
            from: -1.0
            to: 1.0
            step: 0.05
            value: HyprSettings.mouseSensitivity
            onMoved: v => HyprSettings.setMouseSensitivity(v)
        }

        SettingsRow {
            icon: "speed"
            title: "Mouse Acceleration Profile"
            subtitle: "Flat gives 1:1 raw movement; Adaptive accelerates fast sweeps"
            SettingsPillGroup {
                Layout.preferredWidth: 190
                Layout.fillWidth: false
                selectedId: HyprSettings.mouseAccelProfile
                model: [{ id: "flat", label: "Flat" }, { id: "adaptive", label: "Adaptive" }]
                onPicked: id => HyprSettings.setMouseAccelProfile(id)
            }
        }

        SettingsRow {
            icon: "swap_vert"
            title: "Mouse Natural Scrolling"
            subtitle: "Reverse mouse wheel scroll direction"
            Toggle {
                checked: HyprSettings.mouseNaturalScroll
                onToggled: HyprSettings.setMouseNaturalScroll(!HyprSettings.mouseNaturalScroll)
            }
        }
    }

    // ---- Searchable Keybindings Cheat Sheet ----
    SettingsSection {
        title: "Keybindings Reference (" + root.filteredBinds.length + ")"
        description: "Live bindings loaded directly from Hyprland"

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXxs

                TextField {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    placeholder: "Filter shortcuts (e.g. screenshot, overview, workspace, SUPER)…"
                    text: root.bindQuery
                    onTextChanged: root.bindQuery = text
                }
                SettingsActionButton {
                    icon: "refresh"
                    text: "Reload"
                    onClicked: HyprSettings.refreshKeybinds()
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: root.bindCategories
                    delegate: SettingsActionButton {
                        required property string modelData
                        active: root.bindCategory === modelData
                        text: modelData
                        onClicked: root.bindCategory = modelData
                    }
                }
            }
        }

        StyledText {
            visible: root.filteredBinds.length === 0
            Layout.fillWidth: true
            Layout.margins: Theme.spaceS
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textDim
            text: HyprSettings.keybindsLoading ? "Loading keybindings…" : "No matching shortcuts"
        }

        Repeater {
            model: root.filteredBinds.slice(0, 60)
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: Math.max(44, bRow.implicitHeight + 12)
                radius: Theme.radiusS
                color: Theme.surface0

                RowLayout {
                    id: bRow
                    anchors {
                        fill: parent
                        leftMargin: Theme.spaceXs
                        rightMargin: Theme.spaceXs
                    }
                    spacing: Theme.spaceXs

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.description
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        StyledText {
                            text: modelData.category
                            font.pixelSize: 11
                            color: Theme.textDim
                        }
                    }

                    Rectangle {
                        implicitWidth: kLbl.implicitWidth + 16
                        implicitHeight: 28
                        radius: Theme.radiusXs
                        color: Theme.primaryComponent
                        border.width: 1
                        border.color: Theme.divider

                        StyledText {
                            id: kLbl
                            anchors.centerIn: parent
                            text: modelData.combo
                            font.family: Theme.monoFamily
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: Font.DemiBold
                            color: Theme.accent
                        }
                    }
                }
            }
        }
    }
}
