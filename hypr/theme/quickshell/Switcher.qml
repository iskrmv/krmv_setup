// Switcher.qml - ALT + TAB window switcher.
// Hold ALT and tap TAB to walk through the open windows (last used first); let go of ALT to jump to the selected one.
// A quick ALT + TAB tap goes straight to the previously used window. ALT + SHIFT + TAB walks backwards.
// Hyprland sends the three events (conf/keybinds.lua):  next / prev on the key presses, commit when ALT is released.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: sw
    property var theme

    property bool shown: false
    property bool loading: false
    property bool commitPending: false
    property int steps: 0                    // TAB presses that arrived while the window list was loading
    property var clients: []
    property int index: 0

    function next() { if (shown) index = (index + 1) % clients.length; else { steps += 1; load() } }
    function prev() { if (shown) index = (index - 1 + clients.length) % clients.length; else { steps -= 1; load() } }
    function commit() {
        if (shown) { focusSelected(); close() }
        else if (loading) commitPending = true
    }
    function close() { shown = false; steps = 0; commitPending = false; clients = [] }
    function load() {
        if (loading) return
        loading = true
        listProc.running = true
    }
    function loaded(txt) {
        loading = false
        let list = []
        try { list = JSON.parse(txt) } catch (e) {}
        list = list.filter(c => c.mapped === true && c.class !== "")
        list.sort((a, b) => a.focusHistoryID - b.focusHistoryID)
        if (list.length === 0) { close(); return }
        clients = list
        const n = list.length
        index = n === 1 ? 0 : ((steps % n) + n) % n
        steps = 0
        if (commitPending) { focusSelected(); close() }       // ALT was already released: just switch, no overlay
        else shown = true
    }
    function focusSelected() {
        if (clients.length === 0) return
        focusProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + clients[index].address + "\" })"]
        focusProc.running = true
    }

    Process { id: focusProc }
    Process {
        id: listProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { onStreamFinished: sw.loaded(text) }
    }

    IpcHandler {
        target: "switcher"
        function next(): void { sw.next() }
        function prev(): void { sw.prev() }
        function commit(): void { sw.commit() }
    }

    PanelWindow {
        visible: sw.shown
        screen: Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None     // keys keep going to Hyprland, so TAB can be pressed again
        implicitWidth: row.implicitWidth + 32
        implicitHeight: 150
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: sw.theme.bg
            border.width: 1
            border.color: sw.theme.muted

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    // at most 8 tiles around the selection
                    model: {
                        const n = sw.clients.length
                        const start = Math.max(0, Math.min(sw.index - 3, n - 8))
                        return sw.clients.slice(start, start + 8).map((c, i) => ({ c: c, i: start + i }))
                    }
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool current: modelData.i === sw.index
                        width: 150; height: 112
                        color: current ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        border.width: current ? 2 : 1
                        border.color: current ? sw.theme.icon : sw.theme.muted
                        Column {
                            anchors { fill: parent; margins: 8 }
                            spacing: 6
                            Item {
                                width: parent.width; height: 44
                                Image {
                                    id: ico
                                    anchors.centerIn: parent
                                    width: 40; height: 40
                                    sourceSize.width: 80; sourceSize.height: 80
                                    source: Quickshell.iconPath(tile.modelData.c.class.toLowerCase(), true)
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: ico.status !== Image.Ready
                                    text: tile.modelData.c.class.substring(0, 1).toUpperCase()
                                    color: sw.theme.icon; font.bold: true
                                    font.family: sw.theme.font; font.pixelSize: 26
                                }
                            }
                            Text {
                                width: parent.width
                                text: tile.modelData.c.class
                                color: tile.current ? sw.theme.icon : sw.theme.fg; font.bold: true
                                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                                font.family: sw.theme.font; font.pixelSize: sw.theme.size - 1
                            }
                            Text {
                                width: parent.width
                                text: tile.modelData.c.title
                                color: sw.theme.dim
                                elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                font.family: sw.theme.font; font.pixelSize: sw.theme.size - 3
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: { sw.index = tile.modelData.i; sw.commit() } }
                    }
                }
            }
        }
    }
}
