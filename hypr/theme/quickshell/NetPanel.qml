// NetPanel.qml - Wi-Fi panel: network list, pick a network, connect with a password.
// The panel has a FIXED size and its list is updated in place, so nothing jumps around.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
    id: panel
    required property var theme
    property bool wifiOn: false
    property bool ethernet: false
    signal closeRequested()
    signal powerChanged(bool on)

    property var saved: []
    property string selected: ""
    property string status: ""
    property bool busy: false
    property string lastPw: ""
    property bool spinHold: false                     // keeps the spinner visible long enough to notice
    readonly property bool scanning: rescanProc.running || spinHold

    anchors { top: true; right: true }
    margins { top: 38; right: 12 }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    implicitWidth: 340
    implicitHeight: col.implicitHeight + 28
    color: "transparent"

    onVisibleChanged: if (visible) { selected = ""; status = ""; refresh() }

    function refresh() { savedProc.running = true; listProc.running = true }
    function rescan() {
        if (!wifiOn || scanning) return
        spinHold = true
        spinTimer.restart()
        rescanProc.running = true
    }
    function connectTo(ssid, pw) {
        busy = true; status = "Connecting..."; lastPw = pw
        connProc.ssid = ssid
        connProc.command = pw !== "" ? ["nmcli", "dev", "wifi", "connect", ssid, "password", pw]
                                     : ["nmcli", "dev", "wifi", "connect", ssid]
        connProc.running = true
    }
    function pick(n) {
        if (n.active) { connProc.ssid = n.ssid; lastPw = ""; connProc.command = ["nmcli", "connection", "down", "id", n.ssid]; connProc.running = true; return }
        const open = (n.security === "" || n.security === "--")
        if (open || saved.indexOf(n.ssid) >= 0) { selected = ""; connectTo(n.ssid, "") }
        else { selected = n.ssid; pw.text = ""; pw.forceActiveFocus() }
    }
    // Update the list model in place (no reset, so the scroll position and layout stay put)
    function syncModel(arr) {
        for (let i = 0; i < arr.length; i++) {
            if (i < netModel.count) netModel.set(i, arr[i]); else netModel.append(arr[i])
        }
        while (netModel.count > arr.length) netModel.remove(netModel.count - 1)
    }

    Shortcut { sequence: "Escape"; onActivated: panel.closeRequested() }
    // Closes when you click outside the panel
    HyprlandFocusGrab { windows: [panel]; active: panel.visible; onCleared: panel.closeRequested() }

    ListModel { id: netModel }

    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                text.trim().split("\n").forEach(l => {
                    if (l.endsWith(":802-11-wireless")) out.push(l.slice(0, -16).replace(/\\:/g, ":"))
                })
                panel.saved = out
            }
        }
    }
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                text.trim().split("\n").forEach(line => {
                    const p = line.split(":")
                    if (p.length < 4) return
                    const ssid = p.slice(3).join(":").replace(/\\:/g, ":")
                    if (!ssid) return
                    const n = { ssid: ssid, strength: parseInt(p[1]) || 0, security: p[2], active: p[0] === "*" }
                    const old = map[ssid]
                    if (!old || n.active || (!old.active && n.strength > old.strength)) map[ssid] = n
                })
                const arr = Object.keys(map).map(k => map[k])
                arr.sort((a, b) => (b.active - a.active) || (b.strength - a.strength) || a.ssid.localeCompare(b.ssid))
                panel.syncModel(arr)
            }
        }
    }
    Process {
        id: connProc
        property string ssid: ""
        stdout: StdioCollector { id: connOut }
        stderr: StdioCollector { id: connErr }
        onExited: (code, st) => {
            panel.busy = false
            if (code === 0) { panel.status = "Connected to " + ssid; panel.selected = "" }
            else {
                const raw = (connErr.text || connOut.text).trim().split("\n")[0]
                // NetworkManager reports a wrong password in many ways; all of them mean "ask again"
                const badPw = /secrets were required|\(7\)|\(4\)|authentication|4-way|handshake|password|psk/i.test(raw)
                if (badPw) {
                    // the profile that was created (or saved earlier) holds the wrong password: remove it,
                    // then let you type the password again right here
                    cleanProc.command = ["nmcli", "connection", "delete", "id", ssid]
                    cleanProc.running = true
                    panel.status = "Error: wrong password for " + ssid + ". Type it again and press Enter."
                    panel.selected = ssid
                    pw.text = ""
                    pw.forceActiveFocus()
                } else if (/no network with ssid|not found/i.test(raw)) {
                    panel.status = "Error: " + ssid + " is not in range right now."
                } else {
                    panel.status = "Error: could not connect to " + ssid + (raw !== "" ? " (" + raw + ")" : "")
                }
            }
            panel.refresh()
        }
    }
    Process { id: cleanProc }   // removes the half-created profile after a wrong password
    Process { id: powerProc; onExited: refreshTimer.start() }
    Process { id: rescanProc; command: ["nmcli", "dev", "wifi", "rescan"]; onExited: panel.refresh() }
    Timer { id: spinTimer; interval: 1200; onTriggered: panel.spinHold = false }
    Timer { id: refreshTimer; interval: 1500; onTriggered: panel.refresh() }
    Timer { interval: 8000; running: panel.visible; repeat: true; onTriggered: if (!panel.busy) panel.refresh() }

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
                Text { text: "\uf1eb  Wi-Fi"; color: panel.theme.icon; font.family: panel.theme.font; font.pixelSize: panel.theme.size + 1; font.bold: true }
                Item { Layout.fillWidth: true }
                SpinIcon {
                    theme: panel.theme
                    idleIcon: "\uf021"
                    spinIcon: "\uf021"
                    spinning: panel.scanning
                    onClicked: panel.rescan()
                }
                Toggle {
                    theme: panel.theme
                    on: panel.wifiOn
                    onToggled: {
                        powerProc.command = ["nmcli", "radio", "wifi", panel.wifiOn ? "off" : "on"]
                        powerProc.running = true
                        panel.powerChanged(!panel.wifiOn)
                    }
                }
            }

            Text {
                visible: panel.ethernet
                Layout.fillWidth: true
                text: "\uDB80\uDE00  Ethernet connected"
                color: panel.theme.fg; font.family: panel.theme.font; font.pixelSize: panel.theme.size
            }

            Text {
                visible: !panel.wifiOn || netModel.count === 0
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: panel.wifiOn ? "No networks found" : "Wi-Fi is off"
                color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size
            }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(260, netModel.count * 36)
                visible: panel.wifiOn && netModel.count > 0
                clip: true
                model: netModel
                delegate: Rectangle {
                    id: row
                    required property string ssid
                    required property int strength
                    required property string security
                    required property bool active
                    width: ListView.view.width; height: 34
                    color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                        Text { text: row.active ? "\uf00c" : "\uf1eb"; color: row.active ? panel.theme.icon : panel.theme.fg; font.family: panel.theme.font; font.pixelSize: panel.theme.size }
                        Text { Layout.fillWidth: true; text: row.ssid; elide: Text.ElideRight; color: row.active ? panel.theme.icon : panel.theme.fg; font.family: panel.theme.font; font.pixelSize: panel.theme.size }
                        Text { visible: row.security !== "" && row.security !== "--"; text: "\uf023"; color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size - 2 }
                        Text { text: row.strength + "%"; color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size - 2 }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: panel.pick({ ssid: row.ssid, security: row.security, active: row.active }) }
                }
            }

            // Password input
            Rectangle {
                visible: panel.selected !== ""
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                color: Qt.rgba(1, 1, 1, 0.06)
                border.color: panel.theme.icon; border.width: 1
                TextInput {
                    id: pw
                    anchors.fill: parent; anchors.margins: 10
                    echoMode: TextInput.Password
                    color: panel.theme.fg; clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: panel.theme.font; font.pixelSize: panel.theme.size
                    onAccepted: panel.connectTo(panel.selected, text)
                    Text {
                        visible: pw.text === ""
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: panel.selected + " password (Enter)"
                        color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size
                        elide: Text.ElideRight
                    }
                }
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
