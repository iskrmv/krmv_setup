// BtPanel.qml - Bluetooth panel: scan, pair, connect, disconnect
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
    id: panel
    required property var theme
    property bool btOn: false
    signal closeRequested()
    signal powerChanged(bool on)

    property bool scanning: false
    property string status: ""
    property var firstSeen: ({})     // mac -> order of discovery (new devices are appended, rows never reshuffle)
    property int seenCount: 0

    anchors { top: true; right: true }
    margins { top: 38; right: 12 }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    implicitWidth: 340
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    onVisibleChanged: if (visible) { status = ""; refresh() }

    function refresh() { listProc.running = true }
    function startScan() {
        if (!btOn || scanning) return
        scanning = true
        status = "Scanning (8 seconds)..."
        scanProc.running = true
    }
    function run(cmd, msg) { status = msg; actProc.command = cmd; actProc.running = true }
    function pick(d) {
        if (d.connected) run(["bluetoothctl", "disconnect", d.mac], "Disconnecting...")
        else if (d.paired) run(["bluetoothctl", "connect", d.mac], "Connecting...")
        else run(["sh", "-c", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"", "_", d.mac], "Pairing...")
    }
    // Update the list in place: no reset, so the rows already on screen do not jump
    function syncModel(arr) {
        for (let i = 0; i < arr.length; i++) {
            if (i < devModel.count) devModel.set(i, arr[i]); else devModel.append(arr[i])
        }
        while (devModel.count > arr.length) devModel.remove(devModel.count - 1)
    }

    Shortcut { sequence: "Escape"; onActivated: panel.closeRequested() }
    // Closes when you click outside the panel
    HyprlandFocusGrab { windows: [panel]; active: panel.visible; onCleared: panel.closeRequested() }

    ListModel { id: devModel }

    Process {
        id: listProc
        command: ["sh", "-c", "bluetoothctl devices | while read -r _ mac name; do i=$(bluetoothctl info \"$mac\"); c=$(echo \"$i\" | grep -c 'Connected: yes'); p=$(echo \"$i\" | grep -c 'Paired: yes'); echo \"$mac|$c|$p|$name\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const arr = []
                text.trim().split("\n").forEach(l => {
                    const p = l.split("|")
                    if (p.length < 4) return
                    const name = p.slice(3).join("|")
                    if (/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/.test(name)) return   // hide unnamed devices
                    if (panel.firstSeen[p[0]] === undefined) panel.firstSeen[p[0]] = panel.seenCount++
                    arr.push({ mac: p[0], connected: p[1] !== "0", paired: p[2] !== "0", devName: name })
                })
                arr.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (panel.firstSeen[a.mac] - panel.firstSeen[b.mac]))
                panel.syncModel(arr)
            }
        }
    }
    Process {
        id: actProc
        stdout: StdioCollector { id: actOut }
        onExited: (code, st) => {
            panel.status = code === 0 ? "Done" : "Error: " + actOut.text.trim().split("\n").pop()
            panel.refresh()
        }
    }
    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onExited: { panel.scanning = false; panel.status = ""; panel.refresh() }
    }
    Process { id: powerProc; onExited: refreshTimer.start() }
    Timer { id: refreshTimer; interval: 1500; onTriggered: panel.refresh() }
    Timer { interval: 2000; running: panel.visible && panel.scanning; repeat: true; onTriggered: panel.refresh() }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.bg
        border.color: panel.theme.muted
        border.width: 1

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text { text: "\uf293  Bluetooth"; color: panel.theme.icon; font.family: panel.theme.font; font.pixelSize: panel.theme.size + 1; font.bold: true }
                Item { Layout.fillWidth: true }
                SpinIcon {
                    theme: panel.theme
                    idleIcon: "\uf002"      // magnifier
                    spinIcon: "\uf110"      // spinner
                    spinning: panel.scanning
                    onClicked: panel.startScan()
                }
                Toggle {
                    theme: panel.theme
                    on: panel.btOn
                    onToggled: {
                        powerProc.command = ["sh", "-c", panel.btOn ? "bluetoothctl power off" : "rfkill unblock bluetooth; bluetoothctl power on"]
                        powerProc.running = true
                        panel.powerChanged(!panel.btOn)
                    }
                }
            }

            Text {
                visible: !panel.btOn || devModel.count === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: panel.btOn ? "No devices. Use the magnifier to scan." : "Bluetooth is off"
                color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, devModel.count * 36)
                visible: panel.btOn && devModel.count > 0
                clip: true
                model: devModel
                delegate: Rectangle {
                    id: row
                    required property string mac
                    required property bool connected
                    required property bool paired
                    required property string devName
                    width: ListView.view.width; height: 34
                    color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text { text: row.connected ? "\uf00c" : "\uf293"; color: row.connected ? panel.theme.icon : panel.theme.fg; font.family: panel.theme.font; font.pixelSize: panel.theme.size }
                        Text { Layout.fillWidth: true; text: row.devName; elide: Text.ElideRight; color: row.connected ? panel.theme.icon : panel.theme.fg; font.family: panel.theme.font; font.pixelSize: panel.theme.size }
                        Text { text: row.connected ? "connected" : (row.paired ? "paired" : ""); color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size - 2 }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) panel.run(["bluetoothctl", "remove", row.mac], "Removing...")
                            else panel.pick({ mac: row.mac, connected: row.connected, paired: row.paired })
                        }
                    }
                }
            }

            Text {
                visible: panel.btOn && devModel.count > 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Left click: connect/disconnect  ·  Right click: forget"
                color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size - 3
            }
            Text {
                visible: panel.status !== ""
                Layout.fillWidth: true
                text: panel.status; wrapMode: Text.Wrap
                color: panel.status.startsWith("Error") ? panel.theme.red : panel.theme.icon
                font.family: panel.theme.font; font.pixelSize: panel.theme.size - 1
            }
        }
    }
}
