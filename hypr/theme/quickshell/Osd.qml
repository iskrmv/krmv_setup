// Osd.qml - small on-screen display at the bottom center.
//   level mode:   volume / brightness (an icon, a level line and a percentage)
//   message mode: media keys, touchpad on/off, night mode (an icon, a title and a second line)
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: osd
    required property var theme
    property string kind: "volume"      // "volume" | "brightness" | "message"
    property real value: 0              // 0..1
    property bool muted: false
    property bool shown: false
    property string msgIcon: ""
    property string msgText: ""
    property string msgSub: ""

    function show(k, v, m) {
        kind = k; value = v; muted = m
        shown = true
        hideTimer.restart()
    }
    // icon names: play, pause, next, prev, music, touchpad, touchpad-off, night
    function showMessage(icon, text, sub) {
        kind = "message"; msgIcon = icon; msgText = text; msgSub = sub
        shown = true
        hideTimer.restart()
    }
    Timer { id: hideTimer; interval: 1700; onTriggered: osd.shown = false }

    screen: Quickshell.screens[0]
    visible: shown || box.opacity > 0.01
    anchors { bottom: true }
    margins { bottom: 110 }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    implicitWidth: 340
    implicitHeight: 64
    color: "transparent"

    readonly property var msgGlyphs: ({
        "play": "\uf04b", "pause": "\uf04c", "next": "\uf051", "prev": "\uf048", "music": "\uf001",
        "touchpad": "\uf245", "touchpad-off": "\uf05e", "night": "\uf186", "keyboard": "\uf11c"
    })
    readonly property string glyph: kind === "message" ? (msgGlyphs[msgIcon] || "\uf05a")
                                    : kind === "brightness" ? "\uf185"
                                    : (muted ? "\uf026" : (value < 0.34 ? "\uf027" : "\uf028"))

    Rectangle {
        id: box
        anchors.fill: parent
        color: osd.theme.bg
        border.width: 1
        border.color: osd.theme.muted
        opacity: osd.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }

        RowLayout {
            anchors { fill: parent; leftMargin: 18; rightMargin: 18 }
            spacing: 14

            Text {
                Layout.preferredWidth: 28
                horizontalAlignment: Text.AlignHCenter
                text: osd.glyph
                color: (osd.kind === "volume" && osd.muted) ? osd.theme.red : osd.theme.icon
                font.family: osd.theme.font; font.pixelSize: 24
            }

            // level mode: the level line
            Item {
                visible: osd.kind !== "message"
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                Rectangle { anchors.fill: parent; color: osd.theme.muted }
                Rectangle {
                    height: parent.height
                    width: parent.width * ((osd.kind === "volume" && osd.muted) ? 0 : Math.max(0, Math.min(1, osd.value)))
                    color: osd.theme.icon
                    Behavior on width { NumberAnimation { duration: 90 } }
                }
            }
            Text {
                visible: osd.kind !== "message"
                Layout.preferredWidth: 56
                horizontalAlignment: Text.AlignRight
                text: (osd.kind === "volume" && osd.muted) ? "Muted" : Math.round(osd.value * 100) + "%"
                color: osd.theme.fg
                font.family: osd.theme.font; font.pixelSize: osd.theme.size
            }

            // message mode: title + second line
            ColumnLayout {
                visible: osd.kind === "message"
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: osd.msgText
                    elide: Text.ElideRight
                    color: osd.theme.fg; font.bold: true
                    font.family: osd.theme.font; font.pixelSize: osd.theme.size
                }
                Text {
                    visible: text !== ""
                    Layout.fillWidth: true
                    text: osd.msgSub
                    elide: Text.ElideRight
                    color: osd.theme.dim
                    font.family: osd.theme.font; font.pixelSize: osd.theme.size - 2
                }
            }
        }
    }
}
