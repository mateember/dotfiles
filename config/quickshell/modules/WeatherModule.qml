import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import "weather"

// Modular weather widget: customizable bar display + popup with summary, hourly strip,
// modular detail tiles, multi-day forecast, location search/auto-locate, and unit settings.
BarButton {
    id: root

    active: pop.open
    onClicked: button => {
        if (button === Qt.MiddleButton) {
            Weather.refresh();
        } else if (button === Qt.RightButton) {
            if (pop.open) {
                if (pop.page !== "settings") pop.goTo("settings");
                else pop.close();
            } else {
                pop.pendingInitialPage = "settings";
                pop.toggle();
            }
        } else {
            pop.toggle();
        }
    }

    WeatherBarContent {}

    Popup {
        id: pop
        name: "weather"
        anchorItem: root
        contentWidth: 360

        property string page: ""
        property var pageStack: []
        property string pendingInitialPage: ""

        function goTo(p: string) {
            if (page === p) return;
            pageStack = pageStack.concat([page]);
            page = p;
        }

        function goBack(): bool {
            if (pageStack.length > 0) {
                const prev = pageStack[pageStack.length - 1];
                pageStack = pageStack.slice(0, pageStack.length - 1);
                page = prev;
                return true;
            }
            if (page !== "") {
                page = "";
                return true;
            }
            return false;
        }

        backHandler: () => pop.goBack()

        Connections {
            target: Weather
            function onOpenPageRequested(screenName: string, pageName: string) {
                const myScreen = pop.barWindow?.screen?.name ?? "";
                if (screenName !== "" && myScreen !== screenName) return;
                pop.pendingInitialPage = pageName;
                if (pop.open) {
                    if (pageName !== "" && pop.page !== pageName) pop.goTo(pageName);
                    else { pop.page = pageName; pop.pageStack = []; }
                    pop.pendingInitialPage = "";
                } else {
                    Popups.open(pop.popupId);
                }
            }
        }

        onOpenChanged: {
            if (open) {
                page = pendingInitialPage;
                pageStack = [];
                pendingInitialPage = "";
                Weather.refresh();
            }
        }

        onVisibleChanged: {
            if (!visible && !open) {
                page = "";
                pageStack = [];
                pendingInitialPage = "";
                locationPage.resetTransient();
                settingsHub.resetConfirmation();
            }
        }

        // ---- Main Page: Header + Modular Forecast ----
        ColumnLayout {
            visible: pop.page === ""
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            PopupHeader {
                title: Weather.displayLocation
                showBack: pop.canGoBack
                backAction: () => pop.back()

                IconButton {
                    icon: "refresh"
                    enabled: !Weather.loading
                    opacity: Weather.loading ? 0.45 : 1
                    onClicked: Weather.refresh()
                }
                IconButton {
                    icon: WeatherConfig.autoLocate ? "my_location" : "location_on"
                    onClicked: pop.goTo("location")
                }
                IconButton {
                    icon: "settings"
                    onClicked: pop.goTo("settings")
                }
            }

            // Empty / first-fetch error state
            ColumnLayout {
                visible: !Weather.ready
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceXs
                Layout.bottomMargin: Theme.spaceXs
                spacing: Theme.spaceXs

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: Weather.loading ? "cloud_sync" : "cloud_off"
                    size: 36
                    color: Weather.loading ? Theme.accent : Theme.textDim
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    color: Theme.textDim
                    text: Weather.loading
                        ? ("Fetching weather for " + Weather.displayLocation + "…")
                        : (Weather.error !== "" ? Weather.error : "No weather data loaded yet")
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.spaceXs
                    visible: !Weather.loading
                    Rectangle {
                        implicitWidth: retryLbl.implicitWidth + 2 * Theme.spaceXs
                        implicitHeight: 30
                        radius: 15
                        color: retryMouse.containsMouse ? Theme.componentHover : Theme.component
                        StyledText { id: retryLbl; anchors.centerIn: parent; text: "Retry"; font.pixelSize: Theme.fontSizeSmall }
                        MouseArea { id: retryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Weather.refresh() }
                    }
                    Rectangle {
                        implicitWidth: locBtnLbl.implicitWidth + 2 * Theme.spaceXs
                        implicitHeight: 30
                        radius: 15
                        color: locBtnMouse.containsMouse ? Theme.accentHover : Theme.accent
                        StyledText { id: locBtnLbl; anchors.centerIn: parent; text: "Change location"; font.pixelSize: Theme.fontSizeSmall; color: Theme.fgOnAccent; font.weight: Font.DemiBold }
                        MouseArea { id: locBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.goTo("location") }
                    }
                }
            }

            // Scrollable modular sections (only scrolls when many sections/days exceed cap)
            Flickable {
                id: mainFlick
                visible: Weather.ready
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 590)
                contentWidth: width
                contentHeight: mainSectionsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Component { id: secHero; WeatherHeroSection {} }
                Component { id: secHourly; WeatherHourlySection {} }
                Component { id: secDetails; WeatherDetailsSection {} }
                Component { id: secDaily; WeatherDailySection {} }
                Component {
                    id: secFooter
                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Theme.fontSizeSmall
                        color: Weather.stale ? Theme.warning : Theme.textDim
                        elide: Text.ElideRight
                        text: {
                            const tStr = Weather.formatClockHHMM(Time.locale.toString(Weather.fetchedAt, "HH:mm"));
                            const prefix = Weather.stale ? "Offline, cached from " : "Updated ";
                            const srcLabel = Weather.activeSource === "hybrid" && Weather.stationName !== ""
                                ? (`HungaroMet (${Weather.stationName}) + Open-Meteo`)
                                : "Open-Meteo";
                            return prefix + tStr + " · " + srcLabel + (Weather.stale && Weather.error !== "" ? (" · " + Weather.error) : "");
                        }
                    }
                }

                function sectionComponent(id: string): Component {
                    switch (id) {
                        case "hero":    return secHero;
                        case "hourly":  return secHourly;
                        case "details": return secDetails;
                        case "daily":   return secDaily;
                        case "footer":  return secFooter;
                        default:        return null;
                    }
                }

                ColumnLayout {
                    id: mainSectionsCol
                    width: mainFlick.width
                    spacing: Theme.spaceXs

                    Repeater {
                        model: WeatherConfig.enabledPopupSections

                        delegate: ColumnLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: Theme.spaceXs

                            Separator {
                                visible: modelData.id === "daily" && index > 0
                            }

                            Loader {
                                Layout.fillWidth: true
                                sourceComponent: mainFlick.sectionComponent(modelData.id)
                            }
                        }
                    }

                    StyledText {
                        visible: WeatherConfig.enabledPopupSections.length === 0
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textDim
                        text: "All popup sections are hidden — open Settings to enable modules."
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ---- Settings Subpages ----
        WeatherSettingsHub {
            id: settingsHub
            visible: pop.page === "settings"
            onNavigate: p => pop.goTo(p)
            onGoBack: pop.goBack()
        }

        WeatherLocationPage {
            id: locationPage
            visible: pop.page === "location"
            popupRoot: pop
            onGoBack: pop.goBack()
        }

        WeatherBarSettingsPage {
            visible: pop.page === "bar"
            onGoBack: pop.goBack()
        }

        WeatherPopupSettingsPage {
            visible: pop.page === "popup"
            onGoBack: pop.goBack()
        }

        WeatherUnitsSettingsPage {
            visible: pop.page === "units"
            onGoBack: pop.goBack()
        }
    }
}
