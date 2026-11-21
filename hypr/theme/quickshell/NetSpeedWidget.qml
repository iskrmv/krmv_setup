// NetSpeedWidget.qml - desktop card for the live network speed monitor.
// Sampling happens once in shell.qml; this window only displays the values.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: widget
    required property var theme
    property string iface: ""
    property string speedText: "\u2193 0B \u2191 0B"
    property string receivedText: "0 B"
    property string sentText: "0 B"

    screen: Quickshell.screens[0]
    anchors { left: true; top: true }
    margins { left: 80; top: 60 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: 280
    implicitHeight: 176
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: widget.theme.bg
        border.width: 1
        border.color: widget.theme.muted

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: "\uf3fd"
                    color: widget.theme.icon
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size + 2
                }
                Text {
                    Layout.fillWidth: true
                    text: "Network speed"
                    color: widget.theme.icon; font.bold: true
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size
                }
            }
            Text {
                Layout.fillWidth: true
                text: widget.iface !== "" ? widget.iface : "No active interface"
                color: widget.theme.dim
                font.family: widget.theme.font; font.pixelSize: widget.theme.size - 2
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: widget.theme.muted }
            Text {
                Layout.fillWidth: true
                text: widget.speedText
                color: widget.theme.fg; font.bold: true
                font.family: widget.theme.font; font.pixelSize: widget.theme.size + 8
            }
            Text {
                Layout.fillWidth: true
                text: "Received: " + widget.receivedText
                color: widget.theme.fg
                font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
            }
            Text {
                Layout.fillWidth: true
                text: "Sent: " + widget.sentText
                color: widget.theme.fg
                font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
            }
            Text {
                Layout.fillWidth: true
                text: "Updated every 2 seconds"
                color: widget.theme.dim
                font.family: widget.theme.font; font.pixelSize: widget.theme.size - 3
            }
        }
    }
}
