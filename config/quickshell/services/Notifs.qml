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

    // Focus matching Hyprland window (or open referenced file path) when a notification is clicked.
    function focusAppOrPath(n) {
        const entry = (n.desktopEntry || "").trim();
        const appName = (n.appName || "").trim();
        const icon = (n.appIcon || "").trim();
        const body = (n.body || "").trim();
        const summary = (n.summary || "").trim();

        Quickshell.execDetached([
            "python3", "-c",
            `
import json, os, re, subprocess, sys
entry, app_name, icon, summary, body = sys.argv[1:6]

# 1. Try to find and focus a matching Hyprland window
try:
    out = subprocess.check_output(["hyprctl", "clients", "-j"], text=True, timeout=2)
    clients = json.loads(out)
except Exception:
    clients = []

candidates = []
for s in (entry, app_name, icon):
    s_clean = s.lower().strip()
    if s_clean:
        candidates.append(s_clean)
        # Also last segment of reverse-DNS desktop entry (e.g. org.gnome.Calendar -> calendar)
        if "." in s_clean:
            candidates.append(s_clean.split(".")[-1])

aliases = {
    "brave": ["brave-browser", "brave"],
    "discord": ["discord", "vesktop", "webcord"],
    "telegram": ["org.telegram.desktop", "telegramdesktop"],
    "spotify": ["spotify"],
    "files": ["org.gnome.nautilus", "nautilus", "thunar"],
    "calendar": ["org.gnome.calendar"],
}
for c in list(candidates):
    for k, vals in aliases.items():
        if k in c:
            candidates.extend(vals)

best_addr = None
for cl in clients:
    if not cl.get("mapped") or cl.get("hidden"):
        continue
    w_class = (cl.get("class") or "").lower()
    w_init = (cl.get("initialClass") or "").lower()
    w_title = (cl.get("title") or "").lower()
    for cand in candidates:
        if not cand or cand in ("notify-send", "notification", "quickshell"):
            continue
        if cand == w_class or cand == w_init or cand in w_class or (w_class and w_class in cand):
            best_addr = cl.get("address")
            break
    if best_addr:
        break

if best_addr:
    subprocess.run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{best_addr}" }})'], timeout=2)
    sys.exit(0)

# 2. If notification body/summary has an existing local path (e.g. Screenshot / Recording / USB), open it
for text in (body, summary):
    m = re.search(r"(/home/[^\\s()\"'<>]+|/run/media/[^\\s()\"'<>]+)", text)
    if m:
        p = m.group(1)
        if os.path.exists(p):
            subprocess.Popen(["xdg-open", p])
            sys.exit(0)
`,
            entry, appName, icon, summary, body
        ]);
    }

    // Clicking a notification runs its default action (if any), focuses the source app/window,
    // closes the notification center popup if open, and dismisses the notification.
    function activate(n) {
        if (!n) return;
        Popups.close();
        const def = n.actions.find(a => a.identifier === "default")
                 || (n.actions.length === 1 ? n.actions[0] : null);
        if (def) def.invoke();
        focusAppOrPath(n);
        dismiss(n);
    }

    // Invoke a specific action button on a notification and focus its app window.
    function invokeAction(n, action) {
        if (!n || !action) return;
        Popups.close();
        action.invoke();
        focusAppOrPath(n);
        dismiss(n);
    }

    // Seconds the toast stays up before fading out (4.5s default; 10s for critical).
    function timeoutFor(n): real {
        if (!n) return 4.5;
        if (n.urgency === NotificationUrgency.Critical) return 10;
        let t = n.expireTimeout;
        if (t <= 0) return 4.5;
        // FreeDesktop expire_timeout is sometimes passed in milliseconds (e.g. 5000)
        if (t > 100) t = t / 1000.0;
        return Math.max(3.0, Math.min(t, 6.0));
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
