// PowerMenu.qml - full-screen power menu: lock, log out, sleep, reboot, power off.
// Same look as the lock screen. Keys: L E S R P, Esc (or click outside) closes it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: menu
    required property var theme
    signal closeRequested()

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay      // above everything, also above fullscreen windows
    focusable: true
    color: "transparent"

    readonly property var actions: [
        { icon: "\uf023", label: "Lock",      key: "L", cmd: ["sh", "-c", "pidof hyprlock || hyprlock"] },
        { icon: "\uf08b", label: "Log out",   key: "E", cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"] },
        { icon: "\uf186", label: "Sleep",     key: "S", cmd: ["systemctl", "suspend"] },
        { icon: "\uf021", label: "Reboot",    key: "R", cmd: ["systemctl", "reboot"] },
        { icon: "\uf011", label: "Power off", key: "P", cmd: ["systemctl", "poweroff"] }
    ]

    // Close the menu first, then run the command, so the lock screen never captures the menu
    property var pendingCmd: []
    function choose(cmd) { pendingCmd = cmd; closeRequested(); runTimer.restart() }
    Timer { id: runTimer; interval: 250; onTriggered: Quickshell.execDetached(menu.pendingCmd) }

    Shortcut { sequence: "Escape"; onActivated: menu.closeRequested() }
    Shortcut { sequence: "L"; onActivated: menu.choose(menu.actions[0].cmd) }
    Shortcut { sequence: "E"; onActivated: menu.choose(menu.actions[1].cmd) }
    Shortcut { sequence: "S"; onActivated: menu.choose(menu.actions[2].cmd) }
    Shortcut { sequence: "R"; onActivated: menu.choose(menu.actions[3].cmd) }
    Shortcut { sequence: "P"; onActivated: menu.choose(menu.actions[4].cmd) }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.102, 0.106, 0.149, 0.94)
        opacity: menu.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        MouseArea { anchors.fill: parent; onClicked: menu.closeRequested() }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "HH:mm")
                color: menu.theme.icon; font.bold: true
                font.family: menu.theme.font; font.pixelSize: 96
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                color: menu.theme.fg
                font.family: menu.theme.font; font.pixelSize: 20
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Quickshell.env("USER")
                color: menu.theme.dim
                font.family: menu.theme.font; font.pixelSize: 16
            }

            Item { Layout.preferredHeight: 28 }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16
                Repeater {
                    model: menu.actions
                    delegate: Rectangle {
                        id: btn
                        required property var modelData
                        implicitWidth: 126; implicitHeight: 118
                        color: area.containsMouse ? "#292e42" : "#1f2335"
                        border.width: 1
                        border.color: area.containsMouse ? menu.theme.icon : menu.theme.muted

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btn.modelData.icon
                                color: menu.theme.icon
                                font.family: menu.theme.font; font.pixelSize: 32
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btn.modelData.label
                                color: menu.theme.fg
                                font.family: menu.theme.font; font.pixelSize: menu.theme.size
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: btn.modelData.key
                                color: menu.theme.dim
                                font.family: menu.theme.font; font.pixelSize: menu.theme.size - 3
                            }
                        }
                        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: menu.choose(btn.modelData.cmd) }
                    }
                }
            }

            Item { Layout.preferredHeight: 18 }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Esc to cancel"
                color: menu.theme.dim
                font.family: menu.theme.font; font.pixelSize: menu.theme.size - 2
            }
        }
    }
}
