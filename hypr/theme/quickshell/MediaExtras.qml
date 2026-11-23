// MediaExtras.qml - the small line under the controls: which player this is, its own volume (if it has one),
// and a button that brings the player's window to the front (if it allows that).
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

RowLayout {
    id: x
    required property var theme
    property var player: null
    property bool shadow: false
    readonly property bool ok: player !== null && player !== undefined
    spacing: 10

    Text {
        Layout.fillWidth: true
        text: x.ok ? x.player.identity : ""
        elide: Text.ElideRight
        color: x.shadow ? "#b3ffffff" : x.theme.dim
        style: x.shadow ? Text.Raised : Text.Normal; styleColor: "#99000000"
        font.family: x.theme.font; font.pixelSize: x.theme.size - 3
    }
    Row {
        visible: x.ok && x.player.volumeSupported
        spacing: 8
        Layout.alignment: Qt.AlignVCenter
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: x.ok && x.player.volume <= 0.001 ? "\uf026" : (x.ok && x.player.volume < 0.5 ? "\uf027" : "\uf028")
            color: x.shadow ? "#ffffff" : x.theme.icon
            font.family: x.theme.font; font.pixelSize: x.theme.size - 1
        }
        Slider {
            width: 96
            anchors.verticalCenter: parent.verticalCenter
            theme: x.theme
            value: x.ok ? Math.max(0, Math.min(1, x.player.volume)) : 0
            onMoved: v => x.player.volume = v
        }
    }
    Text {
        visible: x.ok && x.player.canRaise
        text: "\uf08e"
        color: raiseArea.containsMouse ? x.theme.bright : (x.shadow ? "#ffffff" : x.theme.icon)
        font.family: x.theme.font; font.pixelSize: x.theme.size
        MouseArea { id: raiseArea; anchors { fill: parent; margins: -6 } hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: x.player.raise() }
    }
}
