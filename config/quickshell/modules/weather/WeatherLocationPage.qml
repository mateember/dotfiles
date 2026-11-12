import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Location settings: IP auto-locate toggle, Open-Meteo city search, saved cities, and custom coordinates.
ColumnLayout {
    id: root

    signal goBack()
    property var popupRoot: null

    property bool manualOpen: false
    property string manualError: ""

    function resetTransient() {
        searchInput.text = "";
        Weather.clearSearch();
        manualOpen = false;
        manualError = "";
        searchDebounce.stop();
    }

    function applyManualCoordinates() {
        const lat = Number(latField.text.trim().replace(",", "."));
        const lon = Number(lonField.text.trim().replace(",", "."));
        if (isNaN(lat) || lat < -90 || lat > 90) {
            manualError = "Latitude must be between -90 and 90";
            return;
        }
        if (isNaN(lon) || lon < -180 || lon > 180) {
            manualError = "Longitude must be between -180 and 180";
            return;
        }
        manualError = "";
        WeatherConfig.setLocation(nameField.text, "", lat, lon);
        manualOpen = false;
    }

    function openManualEditor() {
        manualOpen = !manualOpen;
        if (manualOpen) {
            nameField.text = WeatherConfig.locationName;
            latField.text = String(WeatherConfig.latitude);
            lonField.text = String(WeatherConfig.longitude);
            manualError = "";
        }
    }

    Layout.fillWidth: true
    spacing: Theme.spaceXs

    Timer {
        id: searchDebounce
        interval: 350
        onTriggered: Weather.searchLocations(searchInput.text)
    }

    PopupHeader {
        title: "Location"
        showBack: true
        backAction: () => root.goBack()
    }

    // ---- Auto-locate (IP) ----
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: autoRow.implicitHeight + 2 * Theme.spaceXs
        radius: Theme.radiusS
        color: Theme.component

        RowLayout {
            id: autoRow
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            spacing: Theme.spaceXs

            Icon {
                icon: "my_location"
                color: WeatherConfig.autoLocate ? Theme.accent : Theme.textDim
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    text: "Auto-locate by IP"
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: WeatherConfig.autoLocate
                        ? (Weather.detectedLocation !== ""
                            ? (Weather.detectedLocation + (Weather.detectedRegion !== "" ? ", " + Weather.detectedRegion : ""))
                            : (Weather.loading ? "Detecting location…" : "Using IP geolocation"))
                        : "Automatically follow your current network location"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
            }

            Toggle {
                checked: WeatherConfig.autoLocate
                onToggled: WeatherConfig.setAutoLocate(!WeatherConfig.autoLocate)
            }
        }
    }

    // ---- City Search ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        TextField {
            id: searchInput
            Layout.fillWidth: true
            placeholder: "Search city (e.g. Budapest, London)…"
            onTextChanged: {
                if (text.trim().length < 2) {
                    searchDebounce.stop();
                    Weather.clearSearch();
                } else {
                    searchDebounce.restart();
                }
            }
            onAccepted: {
                searchDebounce.stop();
                Weather.searchLocations(text);
            }
            input.Keys.onEscapePressed: {
                if (text !== "") {
                    text = "";
                    Weather.clearSearch();
                } else {
                    root.goBack();
                    if (root.popupRoot) Qt.callLater(() => root.popupRoot.ensureFocus());
                }
            }
        }

        IconButton {
            visible: searchInput.text !== ""
            icon: "close"
            onClicked: {
                searchInput.text = "";
                Weather.clearSearch();
                searchInput.focusInput();
            }
        }

        IconButton {
            icon: "search"
            highlighted: searchInput.text.trim().length >= 2
            onClicked: {
                searchDebounce.stop();
                Weather.searchLocations(searchInput.text);
            }
        }
    }

    // ---- Search Results ----
    StyledText {
        visible: Weather.searching || Weather.searchError !== ""
            || (searchInput.text.trim().length >= 2 && Weather.searchResults.length === 0)
        Layout.fillWidth: true
        font.pixelSize: Theme.fontSizeSmall
        color: Weather.searchError !== "" ? Theme.destructive : Theme.textDim
        text: Weather.searching ? "Searching cities…"
            : Weather.searchError !== "" ? Weather.searchError
            : "No matching cities found"
    }

    ListView {
        visible: Weather.searchResults.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 168)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Weather.searchResults

        delegate: ListItem {
            id: resRow
            required property var modelData
            readonly property bool isActive: !WeatherConfig.autoLocate
                && WeatherConfig.coordsMatch(WeatherConfig.latitude, WeatherConfig.longitude, modelData.lat, modelData.lon)
            readonly property bool isSaved: WeatherConfig.isLocationSaved(modelData.lat, modelData.lon)

            width: ListView.view.width
            icon: "location_on"
            iconFilled: isActive
            highlighted: isActive
            text: modelData.name
            subtext: [modelData.region, `${modelData.lat.toFixed(2)}°, ${modelData.lon.toFixed(2)}°`].filter(Boolean).join(" · ")
            onClicked: {
                WeatherConfig.setLocation(modelData.name, modelData.region, modelData.lat, modelData.lon);
                searchInput.text = "";
                Weather.clearSearch();
            }

            IconButton {
                icon: "star"
                filled: resRow.isSaved
                implicitWidth: 28
                implicitHeight: 28
                iconSize: 18
                onClicked: {
                    if (!resRow.isSaved)
                        WeatherConfig.saveLocation(resRow.modelData.name, resRow.modelData.region, resRow.modelData.lat, resRow.modelData.lon);
                }
            }
        }
    }

    Separator {}

    // ---- Saved Locations ----
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        StyledText {
            Layout.fillWidth: true
            text: "Saved locations"
            font.weight: Font.DemiBold
        }

        Rectangle {
            visible: !WeatherConfig.autoLocate
                && !WeatherConfig.isLocationSaved(WeatherConfig.latitude, WeatherConfig.longitude)
            implicitWidth: saveRow.implicitWidth + 2 * Theme.spaceXs
            implicitHeight: 24
            radius: 12
            color: saveMouse.pressed ? Theme.componentPressed
                 : saveMouse.containsMouse ? Theme.componentHover
                 : Theme.component
            RowLayout {
                id: saveRow
                anchors.centerIn: parent
                spacing: 3
                Icon { icon: "add"; size: 14; color: Theme.accent }
                StyledText { text: "Save current"; font.pixelSize: Theme.fontSizeSmall }
            }
            MouseArea {
                id: saveMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: WeatherConfig.saveLocation(
                    WeatherConfig.locationName,
                    WeatherConfig.locationRegion,
                    WeatherConfig.latitude,
                    WeatherConfig.longitude
                )
            }
        }
    }

    StyledText {
        visible: WeatherConfig.savedLocations.length === 0
        Layout.fillWidth: true
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.textDim
        text: "No saved cities — search above or save your current coordinates."
    }

    ListView {
        visible: WeatherConfig.savedLocations.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 148)
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: WeatherConfig.savedLocations

        delegate: ListItem {
            id: savedRow
            required property var modelData
            required property int index
            readonly property bool isActive: !WeatherConfig.autoLocate
                && WeatherConfig.coordsMatch(WeatherConfig.latitude, WeatherConfig.longitude, modelData.lat, modelData.lon)

            width: ListView.view.width
            icon: isActive ? "check" : "location_on"
            highlighted: isActive
            text: modelData.name
            subtext: [modelData.region, `${Number(modelData.lat).toFixed(2)}°, ${Number(modelData.lon).toFixed(2)}°`].filter(Boolean).join(" · ")
            onClicked: WeatherConfig.setLocation(modelData.name, modelData.region ?? "", modelData.lat, modelData.lon)

            IconButton {
                icon: "close"
                implicitWidth: 26
                implicitHeight: 26
                iconSize: 16
                onClicked: WeatherConfig.removeSavedLocation(savedRow.index)
            }
        }
    }

    Separator {}

    // ---- Manual Coordinates ----
    ListItem {
        icon: root.manualOpen ? "expand_less" : "expand_more"
        text: "Custom coordinates"
        subtext: WeatherConfig.autoLocate
            ? "Manual fallback coordinates"
            : `${WeatherConfig.locationName} (${WeatherConfig.latitude.toFixed(4)}°, ${WeatherConfig.longitude.toFixed(4)}°)`
        onClicked: root.openManualEditor()
    }

    ColumnLayout {
        visible: root.manualOpen
        Layout.fillWidth: true
        spacing: Theme.spaceXxs

        TextField {
            id: nameField
            Layout.fillWidth: true
            placeholder: "Display name (e.g. Home)"
            onAccepted: root.applyManualCoordinates()
            input.Keys.onEscapePressed: {
                root.manualOpen = false;
                if (root.popupRoot) Qt.callLater(() => root.popupRoot.ensureFocus());
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXxs

            TextField {
                id: latField
                Layout.fillWidth: true
                placeholder: "Latitude (-90..90)"
                onAccepted: root.applyManualCoordinates()
                input.Keys.onEscapePressed: {
                    root.manualOpen = false;
                    if (root.popupRoot) Qt.callLater(() => root.popupRoot.ensureFocus());
                }
            }

            TextField {
                id: lonField
                Layout.fillWidth: true
                placeholder: "Longitude (-180..180)"
                onAccepted: root.applyManualCoordinates()
                input.Keys.onEscapePressed: {
                    root.manualOpen = false;
                    if (root.popupRoot) Qt.callLater(() => root.popupRoot.ensureFocus());
                }
            }

            IconButton {
                icon: "check"
                highlighted: true
                onClicked: root.applyManualCoordinates()
            }
        }

        StyledText {
            visible: root.manualError !== ""
            Layout.fillWidth: true
            text: root.manualError
            color: Theme.destructive
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
