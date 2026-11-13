import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Compact live preview card inside ThemeSettingsWindow showing how the active
// bar, popup surface, typography, radii, toggles, and semantic colors harmonize.
Rectangle {
    id: root

    Layout.fillWidth: true
    implicitHeight: previewRow.implicitHeight + 2 * Theme.spaceXs
    radius: Theme.radiusM
    color: Theme.surface0
    border.width: 1
    border.color: Theme.divider

    RowLayout {
        id: previewRow
        anchors.fill: parent
        anchors.margins: Theme.spaceXs
        spacing: Theme.spaceXs

        // Mini bar + workspace + clock preview
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(24, Math.min(34, Theme.barHeight - 4))
                radius: Math.min(Theme.barRadius, height / 2)
                color: Theme.barBg
                border.width: Theme.barBorderWidth
                border.color: Theme.panelBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 6

                    Rectangle {
                        width: Math.min(20, parent.height - 6)
                        height: width
                        radius: width / 2
                        color: Theme.accent

                        StyledText {
                            anchors.centerIn: parent
                            text: "1"
                            font.pixelSize: Math.max(10, Theme.barFontSize - 4)
                            font.weight: Font.Bold
                            color: Theme.fgOnAccent
                        }
                    }

                    StyledText {
                        text: "2"
                        font.pixelSize: Math.max(10, Theme.barFontSize - 4)
                        color: Theme.text
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: "10:24"
                        font.pixelSize: Math.max(10, Theme.barFontSize - 3)
                        color: Theme.text
                    }

                    Icon {
                        icon: "wifi"
                        size: Math.max(12, Theme.barIconSize - 4)
                        color: Theme.text
                    }
                    Icon {
                        icon: "volume_up"
                        size: Math.max(12, Theme.barIconSize - 4)
                        color: Theme.accent
                    }
                }
            }

            // Semantic + surface chips
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: Math.min(Theme.radiusS, 14)
                    color: Theme.primary
                    border.width: Theme.popupBorderWidth
                    border.color: Theme.popupBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 6

                        StyledText {
                            text: Theme.fontFamily
                            font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                            color: Theme.textStrong
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        StyledText {
                            text: "Dim"
                            font.pixelSize: Math.max(10, Theme.fontSizeSmall - 1)
                            color: Theme.textDim
                        }
                    }
                }

                Repeater {
                    model: [
                        { label: "OK", c: Theme.success },
                        { label: "Warn", c: Theme.warning },
                        { label: "Err", c: Theme.destructive }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        implicitWidth: semLbl.implicitWidth + 12
                        implicitHeight: 24
                        radius: Math.min(Theme.radiusXs, 12)
                        color: Theme.alpha(modelData.c, 0.18)
                        border.width: 1
                        border.color: Theme.alpha(modelData.c, 0.55)

                        StyledText {
                            id: semLbl
                            anchors.centerIn: parent
                            text: modelData.label
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: modelData.c
                        }
                    }
                }
            }
        }

        // Mini interactive control sample
        Rectangle {
            Layout.preferredWidth: 168
            implicitHeight: 58
            radius: Math.min(Theme.radiusM, 18)
            color: Theme.secondary
            border.width: Theme.popupBorderWidth
            border.color: Theme.popupBorder

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 20
                        radius: Math.min(Theme.radiusS, 10)
                        color: Theme.accent
                        StyledText {
                            anchors.centerIn: parent
                            text: ThemeConfig.activeProfile?.name ?? "Default"
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: Theme.fgOnAccent
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 28
                        height: 16
                        radius: 8
                        color: Theme.accent
                        Rectangle {
                            width: 12; height: 12; radius: 6
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width - width - 2
                            color: Theme.fgOnAccent
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 4
                    radius: 2
                    color: Theme.componentHover
                    Rectangle {
                        width: parent.width * 0.65
                        height: parent.height
                        radius: 2
                        color: Theme.accent
                    }
                }
            }
        }
    }
}
