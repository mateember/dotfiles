import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Profile creation, switching, renaming, duplication, deletion, and factory reset.
ColumnLayout {
    id: root

    property string renamingId: ""
    property string confirmDeleteId: ""
    property bool resetArmed: false

    Layout.fillWidth: true
    spacing: Theme.spaceM

    Timer {
        id: deleteArmTimer
        interval: 2800
        onTriggered: root.confirmDeleteId = ""
    }

    Timer {
        id: resetArmTimer
        interval: 2600
        onTriggered: root.resetArmed = false
    }

    function submitNewProfile() {
        const name = nameField.text.trim();
        const desc = descField.text.trim();
        if (!name && ThemeConfig.userProfiles.length === 0) {
            ThemeConfig.createProfile("My Theme", desc);
        } else {
            ThemeConfig.createProfile(name, desc);
        }
        nameField.text = "";
        descField.text = "";
    }

    // ---- Create / Update Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: createCol.implicitHeight + 2 * Theme.spaceS
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        ColumnLayout {
            id: createCol
            anchors.fill: parent
            anchors.margins: Theme.spaceS
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Icon { icon: "bookmark_add"; size: 17; color: Theme.accent }
                StyledText {
                    Layout.fillWidth: true
                    text: "Save Current Look as Profile"
                    font.pixelSize: Theme.fontSize
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: ThemeConfig.activeIsBuiltin
                    ? "Built-in presets stay immutable — save tweaks as a custom profile so you can switch back anytime."
                    : "Save a snapshot of all current colors, surfaces, bar geometry, and typography."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
                wrapMode: Text.WordWrap
            }

            // Quick Update/Revert banner when modifying an existing custom profile
            Rectangle {
                visible: !ThemeConfig.activeIsBuiltin && ThemeConfig.isDirty
                Layout.fillWidth: true
                implicitHeight: dirtyRow.implicitHeight + 2 * Theme.spaceXs
                radius: Theme.radiusS
                color: Theme.alpha(Theme.accent, 0.14)
                border.width: 1
                border.color: Theme.alpha(Theme.accent, 0.45)

                RowLayout {
                    id: dirtyRow
                    anchors.fill: parent
                    anchors.margins: Theme.spaceXs
                    spacing: Theme.spaceXs

                    Icon { icon: "edit_note"; size: 16; color: Theme.accent }
                    StyledText {
                        Layout.fillWidth: true
                        text: "\"" + ThemeConfig.activeProfile.name + "\" has unsaved tweaks"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textStrong
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: revertLbl.implicitWidth + 16
                        implicitHeight: 26
                        radius: 13
                        color: revertMouse.pressed ? Theme.componentPressed
                             : revertMouse.containsMouse ? Theme.componentHover
                             : Theme.component

                        StyledText {
                            id: revertLbl
                            anchors.centerIn: parent
                            text: "Revert"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.text
                        }
                        MouseArea {
                            id: revertMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.revertToActiveProfile()
                        }
                    }

                    Rectangle {
                        implicitWidth: updateLbl.implicitWidth + 18
                        implicitHeight: 26
                        radius: 13
                        color: updateMouse.pressed ? Theme.accentPressed
                             : updateMouse.containsMouse ? Theme.accentHover
                             : Theme.accent

                        StyledText {
                            id: updateLbl
                            anchors.centerIn: parent
                            text: "Update Profile"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.fgOnAccent
                        }
                        MouseArea {
                            id: updateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ThemeConfig.saveToActiveProfile()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                TextField {
                    id: nameField
                    Layout.fillWidth: true
                    placeholder: "Profile name (e.g. Studio Dark)"
                    onAccepted: root.submitNewProfile()
                }

                Rectangle {
                    implicitWidth: saveRow.implicitWidth + 20
                    implicitHeight: 34
                    radius: 17
                    color: saveNewMouse.pressed ? Theme.accentPressed
                         : saveNewMouse.containsMouse ? Theme.accentHover
                         : Theme.accent

                    RowLayout {
                        id: saveRow
                        anchors.centerIn: parent
                        spacing: 5
                        Icon { icon: "add"; size: 16; color: Theme.fgOnAccent }
                        StyledText {
                            text: "Create Profile"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.DemiBold
                            color: Theme.fgOnAccent
                        }
                    }

                    MouseArea {
                        id: saveNewMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submitNewProfile()
                    }
                }
            }

            TextField {
                id: descField
                Layout.fillWidth: true
                placeholder: "Optional description (notes, mood, monitor setup)"
                onAccepted: root.submitNewProfile()
            }
        }
    }

    // ---- Custom Profiles ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            StyledText {
                Layout.fillWidth: true
                text: "Custom Profiles (" + ThemeConfig.userProfiles.length + ")"
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
                color: Theme.textStrong
            }
        }

        Rectangle {
            visible: ThemeConfig.userProfiles.length === 0
            Layout.fillWidth: true
            implicitHeight: emptyCol.implicitHeight + 2 * Theme.spaceS
            radius: Theme.radiusM
            color: Theme.surface0
            border.width: 1
            border.color: Theme.divider

            ColumnLayout {
                id: emptyCol
                anchors.fill: parent
                anchors.margins: Theme.spaceS
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: "No custom profiles yet"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Tweak any colors, opacities, or bar settings and save them above, or duplicate a built-in preset below."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
            }
        }

        Repeater {
            model: ThemeConfig.userProfiles

            delegate: Rectangle {
                id: userCard
                required property var modelData
                readonly property bool isActive: modelData.id === ThemeConfig.activeProfileId
                readonly property bool isRenaming: root.renamingId === modelData.id
                readonly property bool isConfirmingDelete: root.confirmDeleteId === modelData.id
                readonly property var paletteDots: [
                    modelData.settings.bg || "#1B1B1B",
                    modelData.settings.primary || "#272727",
                    modelData.settings.accent || "#FFAD00",
                    modelData.settings.text || "#EEEEEE"
                ]

                Layout.fillWidth: true
                implicitHeight: userRow.implicitHeight + 2 * Theme.spaceXs
                radius: Theme.radiusM
                color: isActive ? Theme.alpha(Theme.accent, 0.10)
                     : cardMouse.containsMouse ? Theme.alpha(Theme.surfaceTint, 0.05 * Theme.surfaceStrength)
                     : Theme.surface0
                border.width: isActive ? 1.5 : 1
                border.color: isActive ? Theme.accent : Theme.divider

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !userCard.isRenaming
                    onClicked: ThemeConfig.applyProfile(userCard.modelData.id)
                }

                RowLayout {
                    id: userRow
                    anchors.fill: parent
                    anchors.margins: Theme.spaceXs
                    spacing: Theme.spaceS

                    // 2x2 Palette Swatch Grid
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Theme.radiusS
                        color: userCard.paletteDots[0]
                        border.width: 1
                        border.color: Theme.divider

                        Grid {
                            anchors.centerIn: parent
                            columns: 2
                            spacing: 3

                            Repeater {
                                model: userCard.paletteDots
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: modelData
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.borderColor, 0.28)
                                }
                            }
                        }
                    }

                    // Name / Rename input / Metadata
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            visible: userCard.isRenaming
                            Layout.fillWidth: true
                            spacing: 4

                            TextField {
                                id: renameInput
                                Layout.fillWidth: true
                                text: userCard.modelData.name
                                onAccepted: {
                                    ThemeConfig.renameProfile(userCard.modelData.id, text);
                                    root.renamingId = "";
                                }
                            }
                            IconButton {
                                icon: "check"
                                highlighted: true
                                onClicked: {
                                    ThemeConfig.renameProfile(userCard.modelData.id, renameInput.text);
                                    root.renamingId = "";
                                }
                            }
                            IconButton {
                                icon: "close"
                                onClicked: root.renamingId = ""
                            }
                        }

                        RowLayout {
                            visible: !userCard.isRenaming
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                text: userCard.modelData.name
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                color: Theme.textStrong
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: userCard.isActive
                                implicitWidth: activeTag.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: Theme.accent

                                StyledText {
                                    id: activeTag
                                    anchors.centerIn: parent
                                    text: ThemeConfig.isDirty ? "Active · Modified" : "Active"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fgOnAccent
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        StyledText {
                            visible: !userCard.isRenaming
                            Layout.fillWidth: true
                            text: (userCard.modelData.description ? (userCard.modelData.description + " · ") : "")
                                + (userCard.modelData.settings.fontFamily || "Fira Sans") + " "
                                + (userCard.modelData.settings.fontSize || 14) + "px · Bar "
                                + (userCard.modelData.settings.barHeight || 35) + "px"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                    }

                    // Trailing actions
                    RowLayout {
                        visible: !userCard.isRenaming
                        spacing: 2

                        IconButton {
                            visible: userCard.isActive && ThemeConfig.isDirty
                            icon: "save"
                            highlighted: true
                            onClicked: ThemeConfig.saveToActiveProfile()
                        }

                        IconButton {
                            icon: "edit"
                            onClicked: {
                                root.renamingId = userCard.modelData.id;
                                Qt.callLater(() => renameInput.focusInput());
                            }
                        }

                        IconButton {
                            icon: "content_copy"
                            onClicked: ThemeConfig.duplicateProfile(userCard.modelData.id, "")
                        }

                        Rectangle {
                            visible: userCard.isConfirmingDelete
                            implicitWidth: confirmDelRow.implicitWidth + 14
                            implicitHeight: 28
                            radius: 14
                            color: Theme.destructive

                            RowLayout {
                                id: confirmDelRow
                                anchors.centerIn: parent
                                spacing: 4
                                Icon { icon: "delete"; size: 15; color: "#000000" }
                                StyledText {
                                    text: "Delete?"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: "#000000"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    deleteArmTimer.stop();
                                    root.confirmDeleteId = "";
                                    ThemeConfig.deleteProfile(userCard.modelData.id);
                                }
                            }
                        }

                        IconButton {
                            visible: !userCard.isConfirmingDelete
                            icon: "delete"
                            onClicked: {
                                root.confirmDeleteId = userCard.modelData.id;
                                deleteArmTimer.restart();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Built-in Presets ----
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        StyledText {
            Layout.fillWidth: true
            text: "Built-in Presets"
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            color: Theme.textStrong
        }

        Repeater {
            model: ThemeConfig.builtinProfiles

            delegate: Rectangle {
                id: presetCard
                required property var modelData
                readonly property bool isActive: modelData.id === ThemeConfig.activeProfileId
                readonly property bool isDefault: modelData.id === "default"
                readonly property var paletteDots: [
                    modelData.settings.bg || "#1B1B1B",
                    modelData.settings.primary || "#272727",
                    modelData.settings.accent || "#FFAD00",
                    modelData.settings.text || "#EEEEEE"
                ]

                Layout.fillWidth: true
                implicitHeight: presetRow.implicitHeight + 2 * Theme.spaceXs
                radius: Theme.radiusM
                color: isActive ? Theme.alpha(Theme.accent, 0.10)
                     : presetMouse.containsMouse ? Theme.alpha(Theme.surfaceTint, 0.05 * Theme.surfaceStrength)
                     : Theme.surface0
                border.width: isActive ? 1.5 : 1
                border.color: isActive ? Theme.accent : Theme.divider

                MouseArea {
                    id: presetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ThemeConfig.applyProfile(presetCard.modelData.id)
                }

                RowLayout {
                    id: presetRow
                    anchors.fill: parent
                    anchors.margins: Theme.spaceXs
                    spacing: Theme.spaceS

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: Theme.radiusS
                        color: presetCard.paletteDots[0]
                        border.width: 1
                        border.color: Theme.divider

                        Grid {
                            anchors.centerIn: parent
                            columns: 2
                            spacing: 3

                            Repeater {
                                model: presetCard.paletteDots
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: modelData
                                    border.width: 1
                                    border.color: Theme.alpha(Theme.borderColor, 0.28)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            StyledText {
                                text: presetCard.modelData.name
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                color: Theme.textStrong
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: kindTag.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: Theme.component

                                StyledText {
                                    id: kindTag
                                    anchors.centerIn: parent
                                    text: presetCard.isDefault ? "Default" : "Built-in"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: Theme.text
                                }
                            }

                            Rectangle {
                                visible: presetCard.isActive
                                implicitWidth: presetActiveTag.implicitWidth + 10
                                implicitHeight: 18
                                radius: 9
                                color: Theme.accent

                                StyledText {
                                    id: presetActiveTag
                                    anchors.centerIn: parent
                                    text: ThemeConfig.isDirty ? "Active · Modified" : "Active"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fgOnAccent
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: presetCard.modelData.description || ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        icon: "content_copy"
                        onClicked: ThemeConfig.duplicateProfile(presetCard.modelData.id, "")
                    }
                }
            }
        }
    }

    // ---- Factory Reset ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: resetRow.implicitHeight + 2 * Theme.spaceXs
        radius: Theme.radiusM
        color: Theme.surface0
        border.width: 1
        border.color: Theme.divider

        RowLayout {
            id: resetRow
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceS

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: "Restore Original Look (Default)"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.textStrong
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Re-applies COSMIC Dark factory settings. Custom profiles remain saved."
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                implicitWidth: factoryBtnLbl.implicitWidth + 20
                implicitHeight: 32
                radius: 16
                color: root.resetArmed
                    ? Theme.destructive
                    : (factoryMouse.pressed ? Theme.componentPressed
                     : factoryMouse.containsMouse ? Theme.componentHover
                     : Theme.component)

                StyledText {
                    id: factoryBtnLbl
                    anchors.centerIn: parent
                    text: root.resetArmed ? "Click again to reset" : "Reset to Default"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: root.resetArmed ? Font.DemiBold : Font.Normal
                    color: root.resetArmed ? "#000000" : Theme.text
                }

                MouseArea {
                    id: factoryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.resetArmed) {
                            root.resetArmed = true;
                            resetArmTimer.restart();
                            return;
                        }
                        resetArmTimer.stop();
                        root.resetArmed = false;
                        ThemeConfig.resetToDefault();
                    }
                }
            }
        }
    }
}
