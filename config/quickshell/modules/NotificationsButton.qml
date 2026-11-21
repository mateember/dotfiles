import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.components
import qs.services

// Notification center: grouped by application (expandable stacks), Do Not Disturb
// & Smart Auto-DND indicator, inline reply support, clear all, and media card.
// Middle click on the bar icon toggles Do Not Disturb.
BarButton {
    id: root

    active: pop.open
    onClicked: button => button === Qt.MiddleButton ? Notifs.toggleDnd() : pop.toggle()

    Icon {
        icon: Notifs.effectiveDnd ? "notifications_off" : (Notifs.history.length > 0 ? "notifications_unread" : "notifications")
        color: Notifs.effectiveDnd ? Theme.textDim : Theme.text
    }

    Popup {
        id: pop
        name: "notifications"
        anchorItem: root
        contentWidth: 388

        // Map of appKey -> bool for expanded notification stacks
        property var expandedGroups: ({})

        function isExpanded(key: string): bool {
            return Boolean(expandedGroups[key]);
        }
        function toggleGroup(key: string) {
            const next = Object.assign({}, expandedGroups);
            next[key] = !next[key];
            expandedGroups = next;
        }

        // Group history by appName while preserving newest-first group ordering
        readonly property var groupedHistory: {
            const map = {};
            const order = [];
            for (const n of Notifs.history) {
                const app = (n.appName || "Notification").trim() || "Notification";
                const key = app.toLowerCase();
                if (!map[key]) {
                    map[key] = { key: key, appName: app, items: [] };
                    order.push(key);
                }
                map[key].items.push(n);
            }
            return order.map(k => map[k]);
        }

        // Toasts would duplicate what the center shows.
        onOpenChanged: if (open) Notifs.toasts = []

        PopupHeader {
            title: "Notifications"
            IconButton {
                icon: "settings"
                onClicked: { Popups.close(); SettingsState.openPage("notifications", ""); }
            }
            IconButton {
                icon: "clear_all"
                enabled: Notifs.history.length > 0
                onClicked: Notifs.clearAll()
            }
        }

        ListItem {
            icon: "do_not_disturb_on"
            text: "Do not disturb"
            subtext: Notifs.smartDndActive && !Notifs.dnd ? ("Smart Auto-DND: " + Notifs.smartDndReason) : ""
            highlighted: Notifs.effectiveDnd
            onClicked: Notifs.toggleDnd()
            Toggle { checked: Notifs.dnd; onToggled: Notifs.toggleDnd() }
        }

        StyledText {
            visible: !Notifs.running
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
            text: "The notification server is off (HCS_NO_NOTIFY=1)."
        }

        MediaCard {}

        Separator {}

        StyledText {
            visible: Notifs.history.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            color: Theme.textDim
            Layout.topMargin: Theme.spaceXs
            Layout.bottomMargin: Theme.spaceXs
        }

        Flickable {
            visible: Notifs.history.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(groupsCol.implicitHeight, 540)
            clip: true
            contentWidth: width
            contentHeight: groupsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: groupsCol
                width: parent.width
                spacing: Theme.spaceXxs

                Repeater {
                    model: pop.groupedHistory

                    delegate: ColumnLayout {
                        id: grp
                        required property var modelData
                        readonly property bool isStack: modelData.items.length > 1
                        readonly property bool expanded: !isStack || pop.isExpanded(modelData.key)
                        readonly property Notification latest: modelData.items[0]

                        Layout.fillWidth: true
                        spacing: 4

                        // ---- Stack Header (only shown when app has >= 2 notifications) ----
                        Rectangle {
                            visible: grp.isStack
                            Layout.fillWidth: true
                            implicitHeight: stackHdrRow.implicitHeight + 14
                            radius: Theme.radiusS
                            color: stackMouse.containsMouse ? Theme.componentHover : Theme.surface1
                            border.width: 1
                            border.color: Theme.divider

                            MouseArea {
                                id: stackMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pop.toggleGroup(grp.modelData.key)
                            }

                            RowLayout {
                                id: stackHdrRow
                                anchors {
                                    fill: parent
                                    leftMargin: Theme.spaceXs
                                    rightMargin: Theme.spaceXxs
                                }
                                spacing: Theme.spaceXxs

                                Icon {
                                    icon: grp.expanded ? "expand_less" : "expand_more"
                                    size: 18
                                    color: Theme.accent
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: grp.modelData.appName
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    implicitWidth: Math.max(22, cntTxt.implicitWidth + 10)
                                    implicitHeight: 20
                                    radius: 10
                                    color: Theme.alpha(Theme.accent, 0.22)
                                    StyledText {
                                        id: cntTxt
                                        anchors.centerIn: parent
                                        text: String(grp.modelData.items.length)
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: Theme.accent
                                        font.features: { "tnum": 1 }
                                    }
                                }

                                IconButton {
                                    icon: "clear_all"
                                    iconSize: 16
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    onClicked: Notifs.dismissGroup(grp.modelData.key)
                                }
                            }
                        }

                        // Collapsed stack preview (latest notification + "+N more" subtle hint)
                        NotificationCard {
                            visible: grp.isStack && !grp.expanded
                            Layout.fillWidth: true
                            notification: grp.latest
                        }

                        // Single notification or expanded stack items
                        Repeater {
                            model: grp.expanded ? grp.modelData.items : []
                            delegate: NotificationCard {
                                required property Notification modelData
                                Layout.fillWidth: true
                                Layout.leftMargin: grp.isStack ? 8 : 0
                                notification: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
