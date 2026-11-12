import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import qs
import qs.components
import qs.services
import "../weather"

// Single image tab: native zenity file picker (including .webp conversion),
// recent images strip, and a virtualized in-popup folder gallery browser.
ColumnLayout {
    id: root

    property bool popupOpen: false
    property bool isCurrentPage: false

    spacing: Theme.spaceXxs

    readonly property string browseNorm: Wallpapers.normalizePath(Wallpapers.browseDir)
    readonly property string singleNorm: Wallpapers.normalizePath(Wallpapers.singleImagePath)
    readonly property bool isCurrentGif: Wallpapers.isGifPath(Wallpapers.singleImagePath)

    property var browseFiles: []

    function rebuildBrowseFiles() {
        const arr = [];
        for (let i = 0; i < browseModel.count; i++) {
            const url = String(browseModel.get(i, "fileUrl") || "");
            const name = String(browseModel.get(i, "fileName") || "");
            const path = String(browseModel.get(i, "filePath") || Wallpapers.urlToPath(url));
            if (url) arr.push({ name: name, path: path, url: url, isGif: Wallpapers.isGifPath(name) });
        }
        root.browseFiles = arr;
    }

    readonly property var filteredBrowseFiles: {
        const q = browseFilter.text.trim().toLowerCase();
        if (!q) return root.browseFiles;
        return root.browseFiles.filter(f => (f.name || "").toLowerCase().indexOf(q) >= 0);
    }

    FolderListModel {
        id: browseModel
        folder: Wallpapers.pathToUrl(Wallpapers.browseDir)
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.svg", "*.gif"]
        showDirs: false
        caseSensitive: false
        sortField: FolderListModel.Name
        onCountChanged: root.rebuildBrowseFiles()
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuildBrowseFiles()
    }

    // ---- Current Selection Card & Native Picker ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: selectedCol.implicitHeight + Theme.spaceXs * 2
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider

        ColumnLayout {
            id: selectedCol
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXxs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                ClippingRectangle {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 34
                    radius: Theme.radiusXs
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.componentDivider

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.resolvedSingleImageUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(160, 90)
                    }

                    Icon {
                        visible: !Wallpapers.resolvedSingleImageUrl
                        anchors.centerIn: parent
                        icon: "image"
                        size: 18
                        color: Theme.textDim
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        Layout.fillWidth: true
                        text: Wallpapers.singleImagePath ? Wallpapers.baseName(Wallpapers.singleImagePath) : "No single image chosen"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.DemiBold
                        color: Theme.textStrong
                        elide: Text.ElideMiddle
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Wallpapers.singleImagePath
                            ? Wallpapers.displayPath(Wallpapers.singleImagePath)
                            : "Supports JPG, PNG, SVG, GIF & WebP"
                        font.pixelSize: 11
                        color: Theme.textDim
                        elide: Text.ElideMiddle
                    }
                }

                Rectangle {
                    implicitHeight: 30
                    implicitWidth: pickBtnRow.implicitWidth + 16
                    radius: Theme.radiusXl
                    color: pickMouse.containsMouse ? Theme.accentHover : Theme.accent
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Row {
                        id: pickBtnRow
                        anchors.centerIn: parent
                        spacing: 5

                        Icon { anchors.verticalCenter: parent.verticalCenter; icon: "folder_open"; size: 15; color: Theme.fgOnAccent }
                        StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Browse File…"; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.DemiBold; color: Theme.fgOnAccent }
                    }

                    MouseArea {
                        id: pickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.pickImage()
                    }
                }
            }

            // ffmpeg conversion status or error banner
            StyledText {
                visible: Wallpapers.convertingMedia || Wallpapers.convertError !== ""
                Layout.fillWidth: true
                text: Wallpapers.convertingMedia ? "Converting image to compatible cache format…" : Wallpapers.convertError
                font.pixelSize: 11
                color: Wallpapers.convertingMedia ? Theme.accent : Theme.destructive
                wrapMode: Text.WordWrap
            }

            // GIF speed selector when current single image is an animated GIF
            OptionPills {
                visible: root.isCurrentGif && Wallpapers.mode === "image"
                Layout.fillWidth: true
                label: "GIF Speed"
                options: [
                    { value: 0.5, label: "0.5x" },
                    { value: 1.0, label: "1x" },
                    { value: 1.5, label: "1.5x" },
                    { value: 2.0, label: "2x" }
                ]
                currentValue: Math.round(Wallpapers.animSpeed * 2) / 2
                onPicked: val => Wallpapers.setAnimSpeed(val)
            }
        }
    }

    // ---- Recent Single Images Strip ----
    ColumnLayout {
        visible: Wallpapers.recentImages.length > 0
        Layout.fillWidth: true
        spacing: 4

        StyledText {
            text: "Recent"
            font.pixelSize: 11
            color: Theme.textDim
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            model: (root.popupOpen && root.isCurrentPage) ? Wallpapers.recentImages : []

            delegate: ClippingRectangle {
                required property string modelData
                readonly property bool isSel: Wallpapers.normalizePath(modelData) === root.singleNorm
                readonly property bool isWebp: modelData.toLowerCase().endsWith(".webp")

                width: 72
                height: 40
                radius: Theme.radiusXs
                color: Theme.surface2
                border.width: isSel ? 2 : 1
                border.color: isSel ? Theme.accent
                            : recMouse.containsMouse ? Theme.componentBorder
                            : Theme.componentDivider

                Image {
                    anchors.fill: parent
                    visible: !isWebp
                    source: Wallpapers.pathToUrl(modelData)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize: Qt.size(160, 90)
                }

                Icon {
                    visible: isWebp
                    anchors.centerIn: parent
                    icon: "image"
                    size: 16
                    color: Theme.textDim
                }

                MouseArea {
                    id: recMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Wallpapers.setSingleImage(modelData, true)
                }
            }
        }
    }

    // ---- Built-In Folder Gallery Browser ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxxs

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            contentWidth: browseChipRow.implicitWidth
            contentHeight: 28
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: browseChipRow
                height: 28
                spacing: Theme.spaceXxxs

                Repeater {
                    model: Wallpapers.recentFolders
                    delegate: Rectangle {
                        required property string modelData
                        readonly property string cleanPath: Wallpapers.normalizePath(modelData)
                        readonly property bool selected: cleanPath === root.browseNorm

                        height: 28
                        width: bChipRow.implicitWidth + 14
                        radius: Theme.radiusXl
                        color: selected ? Theme.accent
                             : bChipMouse.containsMouse ? Theme.componentHover
                             : Theme.component
                        border.width: 1
                        border.color: selected ? Theme.accent : Theme.componentDivider
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Row {
                            id: bChipRow
                            anchors.centerIn: parent
                            spacing: 4
                            Icon { anchors.verticalCenter: parent.verticalCenter; icon: "folder_open"; size: 14; color: selected ? Theme.fgOnAccent : Theme.textDim }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Wallpapers.baseName(cleanPath) || Wallpapers.displayPath(cleanPath)
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: selected ? Font.DemiBold : Font.Normal
                                color: selected ? Theme.fgOnAccent : Theme.text
                            }
                        }

                        MouseArea {
                            id: bChipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Wallpapers.setBrowseDir(cleanPath)
                        }
                    }
                }
            }
        }

        Rectangle {
            implicitHeight: 28
            implicitWidth: bAddRow.implicitWidth + 14
            radius: Theme.radiusXl
            color: bAddMouse.containsMouse ? Theme.componentHover : Theme.component
            border.width: 1
            border.color: Theme.componentDivider

            Row {
                id: bAddRow
                anchors.centerIn: parent
                spacing: 4
                Icon { anchors.verticalCenter: parent.verticalCenter; icon: "add"; size: 15; color: Theme.text }
                StyledText { anchors.verticalCenter: parent.verticalCenter; text: "Folder"; font.pixelSize: Theme.fontSizeSmall }
            }

            MouseArea {
                id: bAddMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpapers.pickBrowseFolder()
            }
        }
    }

    TextField {
        id: browseFilter
        Layout.fillWidth: true
        placeholder: "Filter " + Wallpapers.displayPath(Wallpapers.browseDir) + "…"
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 158
        radius: Theme.radiusS
        color: Theme.surface1
        border.width: 1
        border.color: Theme.componentDivider
        clip: true

        GridView {
            id: browseGrid
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            cacheBuffer: 160
            cellWidth: Math.max(80, Math.floor(width / 3))
            cellHeight: Math.max(54, Math.floor(cellWidth * 9 / 16) + 2)
            model: (root.popupOpen && root.isCurrentPage) ? root.filteredBrowseFiles : []

            delegate: Item {
                required property var modelData
                readonly property bool isSel: Wallpapers.normalizePath(modelData.path) === root.singleNorm

                width: browseGrid.cellWidth
                height: browseGrid.cellHeight

                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: Theme.radiusXs
                    color: Theme.bg
                    border.width: isSel ? 2 : 1
                    border.color: isSel ? Theme.accent
                                : bCellMouse.containsMouse ? Theme.componentBorder
                                : Theme.componentDivider

                    Image {
                        anchors.fill: parent
                        source: modelData.url
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(240, 135)
                    }

                    Rectangle {
                        visible: isSel
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 4
                        width: 18
                        height: 18
                        radius: 9
                        color: Theme.accent
                        Icon { anchors.centerIn: parent; icon: "check"; size: 13; color: Theme.fgOnAccent }
                    }

                    Rectangle {
                        visible: Boolean(modelData.isGif)
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 4
                        implicitHeight: 15
                        implicitWidth: gifTag.implicitWidth + 8
                        radius: Theme.radiusXs
                        color: Qt.rgba(0, 0, 0, 0.72)

                        StyledText {
                            id: gifTag
                            anchors.centerIn: parent
                            text: "GIF"
                            font.pixelSize: 9
                            font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }

                    MouseArea {
                        id: bCellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Wallpapers.setSingleImage(modelData.path, true)
                    }
                }
            }
        }

        ColumnLayout {
            visible: browseGrid.count === 0
            anchors.centerIn: parent
            width: parent.width - Theme.spaceM
            spacing: 4

            Icon { Layout.alignment: Qt.AlignHCenter; icon: "image"; size: 24; color: Theme.textDim }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: browseFilter.text.trim() ? "No matching images" : "No JPG/PNG/GIF images in this folder (use Browse File… for WebP)"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
        }
    }
}
