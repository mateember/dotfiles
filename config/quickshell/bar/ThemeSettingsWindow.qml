import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "theme"

// Standalone FloatingWindow app for live theme customization and profile
// management. Launchable via `!theme`, `qs ipc call theme toggle`, or header
// shortcuts inside Bar Settings and Opacity & Transparency.
Scope {
    id: scopeRoot

    property int activeTab: 0
    property bool showPreview: true
    property bool quickSaveOpen: false

    function openNewProfileBar() {
        scopeRoot.quickSaveOpen = true;
        Qt.callLater(() => {
            const win = loader.item;
            if (win && win.quickField) win.quickField.focusInput();
        });
    }

    LazyLoader {
        id: loader
        active: ThemeConfig.settingsOpen

        FloatingWindow {
            id: win
            title: "HCS — Theme & Profiles"
            visible: ThemeConfig.settingsOpen && !ThemeConfig.pickingColor
            color: "transparent"
            implicitWidth: 740
            implicitHeight: 680
            minimumSize: Qt.size(620, 520)

            property alias quickField: quickSaveField

            onVisibleChanged: {
                if (!visible && ThemeConfig.settingsOpen && !ThemeConfig.pickingColor) {
                    WidgetHistory.closeThemeSettings();
                }
            }

            readonly property var tabs: [
                { label: "Profiles",      icon: "style" },
                { label: "Colors",        icon: "palette" },
                { label: "Surfaces",      icon: "layers" },
                { label: "Shape & Bar",   icon: "rounded_corner" },
                { label: "Type & Motion", icon: "text_fields" }
            ]

            function submitQuickSave() {
                const name = quickSaveField.text.trim();
                ThemeConfig.createProfile(name, "");
                quickSaveField.text = "";
                scopeRoot.quickSaveOpen = false;
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                focus: true

                Keys.onEscapePressed: {
                    if (scopeRoot.quickSaveOpen) {
                        scopeRoot.quickSaveOpen = false;
                    } else {
                        WidgetHistory.backFromThemeSettings();
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    // ---- Header ----
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: headerRow.implicitHeight + 2 * Theme.spaceS
                        color: Theme.primary

                        RowLayout {
                            id: headerRow
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceM
                            anchors.rightMargin: Theme.spaceM
                            anchors.topMargin: Theme.spaceS
                            anchors.bottomMargin: Theme.spaceS
                            spacing: Theme.spaceXs

                            IconButton {
                                visible: WidgetHistory.themeOrigin !== ""
                                icon: "arrow_back"
                                onClicked: WidgetHistory.backFromThemeSettings()
                            }

                            Icon {
                                icon: "palette"
                                size: 22
                                color: Theme.accent
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                StyledText {
                                    text: "Theme & Profiles"
                                    font.pixelSize: Theme.fontSizeTitle
                                    font.weight: Font.DemiBold
                                    color: Theme.textStrong
                                }

                                RowLayout {
                                    spacing: 6

                                    StyledText {
                                        text: ThemeConfig.activeProfile.name
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Medium
                                        color: ThemeConfig.isDirty ? Theme.accent : Theme.textDim
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        visible: ThemeConfig.activeProfileId === "default"
                                        text: "· Original look"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.textDim
                                    }

                                    Rectangle {
                                        visible: ThemeConfig.isDirty
                                        implicitWidth: dirtyTag.implicitWidth + 10
                                        implicitHeight: 17
                                        radius: 8.5
                                        color: Theme.alpha(Theme.accent, 0.18)
                                        border.width: 1
                                        border.color: Theme.alpha(Theme.accent, 0.5)

                                        StyledText {
                                            id: dirtyTag
                                            anchors.centerIn: parent
                                            text: "Modified"
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: Theme.accent
                                        }
                                    }
                                }
                            }

                            // Save changes into active custom profile
                            Rectangle {
                                visible: !ThemeConfig.activeIsBuiltin && ThemeConfig.isDirty
                                implicitWidth: hdrSaveRow.implicitWidth + 16
                                implicitHeight: 30
                                radius: 15
                                color: hdrSaveMouse.pressed ? Theme.accentPressed
                                     : hdrSaveMouse.containsMouse ? Theme.accentHover
                                     : Theme.accent

                                RowLayout {
                                    id: hdrSaveRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Icon { icon: "save"; size: 15; color: Theme.fgOnAccent }
                                    StyledText {
                                        text: "Save"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        color: Theme.fgOnAccent
                                    }
                                }
                                MouseArea {
                                    id: hdrSaveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ThemeConfig.saveToActiveProfile()
                                }
                            }

                            // Save As New Profile toggle
                            Rectangle {
                                implicitWidth: saveAsRow.implicitWidth + 16
                                implicitHeight: 30
                                radius: 15
                                color: scopeRoot.quickSaveOpen
                                    ? Theme.accent
                                    : (saveAsMouse.pressed ? Theme.componentPressed
                                     : saveAsMouse.containsMouse ? Theme.componentHover
                                     : Theme.component)

                                RowLayout {
                                    id: saveAsRow
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Icon {
                                        icon: "bookmark_add"
                                        size: 15
                                        color: scopeRoot.quickSaveOpen ? Theme.fgOnAccent : Theme.accent
                                    }
                                    StyledText {
                                        text: "Save As…"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: scopeRoot.quickSaveOpen ? Font.DemiBold : Font.Normal
                                        color: scopeRoot.quickSaveOpen ? Theme.fgOnAccent : Theme.text
                                    }
                                }
                                MouseArea {
                                    id: saveAsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (scopeRoot.quickSaveOpen) scopeRoot.quickSaveOpen = false;
                                        else scopeRoot.openNewProfileBar();
                                    }
                                }
                            }

                            // Revert active tweaks or jump back to Default
                            Rectangle {
                                visible: ThemeConfig.isDirty || ThemeConfig.activeProfileId !== "default"
                                implicitWidth: revertHdrLbl.implicitWidth + 16
                                implicitHeight: 30
                                radius: 15
                                color: revertHdrMouse.pressed ? Theme.componentPressed
                                     : revertHdrMouse.containsMouse ? Theme.componentHover
                                     : Theme.component

                                StyledText {
                                    id: revertHdrLbl
                                    anchors.centerIn: parent
                                    text: ThemeConfig.isDirty ? "Revert" : "Default"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.text
                                }
                                MouseArea {
                                    id: revertHdrMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (ThemeConfig.isDirty) ThemeConfig.revertToActiveProfile();
                                        else ThemeConfig.resetToDefault();
                                    }
                                }
                            }

                            IconButton {
                                icon: scopeRoot.showPreview ? "visibility" : "visibility_off"
                                highlighted: scopeRoot.showPreview
                                onClicked: scopeRoot.showPreview = !scopeRoot.showPreview
                            }

                            IconButton {
                                icon: "close"
                                onClicked: WidgetHistory.closeThemeSettings()
                            }
                        }
                    }

                    // ---- Inline Quick-Save Profile Bar ----
                    Rectangle {
                        visible: scopeRoot.quickSaveOpen
                        Layout.fillWidth: true
                        implicitHeight: qsBarRow.implicitHeight + 2 * Theme.spaceXs
                        color: Theme.alpha(Theme.accent, 0.12)

                        RowLayout {
                            id: qsBarRow
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceM
                            anchors.rightMargin: Theme.spaceM
                            anchors.topMargin: Theme.spaceXs
                            anchors.bottomMargin: Theme.spaceXs
                            spacing: Theme.spaceXs

                            StyledText {
                                text: "New Profile:"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                                color: Theme.textStrong
                            }

                            TextField {
                                id: quickSaveField
                                Layout.fillWidth: true
                                placeholder: "Profile name (e.g. Late Night, Daylight)"
                                onAccepted: win.submitQuickSave()
                            }

                            Rectangle {
                                implicitWidth: qsSaveLbl.implicitWidth + 18
                                implicitHeight: 32
                                radius: 16
                                color: qsSaveMouse.pressed ? Theme.accentPressed
                                     : qsSaveMouse.containsMouse ? Theme.accentHover
                                     : Theme.accent

                                StyledText {
                                    id: qsSaveLbl
                                    anchors.centerIn: parent
                                    text: "Save Profile"
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.fgOnAccent
                                }
                                MouseArea {
                                    id: qsSaveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.submitQuickSave()
                                }
                            }

                            IconButton {
                                icon: "close"
                                onClicked: scopeRoot.quickSaveOpen = false
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

                    // ---- Category Tabs ----
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: tabRow.implicitHeight + 2 * Theme.spaceXs
                        color: Theme.surface0

                        RowLayout {
                            id: tabRow
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spaceM
                            anchors.rightMargin: Theme.spaceM
                            anchors.topMargin: Theme.spaceXs
                            anchors.bottomMargin: Theme.spaceXs
                            spacing: 6

                            Repeater {
                                model: win.tabs
                                delegate: Rectangle {
                                    id: tabPill
                                    required property int index
                                    required property var modelData
                                    readonly property bool selected: scopeRoot.activeTab === index

                                    Layout.fillWidth: true
                                    implicitHeight: 34
                                    radius: Theme.radiusS
                                    color: selected ? Theme.accent
                                         : tabMouse.containsMouse ? Theme.componentHover
                                         : Theme.component
                                    border.width: 1
                                    border.color: selected ? Theme.accent : Theme.divider

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Icon {
                                            icon: tabPill.modelData.icon
                                            size: 16
                                            color: tabPill.selected ? Theme.fgOnAccent : Theme.accent
                                        }
                                        StyledText {
                                            text: tabPill.modelData.label
                                            font.pixelSize: Theme.fontSizeSmall
                                            font.weight: tabPill.selected ? Font.DemiBold : Font.Normal
                                            color: tabPill.selected ? Theme.fgOnAccent : Theme.text
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            scopeRoot.activeTab = tabPill.index;
                                            pageFlick.contentY = 0;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: Theme.divider }

                    // ---- Scrollable Page Content ----
                    Flickable {
                        id: pageFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: pageStack.implicitHeight + 2 * Theme.spaceM
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: pageStack
                            width: parent.width - 2 * Theme.spaceM
                            x: Theme.spaceM
                            y: Theme.spaceM
                            spacing: 0

                            ThemeProfilesPage   { visible: scopeRoot.activeTab === 0 }
                            ThemeColorsPage     { visible: scopeRoot.activeTab === 1 }
                            ThemeSurfacePage    { visible: scopeRoot.activeTab === 2 }
                            ThemeLayoutPage     { visible: scopeRoot.activeTab === 3 }
                            ThemeTypographyPage { visible: scopeRoot.activeTab === 4 }
                        }
                    }

                    // ---- Collapsible Live Preview Footer ----
                    Rectangle {
                        visible: scopeRoot.showPreview
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.divider
                    }

                    Rectangle {
                        visible: scopeRoot.showPreview
                        Layout.fillWidth: true
                        implicitHeight: footerPreview.implicitHeight + 2 * Theme.spaceXs
                        color: Theme.primary

                        ThemePreviewStrip {
                            id: footerPreview
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                leftMargin: Theme.spaceXs
                                rightMargin: Theme.spaceXs
                            }
                        }
                    }
                }
            }
        }
    }
}
