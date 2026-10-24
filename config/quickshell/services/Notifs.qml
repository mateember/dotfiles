pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// Notification daemon (replaces dunst / cosmic-notifications).
// Every notification is kept in `history` until dismissed; `toasts` are the ones currently
// shown as pop-ups. Do-not-disturb hides toasts except critical ones.
Singleton {
    id: root

    readonly property bool dnd: persist.dnd
    readonly property var history: (loader.item?.trackedNotifications.values ?? []).slice().reverse()   // newest first
    property var toasts: []
    property var arrival: ({})   // notification id → Date

    readonly property bool running: loader.item !== null

    function toggleDnd() { persist.dnd = !persist.dnd; }

    function removeToast(n) {
        root.toasts = root.toasts.filter(t => t !== n);
    }
    // Toast timed out: drop transient notifications, keep the rest in history.
    function toastTimedOut(n) {
        removeToast(n);
        if (n.transient) n.expire();
    }
    function dismiss(n) {
        removeToast(n);
        n.dismiss();
    }
    function clearAll() {
        for (const n of root.history) n.dismiss();
        root.toasts = [];
    }
    // Clicking a notification runs its default action (if any) and dismisses it.
    function activate(n) {
        const def = n.actions.find(a => a.identifier === "default");
        if (def) def.invoke();
        dismiss(n);
    }

    // Seconds the toast stays up. Critical stays until closed (0).
    function timeoutFor(n): real {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        return n.expireTimeout > 0 ? n.expireTimeout : 6;
    }

    function timeText(n): string {
        const t = root.arrival[n.id];
        if (!t) return "";
        const min = Math.floor((Date.now() - t.getTime()) / 60000);
        if (min < 1) return "now";
        if (min < 60) return min + " min ago";
        return Qt.formatTime(t, "HH:mm");
    }

    function iconSource(n): string {
        if (n.image) return n.image;
        const i = n.appIcon || n.desktopEntry || "";
        if (i === "") return "";
        if (i.startsWith("/")) return "file://" + i;
        if (i.startsWith("file://") || i.startsWith("image://")) return i;
        return Quickshell.iconPath(i, true);
    }

    PersistentProperties {
        id: persist
        reloadableId: "hcs-notifs"
        property bool dnd: false
    }

    // run.sh --no-notify skips the server so another daemon can keep the D-Bus name.
    LazyLoader {
        id: loader
        active: Config.notificationsEnabled

        NotificationServer {
            keepOnReload: true
            persistenceSupported: true
            bodySupported: true
            bodyMarkupSupported: true
            bodyHyperlinksSupported: true
            actionsSupported: true
            actionIconsSupported: true
            imageSupported: true

            onNotification: n => {
                n.tracked = true;
                const a = Object.assign({}, root.arrival);
                a[n.id] = new Date();
                root.arrival = a;
                if (!root.dnd || n.urgency === NotificationUrgency.Critical)
                    root.toasts = [n].concat(root.toasts.filter(t => t.id !== n.id)).slice(0, 5);
                n.closed.connect(() => root.removeToast(n));
            }
        }
    }
}
