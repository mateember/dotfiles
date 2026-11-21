import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.services

// One notification: icon, app + time, summary, body, action buttons, inline reply,
// optional auto-dismiss countdown bar (on toasts), and close button.
Rectangle {
    id: root

    required property Notification notification
    property bool toast: false
    property real progress: 1.0          // 1.0 -> 0.0 countdown bar (used when toast === true)
    property bool showProgress: false
    property bool replying: false
    readonly property bool hovered: hover.hovered
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical

    // Sanitize notification body to the safe Freedesktop markup subset (b, i, u, br, http(s)/mailto links).
    // Strips <img> (prevents remote tracking / local file reads) and escapes any other tags.
    function sanitizeBody(raw: string): string {
        const s = String(raw ?? "").replace(/[\uE000\uE001]/g, "");
        if (!s) return "";
        const saved = [];
        let out = s.replace(/<\/?[a-zA-Z][^>]*>/g, tag => {
            if (/^<\/?(b|i|u)\s*>$/i.test(tag)) {
                saved.push(tag.replace(/\s+/g, "").toLowerCase());
                return "\uE000" + (saved.length - 1) + "\uE001";
            }
            if (/^<br\s*\/?>$/i.test(tag)) {
                saved.push("<br/>");
                return "\uE000" + (saved.length - 1) + "\uE001";
            }
            if (/^<\/a\s*>$/i.test(tag)) {
                saved.push("</a>");
                return "\uE000" + (saved.length - 1) + "\uE001";
            }
            const am = tag.match(/^<a\s[^>]*href\s*=\s*(?:"([^"]*)"|'([^']*)')[^>]*>$/i);
            if (am) {
                const href = (am[1] ?? am[2] ?? "").trim();
                if (/^(https?:\/\/|mailto:)/i.test(href) && !/[<>"'\s]/.test(href)) {
                    saved.push('<a href="' + href.replace(/&(?!amp;)/g, "&amp;") + '">');
                    return "\uE000" + (saved.length - 1) + "\uE001";
                }
                return "";
            }
            if (/^<img\b/i.test(tag)) return "";
            return tag;
        });
        out = out.replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return out.replace(/\uE000(\d+)\uE001/g, (_, idx) => saved[Number(idx)] ?? "");
    }

    implicitHeight: layout.implicitHeight + 2 * Theme.spaceXs + (showProgress ? 3 : 0)
    radius: Theme.radiusS
    color: root.toast ? Theme.notificationsBg : (hover.hovered ? Theme.componentHover : Theme.component)
    border.width: root.toast ? Theme.popupBorderWidth : 0
    border.color: root.critical ? Theme.destructive : Theme.popupBorder
    clip: true

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: e => {
            if (e.button === Qt.MiddleButton) Notifs.dismiss(root.notification);
            else if (!root.replying) Notifs.activate(root.notification);
        }
    }

    RowLayout {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Theme.spaceXs
        }
        spacing: Theme.spaceXs

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.radiusS
                color: "transparent"
                visible: img.status === Image.Ready
                Image {
                    id: img
                    anchors.fill: parent
                    source: Notifs.iconSource(root.notification)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 80
                    sourceSize.height: 80
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                icon: root.critical ? "warning" : "notifications"
                size: 26
                color: root.critical ? Theme.destructive : Theme.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.notification.appName || "Notification"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
                StyledText {
                    text: Notifs.timeText(root.notification)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
                IconButton {
                    icon: "close"
                    iconSize: 16
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: Notifs.dismiss(root.notification)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification.summary
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sanitizeBody(root.notification.body)
                color: Theme.textDim
                wrapMode: Text.Wrap
                maximumLineCount: root.toast ? 4 : 8
                elide: Text.ElideRight
                textFormat: Text.StyledText
                linkColor: Theme.accent
                onLinkActivated: link => {
                    if (/^(https?:\/\/|mailto:)/i.test(link)) Qt.openUrlExternally(link);
                }
            }

            // Action buttons + Inline Reply toggle
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceXxxs
                spacing: Theme.spaceXxxs
                visible: actions.count > 0 || (root.notification.hasInlineReply && !root.replying)

                Rectangle {
                    visible: root.notification.hasInlineReply && !root.replying
                    implicitWidth: replyRow.implicitWidth + 2 * Theme.spaceXs
                    implicitHeight: 28
                    radius: height / 2
                    color: replyBtnMouse.containsMouse ? Theme.accentHover : Theme.alpha(Theme.accent, 0.22)
                    border.width: 1
                    border.color: Theme.alpha(Theme.accent, 0.55)

                    RowLayout {
                        id: replyRow
                        anchors.centerIn: parent
                        spacing: 4
                        Icon { icon: "reply"; size: 15; color: replyBtnMouse.containsMouse ? Theme.fgOnAccent : Theme.accent }
                        StyledText {
                            text: "Reply"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: replyBtnMouse.containsMouse ? Theme.fgOnAccent : Theme.accent
                        }
                    }

                    MouseArea {
                        id: replyBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.replying = true;
                            Qt.callLater(() => replyInput.focusInput());
                        }
                    }
                }

                Repeater {
                    id: actions
                    model: root.notification.actions.filter(a => a.identifier !== "default" && a.identifier !== "inline-reply")
                    delegate: Rectangle {
                        required property NotificationAction modelData
                        implicitWidth: label.implicitWidth + 2 * Theme.spaceXs
                        implicitHeight: 28
                        radius: height / 2
                        color: actionMouse.containsMouse ? Theme.buttonHover : Theme.button
                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifs.invokeAction(root.notification, parent.modelData)
                        }
                    }
                }
            }

            // Inline Reply input field (`inline-reply` freedesktop spec)
            RowLayout {
                visible: root.notification.hasInlineReply && root.replying
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceXxxs
                spacing: Theme.spaceXxxs

                TextField {
                    id: replyInput
                    Layout.fillWidth: true
                    implicitHeight: 34
                    placeholder: root.notification.inlineReplyPlaceholder || "Type a reply…"
                    onAccepted: {
                        const msg = text.trim();
                        if (msg !== "") {
                            text = "";
                            root.replying = false;
                            Notifs.sendReply(root.notification, msg);
                        }
                    }
                    input.Keys.onEscapePressed: {
                        text = "";
                        root.replying = false;
                    }
                }

                IconButton {
                    icon: "send"
                    highlighted: replyInput.text.trim() !== ""
                    implicitWidth: 32
                    implicitHeight: 32
                    iconSize: 17
                    onClicked: {
                        const msg = replyInput.text.trim();
                        if (msg !== "") {
                            replyInput.text = "";
                            root.replying = false;
                            Notifs.sendReply(root.notification, msg);
                        }
                    }
                }
            }
        }
    }

    // Subtle auto-dismiss countdown progress bar along the bottom edge of toasts
    Rectangle {
        visible: root.showProgress
        anchors {
            left: parent.left
            bottom: parent.bottom
        }
        height: 2.5
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        color: root.critical ? Theme.destructive : Theme.alpha(Theme.accent, 0.78)
    }
}
