import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "components"
import "pages"

// Unified native Quickshell GUI Settings application ("HCS — Settings").
// Designed for laptop use with both keyboard shortcuts (Ctrl+F search, Alt+Left/Right history,
// Ctrl+Tab page stepping, Escape back/close) and touch ergonomics (44-52px hit targets,
// smooth Flickable scrolling, and an adaptive collapsible drawer on narrow windows).
Scope {
    id: scopeRoot

    LazyLoader {
        id: winLoader
        active: SettingsState.open

        FloatingWindow {
            id: win

            title: "HCS — Settings"
            visible: SettingsState.open && !ThemeConfig.pickingColor
            color: "transparent"
            implicitWidth: 1060
            implicitHeight: 740
            minimumSize: Qt.size(640, 480)

            readonly property bool compactMode: width < 820
            property bool drawerOpen: false
            property int searchCursor: 0

            onVisibleChanged: {
                if (!visible && SettingsState.open && !ThemeConfig.pickingColor) {
                    SettingsState.close();
                }
            }

            onCompactModeChanged: if (!compactMode) drawerOpen = false

            readonly property var filteredPages: {
                const q = SettingsState.searchQuery.trim().toLowerCase();
                if (!q) return SettingsState.pages;
                return SettingsState.pages.filter(p => {
                    if (p.title.toLowerCase().includes(q)) return true;
                    if (p.subtitle.toLowerCase().includes(q)) return true;
                    if (p.id.toLowerCase().includes(q)) return true;
                    if (Array.isArray(p.keywords) && p.keywords.some(k => k.toLowerCase().includes(q))) return true;
                    return false;
                });
            }

            function groupedSidebarItems(): var {
                const q = SettingsState.searchQuery.trim();
                const list = win.filteredPages;
                if (q !== "") {
                    return list.map(p => ({ kind: "page", page: p }));
                }
                const out = [];
                for (const cat of SettingsState.categories) {
                    const items = list.filter(p => p.category === cat.id);
                    if (items.length === 0) continue;
                    out.push({ kind: "header", label: cat.label });
                    for (const p of items) out.push({ kind: "page", page: p });
                }
                return out;
            }

            function selectPageAndCloseDrawer(id: string) {
                SettingsState.selectPage(id, "");
                win.drawerOpen = false;
                contentFlick.contentY = 0;
            }

            function pageComponent(id: string): Component {
                switch (id) {
                    case "network":       return compNetwork;
                    case "bluetooth":     return compBluetooth;
                    case "phone":         return compPhone;
                    case "appearance":    return compAppearance;
                    case "background":    return compBackground;
                    case "panel":         return compPanel;
                    case "displays":      return compDisplays;
                    case "sound":         return compSound;
                    case "power":         return compPower;
                    case "desktop":       return compDesktop;
                    case "input":         return compInput;
                    case "notifications": return compNotifications;
                    case "weather":       return compWeather;
                    case "apps":          return compApps;
                    case "lock":          return compLock;
                    case "about":         return compAbout;
                    default:              return compNetwork;
                }
            }

            Component { id: compNetwork;       NetworkPage {} }
            Component { id: compBluetooth;     BluetoothPage {} }
            Component { id: compPhone;         PhonePage {} }
            Component { id: compAppearance;    AppearancePage {} }
            Component { id: compBackground;    BackgroundPage {} }
            Component { id: compPanel;         PanelPage {} }
            Component { id: compDisplays;      DisplaysPage {} }
            Component { id: compSound;         SoundPage {} }
            Component { id: compPower;         PowerPage {} }
            Component { id: compDesktop;       DesktopPage {} }
            Component { id: compInput;         InputKeybindsPage {} }
            Component { id: compNotifications; NotificationsPage {} }
            Component { id: compWeather;       WeatherDatePage {} }
            Component { id: compApps;          AppsServicesPage {} }
            Component { id: compLock;          LockSecurityPage {} }
            Component { id: compAbout;         AboutPage {} }

            // ---- Main Surface ----
            Rectangle {
                id: rootFrame
                anchors.fill: parent
                color: Theme.bg
                focus: true

                Component.onCompleted: rootFrame.forceActiveFocus()

                Keys.onPressed: e => {
                    const ctrl = Boolean(e.modifiers & Qt.ControlModifier);
                    const alt = Boolean(e.modifiers & Qt.AltModifier);
                    const shift = Boolean(e.modifiers & Qt.ShiftModifier);

                    if (ctrl && e.key === Qt.Key_F) {
                        if (win.compactMode) win.drawerOpen = true;
                        searchBox.focusInput();
                        e.accepted = true;
                    } else if (alt && e.key === Qt.Key_Left) {
                        SettingsState.goBack();
                        e.accepted = true;
                    } else if (alt && e.key === Qt.Key_Right) {
                        SettingsState.goForward();
                        e.accepted = true;
                    } else if (ctrl && (e.key === Qt.Key_Tab || e.key === Qt.Key_PageDown)) {
                        SettingsState.stepPage(shift ? -1 : 1);
                        contentFlick.contentY = 0;
                        e.accepted = true;
                    } else if (ctrl && (e.key === Qt.Key_Backtab || e.key === Qt.Key_PageUp)) {
                        SettingsState.stepPage(-1);
                        contentFlick.contentY = 0;
                        e.accepted = true;
                    } else if (e.key === Qt.Key_Escape) {
                        if (SettingsState.searchQuery !== "") {
                            SettingsState.searchQuery = "";
                            searchBox.text = "";
                        } else if (win.drawerOpen) {
                            win.drawerOpen = false;
                        } else {
                            SettingsState.close();
                        }
                        e.accepted = true;
                    }
                }

                // ---- Sidebar Component (pinned on wide screens, slide-over drawer on compact) ----
                Rectangle {
                    id: sidebar
                    z: win.compactMode ? 20 : 1
                    width: win.compactMode ? Math.min(286, parent.width - 48) : 254
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                    }
                    x: win.compactMode ? (win.drawerOpen ? 0 : -width - 4) : 0
                    Behavior on x { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }

                    color: Theme.primary

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceXs
                        spacing: Theme.spaceXxs

                        // App Title & Search
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            spacing: Theme.spaceXxs

                            Icon {
                                icon: "settings"
                                size: 22
                                color: Theme.accent
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: "Settings"
                                font.pixelSize: Theme.fontSizeLarge
                                font.weight: Font.Bold
                                color: Theme.textStrong
                            }
                            IconButton {
                                visible: win.compactMode
                                icon: "close"
                                onClicked: win.drawerOpen = false
                            }
                        }

                        TextField {
                            id: searchBox
                            Layout.fillWidth: true
                            implicitHeight: 38
                            placeholder: "Search settings… (Ctrl+F)"
                            text: SettingsState.searchQuery
                            onTextChanged: {
                                SettingsState.searchQuery = text;
                                win.searchCursor = 0;
                            }
                            input.Keys.onDownPressed: {
                                if (win.filteredPages.length > 0)
                                    win.searchCursor = (win.searchCursor + 1) % win.filteredPages.length;
                            }
                            input.Keys.onUpPressed: {
                                if (win.filteredPages.length > 0)
                                    win.searchCursor = (win.searchCursor - 1 + win.filteredPages.length) % win.filteredPages.length;
                            }
                            input.Keys.onReturnPressed: {
                                const target = win.filteredPages[win.searchCursor] || win.filteredPages[0];
                                if (target) win.selectPageAndCloseDrawer(target.id);
                            }
                            input.Keys.onEscapePressed: {
                                if (text !== "") {
                                    text = "";
                                    SettingsState.searchQuery = "";
                                } else {
                                    rootFrame.forceActiveFocus();
                                }
                            }
                        }

                        // Category / Page List
                        ListView {
                            id: sidebarList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds
                            pressDelay: 70
                            model: win.groupedSidebarItems()

                            delegate: Item {
                                id: navDelegate
                                required property var modelData
                                width: ListView.view.width
                                height: modelData.kind === "header" ? 30 : 44

                                // Section header
                                StyledText {
                                    visible: navDelegate.modelData.kind === "header"
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        bottom: parent.bottom
                                        leftMargin: 10
                                        bottomMargin: 4
                                    }
                                    text: (navDelegate.modelData.label || "").toUpperCase()
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.textDim
                                    elide: Text.ElideRight
                                }

                                // Page row (44px touch target)
                                Rectangle {
                                    visible: navDelegate.modelData.kind === "page"
                                    readonly property var pg: navDelegate.modelData.page ?? null
                                    readonly property bool active: pg !== null && SettingsState.activePage === pg.id
                                    readonly property bool searchSelected: SettingsState.searchQuery !== ""
                                        && pg !== null && (win.filteredPages[win.searchCursor]?.id ?? "") === pg.id

                                    anchors.fill: parent
                                    radius: Theme.radiusS
                                    color: active ? Theme.accent
                                         : searchSelected ? Theme.componentHover
                                         : (navMouse.pressed ? Theme.componentPressed
                                          : navMouse.containsMouse ? Theme.componentHover
                                          : "transparent")
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors {
                                            fill: parent
                                            leftMargin: 10
                                            rightMargin: 10
                                        }
                                        spacing: 10

                                        Icon {
                                            icon: parent.parent.pg ? parent.parent.pg.icon : ""
                                            filled: parent.parent.active
                                            size: 19
                                            color: parent.parent.active ? Theme.fgOnAccent : Theme.accent
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: parent.parent.pg ? parent.parent.pg.title : ""
                                            font.pixelSize: Theme.fontSize
                                            font.weight: parent.parent.active ? Font.DemiBold : Font.Normal
                                            color: parent.parent.active ? Theme.fgOnAccent : Theme.text
                                            elide: Text.ElideRight
                                        }
                                    }

                                    MouseArea {
                                        id: navMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: if (parent.pg) win.selectPageAndCloseDrawer(parent.pg.id)
                                    }
                                }
                            }
                        }

                        // Empty search state
                        StyledText {
                            visible: win.filteredPages.length === 0
                            Layout.fillWidth: true
                            Layout.margins: Theme.spaceXs
                            horizontalAlignment: Text.AlignHCenter
                            text: "No matching settings"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textDim
                        }
                    }

                    // Right divider hairline
                    Rectangle {
                        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                        width: 1
                        color: Theme.divider
                    }
                }

                // Scrim behind slide-over drawer in compact mode
                Rectangle {
                    visible: win.compactMode && win.drawerOpen
                    z: 15
                    anchors.fill: parent
                    color: Theme.shade
                    MouseArea {
                        anchors.fill: parent
                        onClicked: win.drawerOpen = false
                    }
                }

                // ---- Right Content Area ----
                ColumnLayout {
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        right: parent.right
                        left: parent.left
                        leftMargin: win.compactMode ? 0 : sidebar.width
                    }
                    spacing: 0

                    // Top Navigation Toolbar (touch-sized buttons)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 50
                        color: Theme.surface0

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: Theme.spaceXs
                                rightMargin: Theme.spaceXs
                            }
                            spacing: 6

                            IconButton {
                                visible: win.compactMode
                                icon: "menu"
                                implicitWidth: 38
                                implicitHeight: 38
                                onClicked: win.drawerOpen = !win.drawerOpen
                            }

                            IconButton {
                                icon: "arrow_back"
                                implicitWidth: 36
                                implicitHeight: 36
                                enabled: SettingsState.canGoBack
                                onClicked: SettingsState.goBack()
                            }

                            IconButton {
                                icon: "arrow_forward"
                                implicitWidth: 36
                                implicitHeight: 36
                                enabled: SettingsState.canGoForward
                                onClicked: SettingsState.goForward()
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                text: SettingsState.pageById(SettingsState.activePage).title
                                font.pixelSize: Theme.fontSize
                                font.weight: Font.DemiBold
                                color: Theme.textStrong
                                elide: Text.ElideRight
                            }

                            // Compact quick-search trigger when sidebar is collapsed
                            IconButton {
                                visible: win.compactMode
                                icon: "search"
                                implicitWidth: 36
                                implicitHeight: 36
                                onClicked: {
                                    win.drawerOpen = true;
                                    Qt.callLater(() => searchBox.focusInput());
                                }
                            }

                            IconButton {
                                icon: "close"
                                implicitWidth: 36
                                implicitHeight: 36
                                onClicked: SettingsState.close()
                            }
                        }

                        Rectangle {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 1
                            color: Theme.divider
                        }
                    }

                    // Scrollable Page Container (touch flick + wheel)
                    Flickable {
                        id: contentFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: pageHolder.implicitHeight + 2 * Theme.spaceM
                        boundsBehavior: Flickable.StopAtBounds
                        pressDelay: 70

                        Connections {
                            target: SettingsState
                            function onActivePageChanged() { contentFlick.contentY = 0; }
                        }

                        Item {
                            id: pageHolder
                            readonly property int maxContentW: 780
                            width: Math.min(maxContentW, contentFlick.width - 2 * Theme.spaceM)
                            x: Math.round((contentFlick.width - width) / 2)
                            y: Theme.spaceM
                            implicitHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0

                            Loader {
                                id: pageLoader
                                width: parent.width
                                sourceComponent: win.pageComponent(SettingsState.activePage)
                            }
                        }
                    }
                }
            }
        }
    }
}
