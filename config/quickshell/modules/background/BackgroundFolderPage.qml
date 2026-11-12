import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import "../weather"

// Folder slideshow tab: recent folder chips, Bing Daily fetch trigger,
// virtualized 3-column thumbnail grid with search filter, and slideshow controls.
ColumnLayout {
    id: root

    property string targetScreen: ""
    property bool popupOpen: false
    property bool isCurrentPage: false

    spacing: Theme.spaceXxs

    readonly property string activeUrl: Wallpapers.activeUrlForScreen(root.targetScreen)
    readonly property string currentFolderNorm: Wallpapers.normalizePath(Wallpapers.folderPath)
    readonly property string bingFolderNorm: Wallpapers.normalizePath(Config.home + "/Pictures/BingWallpaper")
    readonly property bool isBingFolder: currentFolderNorm === bingFolderNorm

    readonly property var defaultFolderSet: {
        const set = {};
        for (const f of Wallpapers.defaultFolders()) set[Wallpapers.normalizePath(f)] = true;
        return set;
    }

    readonly property var filteredFiles: {
        const files = Wallpapers.folderFiles;
        const q = filterInput.text.trim().toLowerCase();
        if (!q) return files;
        return files.filter(f => (f.name || "").toLowerCase().indexOf(q) >= 0);
    }

    // ---- Folder Chips & Browse ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxxs

        Flickable {
            id: folderStrip
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            contentWidth: folderChipRow.implicitWidth
            contentHeight: 28
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: folderChipRow
                height: 28
                spacing: Theme.spaceXxxs

                Repeater {
                    model: Wallpapers.recentFolders
                    delegate: Rectangle {
                        required property string modelData
                        readonly property string cleanPath: Wallpapers.normalizePath(modelData)
                        readonly property bool selected: cleanPath === root.currentFolderNorm
                        readonly property bool removable: !root.defaultFolderSet[cleanPath]

                        height: 28
                        width: chipRow.implicitWidth + 14
                        radius: Theme.radiusXl
                        color: selected ? Theme.accent
                             : chipMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        border.width: 1
                        border.color: selected ? Theme.accent : Theme.componentDivider
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 4

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: "folder_open"
                                size: 14
                                color: selected ? Theme.fgOnAccent : Theme.textDim
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Wallpapers.baseName(cleanPath) || Wallpapers.displayPath(cleanPath)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.fgOnAccent : Theme.text
                            }

                            Item {
                                visible: removable
                                width: 14
                                height: 14
                                anchors.verticalCenter: parent.verticalCenter

                                Icon {
                                    anchors.centerIn: parent
                                    icon: "close"
                                    size: 12
                                    color: selected ? Theme.fgOnAccent : Theme.textDim
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Wallpapers.removeRecentFolder(cleanPath)
                                }
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            anchors.rightMargin: removable ? 18 : 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.setFolder(cleanPath)
                        }
                    }
                }
            }
        }

        // Native zenity folder picker button
        Rectangle {
            implicitHeight: 28
            implicitWidth: browseRow.implicitWidth + 14
            radius: Theme.radiusXl
            color: browseMouse.containsMouse ? Theme.componentHover : Theme.component
            border.width: 1
            border.color: Theme.componentDivider

            Row {
                id: browseRow
                anchors.centerIn: parent
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; icon: "add"; size: 15; color: Theme.text }
                StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Browse"; font.pixelSize: Theme.fontSizeSmall }
            }

            MouseArea {
                id: browseMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpapers.pickFolder()
            }
        }

        // Bing daily fetcher button when browsing BingWallpaper
        Rectangle {
            visible: root.isBingFolder
            implicitHeight: 28
            implicitWidth: bingRow.implicitWidth + 14
            radius: Theme.radiusXl
            color: Wallpapers.bingFetching ? Theme.accentPressed
                 : bingMouse.containsMouse ? Theme.componentHover
                 : Theme.component
            border.width: 1
            border.color: Theme.componentDivider

            Row {
                id: bingRow
                anchors.centerIn: parent
                spacing: 4
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Wallpapers.bingFetching ? "refresh" : "cloud_download"
                    size: 15
                    color: Theme.accent
                }
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Wallpapers.bingFetching ? "Fetching" : "Bing"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.text
                }
            }

            MouseArea {
                id: bingMouse
                anchors.fill: parent
                enabled: !Wallpapers.bingFetching
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpapers.fetchBingNow()
            }
        }
    }

    // Active path + filter + Bing status
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        TextField {
            id: filterInput
            Layout.fillWidth: true
            placeholder: "Filter " + Wallpapers.displayPath(Wallpapers.folderPath) + "…"
        }

        StyledText {
            text: filterInput.text.trim()
                ? (root.filteredFiles.length + "/" + Wallpapers.count)
                : (Wallpapers.count + " files")
            font.pixelSize: 11
            color: Theme.textDim
        }
    }

    StyledText {
        visible: Wallpapers.bingStatus !== ""
        Layout.fillWidth: true
        text: Wallpapers.bingStatus
        font.pixelSize: 11
        color: Theme.accent
        elide: Text.ElideRight
    }

    // ---- Virtualized Thumbnail Gallery ----
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 172
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider
        clip: true

        GridView {
            id: thumbGrid
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            cacheBuffer: 160
            cellWidth: Math.max(80, Math.floor(width / 3))
            cellHeight: Math.max(54, Math.floor(cellWidth * 9 / 16) + 2)
            model: (root.popupOpen && root.isCurrentPage) ? root.filteredFiles : []

            delegate: Item {
                required property var modelData
                readonly property bool isCurrent: modelData.url === root.activeUrl

                width: thumbGrid.cellWidth
                height: thumbGrid.cellHeight

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: Theme.radiusXs
                    color: Theme.bg
                    border.width: isCurrent ? 2 : 1
                    border.color: isCurrent ? Theme.accent
                                : cellMouse.containsMouse ? Theme.componentBorder
                                : Theme.componentDivider

                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source: modelData.url
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(240, 135)
                    }

                    // Bottom-left active badge
                    Rectangle {
                        visible: isCurrent
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.accent

                        Icon {
                            anchors.centerIn: parent
                            icon: "check"
                            size: 13
                            color: Theme.fgOnAccent
                        }
                    }

                    // Top-left GIF tag
                    Rectangle {
                        visible: Boolean(modelData.isGif)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 4
                        implicitHeight: 15
                        implicitWidth: gifLbl.implicitWidth + 8
                        radius: Theme.radiusXs
                        color: Qt.rgba(0, 0, 0, 0.72)

                        StyledText {
                            id: gifLbl
                            anchors.centerIn: parent
                            text: "GIF"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.selectFolderImage(modelData.url, root.targetScreen)
                    }

                    // Top-right "Use as Single Image" quick button on hover
                    Rectangle {
                        visible: cellMouse.containsMouse || pinMouse.containsMouse
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 22
                        height: 22
                        radius: 11
                        color: pinMouse.containsMouse ? Theme.accent : Qt.rgba(0, 0, 0, 0.76)
                        border.width: 1
                        border.color: Theme.componentDivider

                        Icon {
                            anchors.centerIn: parent
                            icon: "image"
                            size: 13
                            color: pinMouse.containsMouse ? Theme.fgOnAccent : Theme.textStrong
                        }

                        MouseArea {
                            id: pinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.setSingleImage(modelData.path, true)
                        }
                    }
                }
            }
        }

        // Empty / loading overlay
        ColumnLayout {
            visible: thumbGrid.count === 0
            anchors.centerIn: parent
            width: parent.width - Theme.spaceM
            spacing: 4

            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: Wallpapers.scanningFolder ? "refresh" : "photo_library"
                size: 26
                color: Theme.textDim
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Wallpapers.scanningFolder ? "Scanning folder…"
                    : filterInput.text.trim() ? "No matching images in this folder"
                    : "No images found here — pick another folder or enable Subfolders"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
        }
    }

    // ---- Slideshow Controls Card ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: controlsCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: controlsCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            OptionPills {
                Layout.fillWidth: true
                label: "Interval"
                options: [
                    { value: 30,   label: "30s" },
                    { value: 60,   label: "1m" },
                    { value: 300,  label: "5m" },
                    { value: 900,  label: "15m" },
                    { value: 1800, label: "30m" },
                    { value: 3600, label: "1h" },
                    { value: 0,    label: "Manual" }
                ]
                currentValue: Wallpapers.intervalSec
                onPicked: val => Wallpapers.setIntervalSec(val)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText {
                    text: "Order"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }

                Rectangle {
                    implicitHeight: 26
                    implicitWidth: randRow.implicitWidth + 14
                    radius: Theme.radiusXl
                    color: Wallpapers.order === "random" ? Theme.accent : Theme.component
                    Row {
                        id: randRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { anchors.verticalCenter: parent.verticalCenter; icon: "shuffle"; size: 14; color: Wallpapers.order === "random" ? Theme.fgOnAccent : Theme.text }
                        StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Random"; font.pixelSize: Theme.fontSizeSmall; color: Wallpapers.order === "random" ? Theme.fgOnAccent : Theme.text }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.setOrder("random")
                    }
                }

                Rectangle {
                    implicitHeight: 26
                    implicitWidth: seqRow.implicitWidth + 14
                    radius: Theme.radiusXl
                    color: Wallpapers.order === "sequential" ? Theme.accent : Theme.component
                    Row {
                        id: seqRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { anchors.verticalCenter: parent.verticalCenter; icon: "schedule"; size: 14; color: Wallpapers.order === "sequential" ? Theme.fgOnAccent : Theme.text }
                        StyledText { anchors.verticalCenter: parent.verticalCenter; text: "In order"; font.pixelSize: Theme.fontSizeSmall; color: Wallpapers.order === "sequential" ? Theme.fgOnAccent : Theme.text }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.setOrder("sequential")
                    }
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                StyledText {
                    Layout.fillWidth: true
                    text: "Include subfolders"
                    font.pixelSize: Theme.fontSizeSmall
                }
                Toggle {
                    checked: Wallpapers.includeSubfolders
                    onToggled: Wallpapers.setIncludeSubfolders(!Wallpapers.includeSubfolders)
                }

                StyledText {
                    visible: Quickshell.screens.length > 1
                    text: "Sync screens"
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.leftMargin: Theme.spaceXxs
                }
                Toggle {
                    visible: Quickshell.screens.length > 1
                    checked: Wallpapers.syncScreens
                    onToggled: Wallpapers.setSyncScreens(!Wallpapers.syncScreens)
                }
            }
        }
    }
}
