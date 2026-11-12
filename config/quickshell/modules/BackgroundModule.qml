import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "background"

// Top bar widget + tabbed Background Settings popup:
//   - Left-click: open Background Settings popup
//   - Right-click: advance to next wallpaper (Folder mode) or toggle animation pause
//   - Middle-click: toggle slideshow / animation pause
BarButton {
    id: btn

    active: pop.open

    readonly property bool pausedHighlight:
        (Wallpapers.mode === "folder" && Wallpapers.slideshowPaused)
        || (Wallpapers.mode === "animated" && Wallpapers.animatedPaused)

    readonly property string barIconName: {
        if (Wallpapers.mode === "image") return "image";
        if (Wallpapers.mode === "animated") return "animation";
        if (Wallpapers.mode === "solid") return "palette";
        return "photo_library";
    }

    onClicked: button => {
        if (button === Qt.LeftButton) {
            pop.toggle();
        } else if (button === Qt.RightButton) {
            if (Wallpapers.mode === "folder") Wallpapers.next();
            else if (Wallpapers.mode === "animated") Wallpapers.toggleAnimatedPause();
            else pop.toggle();
        } else if (button === Qt.MiddleButton) {
            Wallpapers.toggleCurrentPause();
        }
    }

    Item {
        implicitWidth: barGlyph.implicitWidth
        implicitHeight: barGlyph.implicitHeight

        Icon {
            id: barGlyph
            anchors.centerIn: parent
            icon: btn.barIconName
            size: Theme.barIconSize
            color: btn.pausedHighlight ? Theme.accent : Theme.text
        }

        // Small status dot when slideshow or animation is paused
        Rectangle {
            visible: btn.pausedHighlight
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -2
            anchors.bottomMargin: -1
            width: 6
            height: 6
            radius: 3
            color: Theme.accent
            border.width: 1
            border.color: Theme.bg
        }
    }

    Popup {
        id: pop
        anchorItem: btn
        name: "background"
        contentWidth: 420

        property bool showEffects: false
        property string targetScreen: ""

        function ensureTargetScreen() {
            const screens = Quickshell.screens;
            if (targetScreen && screens.some(s => s.name === targetScreen)) return;
            targetScreen = pop.barWindow?.screen?.name ?? (screens[0]?.name ?? "");
        }

        onOpenChanged: {
            if (open) {
                ensureTargetScreen();
                showEffects = false;
            }
        }

        backHandler: () => {
            if (showEffects) {
                showEffects = false;
                return true;
            }
            return false;
        }

        ColumnLayout {
            width: parent.width
            spacing: Theme.spaceXxs

            PopupHeader {
                title: pop.showEffects ? "Background Effects" : "Background"
                showBack: pop.showEffects || pop.canGoBack
                backAction: () => {
                    if (pop.showEffects) pop.showEffects = false;
                    else pop.back();
                }

                IconButton {
                    visible: !pop.showEffects && (Wallpapers.mode === "folder" || Wallpapers.mode === "animated")
                    icon: (Wallpapers.mode === "folder" ? Wallpapers.slideshowPaused : Wallpapers.animatedPaused)
                        ? "play_arrow" : "pause"
                    filled: true
                    highlighted: Wallpapers.mode === "folder" ? Wallpapers.slideshowPaused : Wallpapers.animatedPaused
                    onClicked: Wallpapers.toggleCurrentPause()
                }

                IconButton {
                    visible: !pop.showEffects && Wallpapers.mode === "folder"
                    icon: "skip_next"
                    enabled: Wallpapers.count > 1
                    onClicked: Wallpapers.next()
                }

                IconButton {
                    icon: "tune"
                    highlighted: pop.showEffects
                    onClicked: pop.showEffects = !pop.showEffects
                }
            }

            // ---- Effects & Reset Subpage ----
            BackgroundEffectsPage {
                visible: pop.showEffects
                Layout.fillWidth: true
            }

            // ---- Main View (Hero Preview + 4 Mode Tabs + Active Page) ----
            ColumnLayout {
                visible: !pop.showEffects
                Layout.fillWidth: true
                spacing: Theme.spaceXxs

                BackgroundHeroPreview {
                    Layout.fillWidth: true
                    targetScreen: pop.targetScreen
                    popupOpen: pop.open && !pop.showEffects
                    onScreenPicked: sn => pop.targetScreen = sn
                }

                // 4-tab mode switcher
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spaceXxxs

                    Repeater {
                        model: [
                            { id: "folder",   label: "Folder",   icon: "photo_library" },
                            { id: "image",    label: "Image",    icon: "image" },
                            { id: "animated", label: "Animated", icon: "animation" },
                            { id: "solid",    label: "Solid",    icon: "palette" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: Wallpapers.mode === modelData.id
                            readonly property bool tabEnabled: modelData.id !== "animated" || Wallpapers.animatedAllowed

                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: Theme.radiusS
                            opacity: tabEnabled ? 1.0 : 0.45
                            color: selected ? Theme.accent
                                 : (tabEnabled && tabMouse.containsMouse) ? Theme.componentHover
                                 : Theme.component
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.componentDivider
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    icon: modelData.icon
                                    size: 16
                                    color: selected ? Theme.fgOnAccent : Theme.text
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: selected ? Font.DemiBold : Font.Normal
                                    color: selected ? Theme.fgOnAccent : Theme.text
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                enabled: tabEnabled
                                hoverEnabled: true
                                cursorShape: tabEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Wallpapers.setMode(modelData.id)
                            }
                        }
                    }
                }

                // Performance-mode requirement hint when Animated is unavailable
                Rectangle {
                    visible: !Wallpapers.animatedAllowed
                    Layout.fillWidth: true
                    implicitHeight: perfHintRow.implicitHeight + 10
                    radius: Theme.radiusXs
                    color: Theme.surface1
                    border.width: 1
                    border.color: Theme.componentDivider

                    RowLayout {
                        id: perfHintRow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceXxs
                        anchors.rightMargin: Theme.spaceXxs
                        spacing: Theme.spaceXxs

                        Icon {
                            icon: "bolt"
                            size: 14
                            color: Wallpapers.resumeAnimatedOnPerf ? Theme.accent : Theme.textDim
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Wallpapers.resumeAnimatedOnPerf
                                ? "Animated paused (" + PowerProfile.label + ") — resumes on Performance"
                                : "Animated requires Performance power mode"
                            font.pixelSize: 11
                            color: Theme.textDim
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            implicitHeight: 20
                            implicitWidth: perfBtnLbl.implicitWidth + 12
                            radius: Theme.radiusXl
                            color: perfBtnMouse.containsMouse ? Theme.accentHover : Theme.component
                            border.width: 1
                            border.color: Theme.componentDivider

                            StyledText {
                                id: perfBtnLbl
                                anchors.centerIn: parent
                                text: "Performance"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: Theme.text
                            }

                            MouseArea {
                                id: perfBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: PowerProfile.setMode("performance")
                            }
                        }
                    }
                }

                BackgroundFolderPage {
                    visible: Wallpapers.mode === "folder"
                    Layout.fillWidth: true
                    targetScreen: pop.targetScreen
                    popupOpen: pop.open
                    isCurrentPage: pop.open && !pop.showEffects && Wallpapers.mode === "folder"
                }

                BackgroundImagePage {
                    visible: Wallpapers.mode === "image"
                    Layout.fillWidth: true
                    popupOpen: pop.open
                    isCurrentPage: pop.open && !pop.showEffects && Wallpapers.mode === "image"
                }

                BackgroundAnimatedPage {
                    visible: Wallpapers.mode === "animated"
                    Layout.fillWidth: true
                    popupOpen: pop.open
                    isCurrentPage: pop.open && !pop.showEffects && Wallpapers.mode === "animated"
                    returnAsWindow: pop.effectiveAsWindow
                    returnScreen: pop.barWindow?.screen?.name ?? ""
                }

                BackgroundSolidPage {
                    visible: Wallpapers.mode === "solid"
                    Layout.fillWidth: true
                    returnAsWindow: pop.effectiveAsWindow
                    returnScreen: pop.barWindow?.screen?.name ?? ""
                }
            }
        }
    }
}
