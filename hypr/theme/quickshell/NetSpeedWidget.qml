// NetSpeedWidget.qml - desktop network speed monitor in the same look as the desktop clock
// (big spaced title, Poppins numbers, soft shadow, no card). Sampling happens once in shell.qml.
// It sits right under the clock and follows it when you move the clock.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: widget
    required property var theme
    property string iface: ""
    property string downText: "0 B/s"
    property string upText: "0 B/s"
    property string receivedText: "0 B"
    property string sentText: "0 B"
    property int clockX: -1                 // where the clock is (-1 = default place)
    property int clockY: -1
    property color textColor: "#ffffff"

    readonly property int curX: clockX >= 0 ? clockX : 80
    readonly property int curY: clockY >= 0 ? clockY + 200 : Math.round(screen.height / 2) + 105

    screen: Quickshell.screens[0]
    anchors { left: true; top: true }
    margins { left: curX; top: curY }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: col.implicitWidth + 40
    implicitHeight: col.implicitHeight + 20
    color: "transparent"

    FontLoader { id: anurati; source: "file://" + Quickshell.env("HOME") + "/.local/share/fonts/Anurati.otf" }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 5

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "NETWORK"
            color: widget.textColor
            font.family: anurati.status === FontLoader.Ready ? anurati.name : "Poppins"
            font.pixelSize: 34
            font.letterSpacing: 9
            style: Text.Raised; styleColor: "#99000000"
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "\u2193  " + widget.downText + "     \u2191  " + widget.upText
            color: widget.textColor
            font.family: "Poppins"; font.pixelSize: 19; font.letterSpacing: 2
            style: Text.Raised; styleColor: "#99000000"
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: (widget.iface !== "" ? widget.iface.toUpperCase() : "OFFLINE") + "  -  " + widget.receivedText + " IN  /  " + widget.sentText + " OUT"
            color: widget.textColor; opacity: 0.8
            font.family: "Poppins"; font.pixelSize: 13; font.letterSpacing: 2
            style: Text.Raised; styleColor: "#99000000"
        }
    }
}
