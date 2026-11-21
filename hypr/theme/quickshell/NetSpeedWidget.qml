// NetSpeedWidget.qml - desktop network speed monitor, same look as the desktop clock (no card, soft shadow).
// Two big rows (download, upload) with colored arrows, a small title and the totals underneath.
import QtQuick
import QtQuick.Layouts

Item {
    id: widget
    property var theme
    property string iface: ""
    property string downText: "0 B/s"
    property string upText: "0 B/s"
    property string receivedText: "0 B"
    property string sentText: "0 B"
    property color textColor: "#ffffff"

    width: implicitWidth
    height: implicitHeight
    implicitWidth: Math.max(280, col.implicitWidth + 40)
    implicitHeight: col.implicitHeight + 24

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 6

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "N E T W O R K"
            color: widget.textColor; opacity: 0.75
            font.family: "Poppins"; font.pixelSize: 13; font.bold: true
            style: Text.Raised; styleColor: "#99000000"
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Text {
                text: "\uf063"
                color: widget.theme ? widget.theme.icon : "#0db9d7"
                font.family: widget.theme ? widget.theme.font : "JetBrainsMono Nerd Font"; font.pixelSize: 22
            }
            Text {
                text: widget.downText
                color: widget.textColor
                font.family: "Poppins"; font.pixelSize: 34; font.weight: Font.Light
                style: Text.Raised; styleColor: "#99000000"
            }
        }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            Text {
                text: "\uf062"
                color: widget.theme ? widget.theme.icon : "#0db9d7"
                font.family: widget.theme ? widget.theme.font : "JetBrainsMono Nerd Font"; font.pixelSize: 22
            }
            Text {
                text: widget.upText
                color: widget.textColor
                font.family: "Poppins"; font.pixelSize: 34; font.weight: Font.Light
                style: Text.Raised; styleColor: "#99000000"
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: (widget.iface !== "" ? widget.iface : "offline") + "   \u2193 " + widget.receivedText + "   \u2191 " + widget.sentText
            color: widget.textColor; opacity: 0.7
            font.family: "Poppins"; font.pixelSize: 13
            style: Text.Raised; styleColor: "#99000000"
        }
    }
}
