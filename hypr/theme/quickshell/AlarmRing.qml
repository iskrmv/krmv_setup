// AlarmRing.qml - the window that appears when a timer ends or an alarm rings. Enter / Esc dismiss, S snoozes 5 minutes.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ring
    required property var theme
    required property var engine

    screen: Quickshell.screens[0]
    visible: engine.ringing
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    implicitWidth: 400
    implicitHeight: 210
    color: "transparent"

    Shortcut { sequence: "Escape"; onActivated: ring.engine.dismiss() }
    Shortcut { sequence: "Return"; onActivated: ring.engine.dismiss() }
    Shortcut { sequence: "S"; enabled: ring.engine.ringKind === "alarm"; onActivated: ring.engine.snooze() }

    Rectangle {
        anchors.fill: parent
        color: ring.theme.bg
        border.width: 1
        border.color: ring.theme.icon

        ColumnLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: ring.engine.ringKind === "timer" ? "\uf017" : "\uf0f3"
                color: ring.theme.icon
                font.family: ring.theme.font; font.pixelSize: 40
                SequentialAnimation on opacity {
                    running: ring.engine.ringing; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 360
                elide: Text.ElideRight
                text: ring.engine.ringTitle
                color: ring.theme.fg; font.bold: true
                font.family: ring.theme.font; font.pixelSize: ring.theme.size + 4
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: ring.engine.ringSub
                color: ring.theme.dim
                font.family: ring.theme.font; font.pixelSize: ring.theme.size
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                PanelButton { theme: ring.theme; text: "Snooze 5 min (S)"; visible: ring.engine.ringKind === "alarm"; onClicked: ring.engine.snooze() }
                PanelButton { theme: ring.theme; text: "Dismiss (Enter)"; accent: true; onClicked: ring.engine.dismiss() }
            }
        }
    }
}
