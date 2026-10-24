import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.components
import qs.services

// Date/time like "Sat, Oct 24, 15:52". Click opens a month calendar.
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
        onOpenChanged: if (open) { month = Time.date.getMonth(); year = Time.date.getFullYear(); }

        function shift(d: int) {
            let m = month + d, y = year;
            if (m < 0) { m = 11; y--; } else if (m > 11) { m = 0; y++; }
            month = m; year = y;
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
                implicitWidth: 36
                implicitHeight: 34

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: day.today ? Theme.accent : "transparent"
                }
                StyledText {
                    anchors.centerIn: parent
                    text: day.model.day
                    color: day.today ? Theme.fgOnAccent : Theme.text
                    font.weight: day.today ? Font.Bold : Font.Normal
                    opacity: day.model.month === grid.month ? 1 : 0.35
                }
            }
        }
    }
}
