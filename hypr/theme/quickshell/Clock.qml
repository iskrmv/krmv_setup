// Clock.qml - bar shows HH:mm only; hover shows a floating popup with seconds + the whole month
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: clock
    required property var theme
    property bool suppressPopup: false      // true while the clock app is open
    signal clicked()
    implicitWidth: label.implicitWidth
    implicitHeight: 30

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var headers: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    function cells(d) {
        const y = d.getFullYear(), m = d.getMonth()
        const first = (new Date(y, m, 1).getDay() + 6) % 7   // week starts on Monday
        const n = new Date(y, m + 1, 0).getDate()
        const out = []
        for (let i = 0; i < first; i++) out.push(0)
        for (let i = 1; i <= n; i++) out.push(i)
        return out
    }

    SystemClock { id: minClock; precision: SystemClock.Minutes }
    SystemClock { id: secClock; enabled: area.containsMouse; precision: SystemClock.Seconds }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(minClock.date, "HH:mm")
        color: clock.theme.icon
        font.family: clock.theme.font
        font.pixelSize: clock.theme.size
    }

    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: clock.clicked() }

    PopupWindow {
        visible: area.containsMouse && !clock.suppressPopup
        anchor.item: clock
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: 7 * 34 + 32
        implicitHeight: col.implicitHeight + 32 + 6
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 6
            radius: 0
            color: clock.theme.bg
            border.color: clock.theme.muted
            border.width: 1

            ColumnLayout {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(secClock.date, "HH:mm:ss")
                    color: clock.theme.icon; font.bold: true
                    font.family: clock.theme.font; font.pixelSize: clock.theme.size + 10
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: clock.dayNames[minClock.date.getDay()] + ", " + minClock.date.getDate() + " " + clock.monthNames[minClock.date.getMonth()] + " " + minClock.date.getFullYear()
                    color: clock.theme.fg
                    font.family: clock.theme.font; font.pixelSize: clock.theme.size
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: clock.theme.muted; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                Grid {
                    Layout.alignment: Qt.AlignHCenter
                    columns: 7
                    Repeater {
                        model: clock.headers
                        delegate: Text {
                            required property string modelData
                            width: 34; height: 24
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: modelData; color: clock.theme.muted
                            font.family: clock.theme.font; font.pixelSize: clock.theme.size - 2
                        }
                    }
                    Repeater {
                        model: clock.cells(minClock.date)
                        delegate: Item {
                            required property int modelData
                            width: 34; height: 28
                            Rectangle {
                                anchors.centerIn: parent
                                width: 26; height: 26; radius: 0
                                visible: modelData === minClock.date.getDate()
                                color: clock.theme.icon
                            }
                            Text {
                                anchors.centerIn: parent
                                text: modelData > 0 ? modelData : ""
                                color: modelData === minClock.date.getDate() ? clock.theme.bg : clock.theme.fg
                                font.bold: modelData === minClock.date.getDate()
                                font.family: clock.theme.font; font.pixelSize: clock.theme.size - 1
                            }
                        }
                    }
                }
            }
        }
    }
}
