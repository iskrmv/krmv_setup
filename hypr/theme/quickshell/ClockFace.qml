// ClockFace.qml - the look of the desktop clock: the day in big stylized letters, the date and the time underneath.
// Same look as KDE's "Modern Clock" (https://store.kde.org/p/2135653): day in Anurati, date and time in Poppins.
// Fonts: Poppins comes from the ttf-poppins package, Anurati is downloaded by install.sh into ~/.local/share/fonts.
// ALL clock settings are here.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: face

    // ---- settings ----
    property bool showDay: true
    property bool showDate: true
    property bool showTime: true
    property bool use24Hour: false          // false: "08:22 PM", true: "20:22"
    property string timeDecor: "-"          // character on both sides of the time ("" for none)
    property color textColor: "#ffffff"
    property real sizeScale: 1.0            // 1.0 = the original size (day 72 px); make it bigger or smaller here

    implicitWidth: col.implicitWidth + 40
    implicitHeight: col.implicitHeight + 20

    FontLoader { id: anurati; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Anurati.otf" }
    readonly property string dayFont: anurati.status === FontLoader.Ready ? anurati.name : "Poppins"

    // The time comes from our own one-second check, not from SystemClock: after the screen was locked or the laptop slept,
    // SystemClock could show the old minute for up to half a minute. This shows the right time within a second.
    property date nowDate: new Date()
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { const d = new Date(); if (d.getMinutes() !== face.nowDate.getMinutes() || d.getDate() !== face.nowDate.getDate() || d.getHours() !== face.nowDate.getHours()) face.nowDate = d }
    }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 5 * face.sizeScale

        Text {
            visible: face.showDay
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(face.nowDate, "dddd").toUpperCase()
            color: face.textColor
            font.family: face.dayFont
            font.pixelSize: 72 * face.sizeScale
            font.letterSpacing: 17 * face.sizeScale
            style: Text.Raised; styleColor: "#99000000"
        }
        Text {
            visible: face.showDate
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(face.nowDate, "dd MMM yyyy").toUpperCase()
            color: face.textColor
            font.family: "Poppins"
            font.pixelSize: 19 * face.sizeScale
            font.letterSpacing: 3 * face.sizeScale
            style: Text.Raised; styleColor: "#99000000"
        }
        Text {
            visible: face.showTime
            Layout.alignment: Qt.AlignHCenter
            text: (face.timeDecor !== "" ? face.timeDecor + " " : "")
                  + Qt.formatDateTime(face.nowDate, face.use24Hour ? "hh:mm" : "hh:mm AP")
                  + (face.timeDecor !== "" ? " " + face.timeDecor : "")
            color: face.textColor
            font.family: "Poppins"
            font.pixelSize: 19 * face.sizeScale
            font.letterSpacing: 3 * face.sizeScale
            style: Text.Raised; styleColor: "#99000000"
        }
    }
}
