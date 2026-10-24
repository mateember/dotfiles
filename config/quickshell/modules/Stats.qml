import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// COSMIC Minimon-style modular system monitor in the bar + dropdown menu.
BarButton {
    id: root

    active: pop.open
    onClicked: button => button === Qt.LeftButton ? pop.toggle() : SystemStats.openSystemMonitor()

    readonly property var sensorDefs: [
        { id: "cpu",  title: "CPU",             color: "#2b79ff", fill: "#442b79ff" },
        { id: "temp", title: "CPU Temperature", color: "#d96b27", fill: "#55d96b27" },
        { id: "mem",  title: "Memory",          color: "#9b3be8", fill: "#559b3be8" },
        { id: "net",  title: "Network",         color: "#2ecc71", fill: "#442ecc71" },
        { id: "disk", title: "Disk",            color: "#00bcd4", fill: "#4400bcd4" },
        { id: "gpu",  title: "GPU",             color: "#e74c3c", fill: "#44e74c3c" }
    ]

    function sensorHistory(id: string): var {
        switch (id) {
            case "cpu":  return SystemStats.cpuHistory;
            case "temp": return SystemStats.tempHistory;
            case "mem":  return SystemStats.memHistory;
            case "net":  return SystemStats.netHistory;
            case "disk": return SystemStats.diskHistory;
            case "gpu":  return SystemStats.gpuHistory;
            default:     return [];
        }
    }

    function sensorFraction(id: string): real {
        switch (id) {
            case "cpu":  return SystemStats.cpu;
            case "temp": return Math.max(0, Math.min(1, (SystemStats.tempC - 25) / 75));
            case "mem":  return SystemStats.memTotalGiB > 0 ? SystemStats.memUsedGiB / SystemStats.memTotalGiB : 0;
            case "net":  {
                const a = SystemStats.netHistory;
                return a.length > 0 ? a[a.length - 1] : 0;
            }
            case "disk": {
                const a = SystemStats.diskHistory;
                return a.length > 0 ? a[a.length - 1] : 0;
            }
            case "gpu":  return SystemStats.gpu;
            default:     return 0;
        }
    }

    function sensorBarLabel(id: string): string {
        switch (id) {
            case "cpu":  return (SystemStats.cpu * 100).toFixed(1) + "%";
            case "temp": return Math.round(SystemStats.tempC) + "°C";
            case "mem":  return SystemStats.memUsedGiB.toFixed(1) + " GB";
            case "gpu":  return (SystemStats.gpu * 100).toFixed(1) + "%";
            default:     return "";
        }
    }

    function sensorRingLabel(id: string): string {
        switch (id) {
            case "cpu":  return String(Math.round(SystemStats.cpu * 100));
            case "temp": return String(Math.round(SystemStats.tempC));
            case "mem":  return SystemStats.memUsedGiB.toFixed(1);
            case "net":  return String(Math.round((SystemStats.netDownBps + SystemStats.netUpBps) / 1024));
            case "disk": return String(Math.round((SystemStats.diskReadBps + SystemStats.diskWriteBps) / 1048576));
            case "gpu":  return String(Math.round(SystemStats.gpu * 100));
            default:     return "";
        }
    }

    function sensorSummary(id: string): string {
        switch (id) {
            case "cpu":  return (SystemStats.cpu * 100).toFixed(2) + "%";
            case "temp": return Math.round(SystemStats.tempC) + "°C";
            case "mem":  return SystemStats.memUsedGiB.toFixed(1) + " GB / " + SystemStats.memTotalGiB.toFixed(2) + " GB";
            case "net":  return "↓ " + SystemStats.formatNetRate(SystemStats.netDownBps) + " ↑ " + SystemStats.formatNetRate(SystemStats.netUpBps);
            case "disk": return "W " + SystemStats.formatDiskRate(SystemStats.diskWriteBps) + " R " + SystemStats.formatDiskRate(SystemStats.diskReadBps);
            case "gpu":  return (SystemStats.gpu * 100).toFixed(2) + "% " + SystemStats.shmemGiB.toFixed(2) + " GB" + (SystemStats.gpuFreqMHz > 0 ? " · " + SystemStats.gpuFreqMHz + " MHz" : "");
            default:     return "";
        }
    }

    // Reusable sparkline graph box
    component SparkGraph: Rectangle {
        id: graphBox
        property var samples: []
        property color strokeColor: "#2b79ff"
        property color fillColor: "#442b79ff"
        property int tick: SystemStats.sampleTick

        radius: 4
        color: Qt.rgba(0.08, 0.08, 0.09, 0.92)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
        clip: true

        onTickChanged: canvas.requestPaint()
        onSamplesChanged: canvas.requestPaint()

        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 1
            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height;
                ctx.clearRect(0, 0, w, h);
                const arr = graphBox.samples || [];
                if (arr.length < 2) return;

                ctx.beginPath();
                for (let i = 0; i < arr.length; i++) {
                    const x = (i / (arr.length - 1)) * w;
                    const y = h - Math.max(0, Math.min(1, arr[i])) * (h - 2) - 1;
                    if (i === 0) ctx.moveTo(x, y);
                    else ctx.lineTo(x, y);
                }
                ctx.strokeStyle = graphBox.strokeColor;
                ctx.lineWidth = 1.4;
                ctx.stroke();

                ctx.lineTo(w, h);
                ctx.lineTo(0, h);
                ctx.closePath();
                ctx.fillStyle = graphBox.fillColor;
                ctx.fill();
            }
        }
    }

    // Reusable circular ring gauge (like minimon.png's circular gauges)
    component RingGauge: Item {
        id: ringBox
        property real value: 0
        property string label: ""
        property color strokeColor: "#e74c3c"
        property int tick: SystemStats.sampleTick

        implicitWidth: 24
        implicitHeight: 24

        onTickChanged: ringCanvas.requestPaint()
        onValueChanged: ringCanvas.requestPaint()

        Canvas {
            id: ringCanvas
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height;
                const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 2;
                ctx.clearRect(0, 0, w, h);

                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.14);
                ctx.lineWidth = 2;
                ctx.stroke();

                const v = Math.max(0.03, Math.min(1, ringBox.value));
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + v * Math.PI * 2);
                ctx.strokeStyle = ringBox.strokeColor;
                ctx.lineWidth = 2;
                ctx.stroke();
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: ringBox.label
            font.pixelSize: 8
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }

    // ---- Bar Row ----
    RowLayout {
        spacing: 5

        // Fallback icon if the user turns off every sensor in the bar
        Icon {
            visible: {
                for (const s of root.sensorDefs) {
                    if (SystemStats.sensorText(s.id) || SystemStats.sensorChart(s.id) !== "none")
                        return false;
                }
                return true;
            }
            icon: "monitoring"
        }

        Repeater {
            model: root.sensorDefs

            delegate: RowLayout {
                id: barSensor
                required property var modelData
                readonly property string sid: modelData.id
                readonly property bool showText: SystemStats.sensorText(sid)
                readonly property string chartMode: SystemStats.sensorChart(sid)

                visible: showText || chartMode !== "none"
                spacing: 3

                // Single-line text (CPU, Temp, Memory, GPU)
                StyledText {
                    visible: barSensor.showText && barSensor.sid !== "net" && barSensor.sid !== "disk"
                    text: root.sensorBarLabel(barSensor.sid)
                    font.pixelSize: Theme.barFontSize - 1
                    font.features: { "tnum": 1 }
                    color: barSensor.sid === "temp"
                        ? (SystemStats.tempC >= 90 ? Theme.destructive : SystemStats.tempC >= 80 ? Theme.warning : Theme.text)
                        : Theme.text
                }

                // Stacked 2-line text for Network / Disk (matching minimon.png)
                ColumnLayout {
                    visible: barSensor.showText && (barSensor.sid === "net" || barSensor.sid === "disk")
                    spacing: -2

                    StyledText {
                        text: barSensor.sid === "net"
                            ? ("↓ " + SystemStats.formatNetRate(SystemStats.netDownBps))
                            : ("W " + SystemStats.formatDiskRate(SystemStats.diskWriteBps))
                        font.pixelSize: 9
                        font.features: { "tnum": 1 }
                        Layout.alignment: Qt.AlignRight
                    }
                    StyledText {
                        text: barSensor.sid === "net"
                            ? ("↑ " + SystemStats.formatNetRate(SystemStats.netUpBps))
                            : ("R " + SystemStats.formatDiskRate(SystemStats.diskReadBps))
                        font.pixelSize: 9
                        font.features: { "tnum": 1 }
                        Layout.alignment: Qt.AlignRight
                    }
                }

                // Mini sparkline graph in bar
                SparkGraph {
                    visible: barSensor.chartMode === "graph"
                    implicitWidth: 21
                    implicitHeight: 20
                    samples: root.sensorHistory(barSensor.sid)
                    strokeColor: barSensor.modelData.color
                    fillColor: barSensor.modelData.fill
                }

                // Mini ring gauge in bar
                RingGauge {
                    visible: barSensor.chartMode === "ring"
                    value: root.sensorFraction(barSensor.sid)
                    label: root.sensorRingLabel(barSensor.sid)
                    strokeColor: barSensor.modelData.color
                }
            }
        }
    }

    // ---- Minimon Dropdown Popup ----
    Popup {
        id: pop
        name: "stats"
        anchorItem: root
        contentWidth: 360

        property string page: "" // "" = main menu, "general", or sensor id ("cpu", "temp", "mem", "net", "disk", "gpu")

        onOpenChanged: {
            if (!open) page = "";
        }

        // Top pill button ("System Monitor ↗" / "COSMIC Observatory ↗") matching minimon.png
        Rectangle {
            visible: pop.page === ""
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: obsRow.implicitWidth + 28
            implicitHeight: 34
            radius: 9
            color: obsMouse.containsMouse ? Theme.componentHover : Theme.component

            RowLayout {
                id: obsRow
                anchors.centerIn: parent
                spacing: 6

                StyledText {
                    text: SystemStats.monitorApp === "btop" ? "btop System Monitor" : "System Monitor"
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                }
                Icon {
                    icon: "open_in_new"
                    size: 16
                }
            }

            MouseArea {
                id: obsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    SystemStats.openSystemMonitor();
                    pop.close();
                }
            }
        }

        // Main menu card with divided rows (matching minimon.png)
        Rectangle {
            visible: pop.page === ""
            Layout.fillWidth: true
            implicitHeight: mainCol.implicitHeight + 8
            radius: Theme.radiusM
            color: Qt.rgba(1, 1, 1, 0.04)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.06)

            ColumnLayout {
                id: mainCol
                anchors.fill: parent
                anchors.margins: 4
                spacing: 0

                // Row 0: General settings
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Theme.radiusS
                    color: genHover.containsMouse ? Theme.componentHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceS
                        anchors.rightMargin: Theme.spaceS
                        spacing: Theme.spaceXs

                        StyledText {
                            Layout.fillWidth: true
                            text: "General settings"
                        }
                        Icon {
                            icon: "chevron_right"
                            size: 18
                            color: Theme.textDim
                        }
                    }

                    MouseArea {
                        id: genHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pop.page = "general"
                    }
                }

                // Sensor rows
                Repeater {
                    model: root.sensorDefs

                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.spaceXs
                            Layout.rightMargin: Theme.spaceXs
                            implicitHeight: 1
                            color: Theme.divider
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: Theme.radiusS
                            color: rowHover.containsMouse ? Theme.componentHover : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spaceS
                                anchors.rightMargin: Theme.spaceS
                                spacing: Theme.spaceXs

                                StyledText {
                                    text: modelData.title
                                }

                                Item { Layout.fillWidth: true }

                                StyledText {
                                    text: root.sensorSummary(modelData.id)
                                    font.features: { "tnum": 1 }
                                    color: Theme.text
                                }

                                Icon {
                                    icon: "chevron_right"
                                    size: 18
                                    color: Theme.textDim
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pop.page = modelData.id
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // Sub-page: Back header
        // =====================================================================
        RowLayout {
            visible: pop.page !== ""
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            IconButton {
                icon: "arrow_back"
                implicitWidth: 30
                implicitHeight: 30
                iconSize: 18
                onClicked: pop.page = ""
            }

            StyledText {
                Layout.fillWidth: true
                font.weight: Font.DemiBold
                font.pixelSize: Theme.fontSizeLarge
                text: {
                    if (pop.page === "general") return "General settings";
                    for (const s of root.sensorDefs)
                        if (s.id === pop.page) return s.title;
                    return "";
                }
            }
        }

        // =====================================================================
        // Sub-page: General settings
        // =====================================================================
        ColumnLayout {
            visible: pop.page === "general"
            Layout.fillWidth: true
            spacing: Theme.spaceS

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: genSettingsCol.implicitHeight + 2 * Theme.spaceS
                radius: Theme.radiusM
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    id: genSettingsCol
                    anchors.fill: parent
                    anchors.margins: Theme.spaceS
                    spacing: Theme.spaceS

                    // Refresh rate
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { Layout.fillWidth: true; text: "Update interval" }
                        Repeater {
                            model: [
                                { ms: 1000, label: "1s" },
                                { ms: 1500, label: "1.5s" },
                                { ms: 2000, label: "2s" },
                                { ms: 5000, label: "5s" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: SystemStats.interval === modelData.ms
                                implicitWidth: 42
                                implicitHeight: 26
                                radius: 13
                                color: active ? Theme.accent : Theme.component
                                StyledText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: active ? Theme.accentText : Theme.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SystemStats.interval = modelData.ms;
                                        SystemStats.saveConfig();
                                    }
                                }
                            }
                        }
                    }

                    Separator {}

                    // Network speed units
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { Layout.fillWidth: true; text: "Network units" }
                        Repeater {
                            model: [
                                { bits: true,  label: "bps (Kbps)" },
                                { bits: false, label: "B/s (KB/s)" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: SystemStats.netInBits === modelData.bits
                                implicitWidth: unitLbl.implicitWidth + 18
                                implicitHeight: 26
                                radius: 13
                                color: active ? Theme.accent : Theme.component
                                StyledText {
                                    id: unitLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: active ? Theme.accentText : Theme.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SystemStats.netInBits = modelData.bits;
                                        SystemStats.saveConfig();
                                    }
                                }
                            }
                        }
                    }

                    Separator {}

                    // System Monitor app
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText { Layout.fillWidth: true; text: "Monitor app" }
                        Repeater {
                            model: [
                                { id: "gnome-system-monitor", label: "System Monitor" },
                                { id: "btop",                 label: "btop" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: SystemStats.monitorApp === modelData.id
                                implicitWidth: appLbl.implicitWidth + 18
                                implicitHeight: 26
                                radius: 13
                                color: active ? Theme.accent : Theme.component
                                StyledText {
                                    id: appLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: active ? Theme.accentText : Theme.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SystemStats.monitorApp = modelData.id;
                                        SystemStats.saveConfig();
                                    }
                                }
                            }
                        }
                    }

                    Separator {}

                    ListItem {
                        icon: "restart_alt"
                        text: "Reset Minimon to defaults"
                        onClicked: SystemStats.resetConfig()
                    }
                }
            }
        }

        // =====================================================================
        // Sub-page: Sensor detail & bar configuration
        // =====================================================================
        ColumnLayout {
            visible: pop.page !== "" && pop.page !== "general"
            Layout.fillWidth: true
            spacing: Theme.spaceS

            readonly property var activeSensor: {
                for (const s of root.sensorDefs)
                    if (s.id === pop.page) return s;
                return root.sensorDefs[0];
            }

            // Large live history chart
            SparkGraph {
                Layout.fillWidth: true
                implicitHeight: 96
                samples: root.sensorHistory(parent.activeSensor.id)
                strokeColor: parent.activeSensor.color
                fillColor: parent.activeSensor.fill

                StyledText {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 8
                    text: root.sensorSummary(parent.parent.activeSensor.id)
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            // Controls card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: sensorCtrlCol.implicitHeight + 2 * Theme.spaceS
                radius: Theme.radiusM
                color: Qt.rgba(1, 1, 1, 0.04)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                ColumnLayout {
                    id: sensorCtrlCol
                    anchors.fill: parent
                    anchors.margins: Theme.spaceS
                    spacing: Theme.spaceS

                    // Toggle value text on bar
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: "Show value in bar"
                        }
                        Rectangle {
                            readonly property bool checked: SystemStats.sensorText(pop.page)
                            implicitWidth: 42
                            implicitHeight: 24
                            radius: 12
                            color: checked ? Theme.accent : Theme.component

                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.checked ? parent.width - width - 3 : 3
                                color: parent.checked ? Theme.accentText : Theme.text
                                Behavior on x { NumberAnimation { duration: Theme.animFast } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SystemStats.setSensorText(pop.page, !parent.checked)
                            }
                        }
                    }

                    Separator {}

                    // Select chart type on bar (Off / Graph / Ring)
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: "Chart in bar"
                        }
                        Repeater {
                            model: [
                                { mode: "none",  label: "Off" },
                                { mode: "graph", label: "Graph" },
                                { mode: "ring",  label: "Ring" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool active: SystemStats.sensorChart(pop.page) === modelData.mode
                                implicitWidth: modeLbl.implicitWidth + 20
                                implicitHeight: 26
                                radius: 13
                                color: active ? Theme.accent : Theme.component
                                StyledText {
                                    id: modeLbl
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: active ? Theme.accentText : Theme.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: SystemStats.setSensorChart(pop.page, modelData.mode)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
