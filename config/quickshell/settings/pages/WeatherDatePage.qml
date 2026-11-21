import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "../../modules/weather"
import "../components"

ColumnLayout {
    id: root

    spacing: Theme.spaceM

    property string tab: "weather"       // "weather" | "datetime"
    property string weatherSub: "hub"    // "hub" | "location" | "bar" | "popup" | "units"

    Component.onCompleted: {
        SystemManager.refreshTimeInfo();
        applySubTab(SettingsState.activeSubTab);
    }

    Connections {
        target: SettingsState
        function onActiveSubTabChanged() {
            if (SettingsState.activePage === "weather")
                root.applySubTab(SettingsState.activeSubTab);
        }
    }

    function applySubTab(s: string) {
        if (s === "datetime" || s === "clock" || s === "time" || s === "calendar") {
            root.tab = "datetime";
        } else if (s === "location" || s === "bar" || s === "popup" || s === "units") {
            root.tab = "weather";
            root.weatherSub = s;
        } else if (s === "weather") {
            root.tab = "weather";
            root.weatherSub = "hub";
        }
    }

    SettingsPageHeader {
        icon: root.tab === "datetime" ? "schedule" : "partly_cloudy_day"
        title: "Weather, Date & Time"
        subtitle: "Forecast data sources, bar/popup weather layout, clock format, and calendar sync"

        SettingsActionButton {
            visible: root.tab === "weather"
            icon: "refresh"
            text: Weather.loading ? "Refreshing…" : "Refresh Weather"
            buttonEnabled: !Weather.loading
            onClicked: Weather.refresh()
        }
    }

    SettingsPillGroup {
        selectedId: root.tab
        model: [
            { id: "weather",  label: "Weather Settings", icon: "partly_cloudy_day" },
            { id: "datetime", label: "Date, Time & Calendar", icon: "calendar_month" }
        ]
        onPicked: id => root.tab = id
    }

    // ---- Weather Settings (embeds existing modular Weather pages) ----
    ColumnLayout {
        visible: root.tab === "weather"
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        SettingsPillGroup {
            selectedId: root.weatherSub
            model: [
                { id: "hub",      label: "Overview" },
                { id: "location", label: "Location" },
                { id: "bar",      label: "Bar Pills" },
                { id: "popup",    label: "Popup" },
                { id: "units",    label: "Units" }
            ]
            onPicked: id => root.weatherSub = id
        }

        SettingsCard {
            WeatherSettingsHub {
                visible: root.weatherSub === "hub"
                Layout.fillWidth: true
                onNavigate: page => root.weatherSub = page
                onGoBack: root.weatherSub = "hub"
            }

            WeatherLocationPage {
                visible: root.weatherSub === "location"
                Layout.fillWidth: true
                onGoBack: root.weatherSub = "hub"
            }

            WeatherBarSettingsPage {
                visible: root.weatherSub === "bar"
                Layout.fillWidth: true
                onGoBack: root.weatherSub = "hub"
            }

            WeatherPopupSettingsPage {
                visible: root.weatherSub === "popup"
                Layout.fillWidth: true
                onGoBack: root.weatherSub = "hub"
            }

            WeatherUnitsSettingsPage {
                visible: root.weatherSub === "units"
                Layout.fillWidth: true
                onGoBack: root.weatherSub = "hub"
            }
        }
    }

    // ---- Date, Time & Calendar ----
    ColumnLayout {
        visible: root.tab === "datetime"
        Layout.fillWidth: true
        spacing: Theme.spaceM

        SettingsSection {
            title: "Clock Display"
            description: "Live preview: " + Time.format(SystemManager.clockFormat)

            SettingsRow {
                icon: "schedule"
                title: "24-Hour Format"
                subtitle: SystemManager.clockUse24h ? "15:45" : "3:45 PM"
                Toggle {
                    checked: SystemManager.clockUse24h
                    onToggled: SystemManager.setClockUse24h(!SystemManager.clockUse24h)
                }
            }

            SettingsRow {
                icon: "av_timer"
                title: "Show Seconds in Top Bar"
                subtitle: "Display live seconds next to hours and minutes"
                Toggle {
                    checked: SystemManager.clockShowSeconds
                    onToggled: SystemManager.setClockShowSeconds(!SystemManager.clockShowSeconds)
                }
            }

            SettingsRow {
                icon: "today"
                title: "Show Weekday & Date in Top Bar"
                subtitle: "Include weekday and calendar date beside the clock"
                Toggle {
                    checked: SystemManager.clockShowDate
                    onToggled: SystemManager.setClockShowDate(!SystemManager.clockShowDate)
                }
            }
        }

        SettingsSection {
            title: "System Timezone & NTP"

            SettingsRow {
                icon: "public"
                title: "Timezone"
                subtitle: SystemManager.timezone || "System default"
            }

            SettingsRow {
                icon: "sync"
                highlighted: SystemManager.ntpSynced
                title: "Automatic Network Time (NTP)"
                subtitle: SystemManager.ntpEnabled
                    ? (SystemManager.ntpSynced ? "Enabled · Clock synchronized" : "Enabled · Waiting for sync")
                    : "Disabled"
            }
        }

        SettingsSection {
            title: "Calendar Integration (EDS)"

            SettingsRow {
                icon: "calendar_month"
                title: "Evolution Data Server Events"
                subtitle: CalendarEvents.ready
                    ? (CalendarEvents.nextUp ? ("Next up: " + CalendarEvents.nextUp.title) : "Synced · No upcoming events")
                    : "Syncing calendar accounts…"

                SettingsActionButton {
                    icon: "refresh"
                    text: "Sync Now"
                    onClicked: CalendarEvents.refresh()
                }
                SettingsActionButton {
                    icon: "open_in_new"
                    text: "GNOME Calendar"
                    onClicked: Quickshell.execDetached(["gnome-calendar"])
                }
            }
        }
    }
}
