import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Date/time like "Sat, Oct 24, 15:52". Click opens a month calendar with calendar events
// (services/CalendarEvents.qml): dots on days with events, the selected day's agenda, "Next up".
BarButton {
    id: root

    horizontalPadding: Theme.spaceXs
    active: pop.open
    onClicked: pop.toggle()

    StyledText {
        text: Time.format(Config.clockFormat)
        font.pixelSize: Theme.barFontSize
    }

    Popup {
        id: pop
        name: "calendar"
        anchorItem: root
        contentWidth: 300

        property int month: Time.date.getMonth()
        property int year: Time.date.getFullYear()
        property date selected: new Date()
        readonly property var dayEvents: CalendarEvents.eventsOn(selected)
        readonly property int maxRows: 6

        onOpenChanged: if (open) {
            month = Time.date.getMonth(); year = Time.date.getFullYear(); selected = Time.date;
            CalendarEvents.viewYear = year; CalendarEvents.viewMonth = month;
            CalendarEvents.refresh();
        }
        onMonthChanged: CalendarEvents.viewMonth = month
        onYearChanged: CalendarEvents.viewYear = year

        function shift(d: int) {
            let m = month + d, y = year;
            if (m < 0) { m = 11; y--; } else if (m > 11) { m = 0; y++; }
            month = m; year = y;
        }

        function sameDay(a: date, b: date): bool {
            return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
        }

        function hm(d: date): string { return Time.locale.toString(d, "HH:mm"); }

        // "Today" / "Tomorrow" / "Monday, October 26"
        function dayTitle(d: date): string {
            const t = new Date(Time.date.getFullYear(), Time.date.getMonth(), Time.date.getDate());
            const diff = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - t) / 86400000);
            if (diff === 0) return "Today";
            if (diff === 1) return "Tomorrow";
            if (diff === -1) return "Yesterday";
            return Time.locale.toString(d, "dddd, MMMM d");
        }

        // Time column of an agenda row, relative to the selected day.
        function timeText(e: var): string {
            if (e.kind === "task") return e.allday ? "Due" : "Due " + hm(e.start);
            if (e.allday) return "All day";
            const s = sameDay(e.start, selected) ? hm(e.start) : "…";
            const en = sameDay(e.end, selected) ? hm(e.end) : "…";
            return s + "–" + en;
        }

        // "Now: Lab 1 · until 12:00" / "Next: Lab 1 · 08:15 tomorrow" / "in 25 min"
        function nextText(e: var): string {
            const now = Time.date;
            if (e.start <= now && e.kind !== "task") return "Now · until " + hm(e.end);
            const mins = Math.round((e.start - now) / 60000);
            if (mins < 60) return "in " + Math.max(mins, 1) + " min";
            if (sameDay(e.start, now)) return hm(e.start);
            const t = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
            if (sameDay(e.start, t)) return "tomorrow " + hm(e.start);
            return Time.locale.toString(e.start, "ddd, MMM d") + " " + hm(e.start);
        }

        function openCalendar() {
            Popups.close();
            Quickshell.execDetached(["gnome-calendar"]);
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                text: Time.format("dddd")
                color: Theme.textDim
            }
            StyledText {
                text: Time.format("MMMM d, yyyy")
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
            }
        }

        // ---- Next up ----
        ListItem {
            id: nextItem
            visible: CalendarEvents.nextUp !== null
            Layout.topMargin: Theme.spaceXxs
            readonly property var ev: CalendarEvents.nextUp
            icon: ev?.kind === "task" ? "task_alt" : "event_upcoming"
            text: ev?.title ?? ""
            subtext: ev ? pop.nextText(ev) + (ev.location ? " · " + ev.location : "") : ""
            onClicked: pop.openCalendar()
            Rectangle {
                width: 8; height: 8; radius: 4
                color: nextItem.ev?.color ?? "transparent"
            }
        }

        Separator {}

        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: Time.locale.standaloneMonthName(pop.month) + " " + pop.year
                font.weight: Font.DemiBold
            }
            AppButton { icon: "calendar_month"; command: ["gnome-calendar"] }
            AppButton { command: ["cosmic-settings", "date-time"] }
            IconButton { icon: "chevron_left"; onClicked: pop.shift(-1) }
            IconButton { icon: "chevron_right"; onClicked: pop.shift(1) }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: StyledText {
                required property string shortName
                text: shortName.slice(0, 2)
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textDim
            }
        }

        MonthGrid {
            id: grid
            Layout.fillWidth: true
            month: pop.month
            year: pop.year
            locale: Time.locale
            spacing: 2

            delegate: Item {
                id: day
                required property var model
                readonly property bool today: model.today
                readonly property bool isSelected: pop.sameDay(model.date, pop.selected)
                // Up to 3 distinct calendar colors for the dots.
                readonly property var colors: {
                    const out = [];
                    for (const e of CalendarEvents.byDay[CalendarEvents.key(model.date)] ?? [])
                        if (out.indexOf(String(e.color)) < 0 && out.length < 3) out.push(String(e.color));
                    return out;
                }
                implicitWidth: 36
                implicitHeight: 36

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                    width: 30
                    height: 30
                    radius: 15
                    color: day.today ? Theme.accent
                         : dayMouse.containsMouse ? Theme.componentHover : "transparent"
                    border.width: day.isSelected && !day.today ? 1.5 : 0
                    border.color: Theme.accent
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1 + (30 - height) / 2
                    text: day.model.day
                    color: day.today ? Theme.fgOnAccent : Theme.text
                    font.weight: day.today ? Font.Bold : Font.Normal
                    opacity: day.model.month === grid.month ? 1 : 0.35
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 0
                    spacing: 2
                    opacity: day.model.month === grid.month ? 1 : 0.35
                    Repeater {
                        model: day.colors
                        Rectangle {
                            required property string modelData
                            width: 4; height: 4; radius: 2
                            color: modelData
                        }
                    }
                }
                MouseArea {
                    id: dayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.selected = day.model.date
                    onDoubleClicked: pop.openCalendar()
                }
            }
        }

        Separator {}

        // ---- Agenda for the selected day ----
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: pop.dayTitle(pop.selected)
                font.weight: Font.DemiBold
            }
            StyledText {
                visible: CalendarEvents.stale
                text: "offline"
                color: Theme.textDim
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        StyledText {
            visible: pop.dayEvents.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceXxxs
            text: CalendarEvents.ready ? "No events" : "Loading…"
            color: Theme.textDim
        }

        Repeater {
            model: pop.dayEvents.slice(0, pop.maxRows)
            delegate: Rectangle {
                id: row
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: col.implicitHeight + 2 * Theme.spaceXxs
                radius: Theme.radiusS
                color: rowMouse.containsMouse ? Theme.componentHover : "transparent"

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pop.openCalendar()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceXxs
                    anchors.rightMargin: Theme.spaceXxs
                    spacing: Theme.spaceXxs

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.topMargin: Theme.spaceXxs
                        Layout.bottomMargin: Theme.spaceXxs
                        implicitWidth: 3
                        radius: 1.5
                        color: row.modelData.color
                    }
                    StyledText {
                        Layout.preferredWidth: 78
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Theme.spaceXxs
                        text: pop.timeText(row.modelData)
                        color: Theme.textDim
                        font.pixelSize: Theme.fontSizeSmall
                        font.features: { "tnum": 1 }
                    }
                    ColumnLayout {
                        id: col
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spaceXxxs
                            Icon {
                                visible: row.modelData.kind === "task"
                                icon: "task_alt"
                                size: Theme.fontSize
                                color: Theme.textDim
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: row.modelData.title
                                elide: Text.ElideRight
                            }
                        }
                        StyledText {
                            visible: text !== ""
                            Layout.fillWidth: true
                            text: row.modelData.location
                            color: Theme.textDim
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        StyledText {
            visible: pop.dayEvents.length > pop.maxRows
            Layout.leftMargin: Theme.spaceXxs
            text: "+" + (pop.dayEvents.length - pop.maxRows) + " more"
            color: Theme.textDim
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
