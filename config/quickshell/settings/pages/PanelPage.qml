import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string filterSection: "all"

    readonly property var filteredItems: {
        if (filterSection === "all") return BarConfig.items;
        return BarConfig.items.filter(i => i.section === filterSection);
    }

    function sectionList(sec: string): var {
        return sec === "left" ? BarConfig.leftIds
             : sec === "center" ? BarConfig.centerIds
             : BarConfig.rightIds;
    }

    function canMoveUp(item): bool {
        return sectionList(item.section).indexOf(item.id) > 0;
    }

    function canMoveDown(item): bool {
        const ids = sectionList(item.section);
        const idx = ids.indexOf(item.id);
        return idx >= 0 && idx < ids.length - 1;
    }

    SettingsPageHeader {
        icon: "view_agenda"
        title: "Top Bar"
        subtitle: "Enable, reorder, and place the 22 modular widgets across Left, Center, and Right"

        SettingsActionButton {
            icon: "opacity"
            text: "Bar Opacity"
            onClicked: SettingsState.openPage("appearance", "surfaces")
        }
        SettingsActionButton {
            icon: "rounded_corner"
            text: "Bar Shape"
            onClicked: SettingsState.openPage("appearance", "shape")
        }
        SettingsActionButton {
            icon: "restart_alt"
            text: "Reset"
            onClicked: BarConfig.reset()
        }
    }

    SettingsPillGroup {
        selectedId: root.filterSection
        model: [
            { id: "all",    label: "All (" + BarConfig.items.length + ")" },
            { id: "left",   label: "Left (" + BarConfig.leftIds.length + ")" },
            { id: "center", label: "Center (" + BarConfig.centerIds.length + ")" },
            { id: "right",  label: "Right (" + BarConfig.rightIds.length + ")" }
        ]
        onPicked: id => root.filterSection = id
    }

    SettingsCard {
        spacing: 4

        Repeater {
            model: root.filteredItems
            delegate: SettingsRow {
                id: modRow
                required property var modelData
                icon: modelData.icon
                iconColor: modelData.enabled ? Theme.accent : Theme.textDim
                title: modelData.name
                subtitle: modelData.subtitle

                SettingsActionButton {
                    text: modRow.modelData.section === "left" ? "Left"
                        : modRow.modelData.section === "center" ? "Center" : "Right"
                    onClicked: BarConfig.cycleSection(modRow.modelData.id)
                }

                IconButton {
                    icon: "keyboard_arrow_up"
                    implicitWidth: 36
                    implicitHeight: 36
                    enabled: root.canMoveUp(modRow.modelData)
                    onClicked: BarConfig.move(modRow.modelData.id, -1)
                }

                IconButton {
                    icon: "keyboard_arrow_down"
                    implicitWidth: 36
                    implicitHeight: 36
                    enabled: root.canMoveDown(modRow.modelData)
                    onClicked: BarConfig.move(modRow.modelData.id, 1)
                }

                Toggle {
                    checked: modRow.modelData.enabled
                    onToggled: BarConfig.toggle(modRow.modelData.id)
                }
            }
        }
    }
}
