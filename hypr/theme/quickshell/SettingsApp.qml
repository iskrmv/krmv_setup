// SettingsApp.qml - the Settings app (SUPER + I). A sidebar with pages; every page is made of cards with plain-language rows.
// It only draws: reading and changing things is done by scripts/settings-api.sh (see that file).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: app
    required property var theme
    property var widgets: []                       // [{ id, name, enabled }] from shell.qml
    signal closeRequested()
    signal widgetToggled(string id, bool on)
    signal moveWidgetsRequested()

    readonly property string api: Quickshell.env("HOME") + "/.config/hypr/scripts/settings-api.sh"
    property int page: 0
    property var st: ({ night: false, mouse: false, polkitClassic: false, stretch: { enabled: false, width: 1440, height: 1080 },
                        layouts: "", input: { mouseSens: 0, mouseAccel: "adaptive", mouseNatural: false, mouseScroll: 1, leftHanded: false, tpNatural: true, tpTap: true, tpDwt: true, tpScroll: 0.5 }, monitors: [], geo: [], wifi: [], sinks: [], defaultSink: "", dns: "" })
    property var pending: null                     // a display change waiting for "Keep / Revert": { name, oldRec, newRec }
    property int pendingLeft: 0
    property string confirmForget: ""

    // data that is loaded when its page opens (kept apart from the quick "state")
    property var camera: ({ present: false, blocked: false, inUse: [], portal: [] })
    property var wifiList: []
    property bool scanning: false
    property string joinSsid: ""                   // the network whose password field is open
    property string joinMsg: ""
    property bool joining: false
    property var appRoles: []
    property string openRole: ""
    property var mimes: []
    property bool mimesLoading: false
    property string openMime: ""
    property var mimeCands: []
    property var binds: []
    property var fixedBinds: []
    property string captureId: ""                  // the shortcut that is waiting for new keys
    property string bindMsg: ""              // uuid of the Wi-Fi network that asks "really forget?"

    readonly property var pages: [
        { name: "Display",  icon: "\uf108", desc: "Resolution, size of everything, rotation and stretched games." },
        { name: "Network",  icon: "\uf1eb", desc: "Wi-Fi networks you know and private DNS." },
        { name: "Sound",    icon: "\uf028", desc: "Where the sound goes, and how loud your laptop can be." },
        { name: "Input",    icon: "\uf245", desc: "Mouse, touchpad and keyboard layouts." },
        { name: "Widgets",  icon: "\uf009", desc: "What lives on your desktop and in the top bar." },
        { name: "Privacy",  icon: "\uf124", desc: "Which apps may know where you are." },
        { name: "Apps",     icon: "\uf00a", desc: "Which app opens what." },
        { name: "Shortcuts", icon: "\uf11c", desc: "Every keyboard shortcut. Click Change, then press the new keys." },
        { name: "System",   icon: "\uf013", desc: "Night mode, the password dialog and tidying up." }
    ]

    screen: Quickshell.screens[0]
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    onVisibleChanged: if (visible) { refresh(); fade.restart(); pageEntered() }
    onPageChanged: { fade.restart(); flick.contentY = 0; pageEntered() }
    function pageEntered() {
        if (page === 1 && wifiList.length === 0) scanWifi()
        if (page === 5) loadCamera()
        if (page === 6 && appRoles.length === 0) loadApps()
        if (page === 7) loadBinds()
    }
    // every page slides in a little and fades in
    ParallelAnimation {
        id: fade
        NumberAnimation { target: pageCol; property: "opacity"; from: 0; to: 1; duration: 170 }
        NumberAnimation { target: pageCol; property: "y"; from: 44; to: 28; duration: 190; easing.type: Easing.OutCubic }
    }

    // ---- talking to the backend ----
    function refresh() { if (!stateProc.running) stateProc.running = true }
    Process {
        id: stateProc
        command: ["sh", app.api, "state"]
        stdout: StdioCollector {
            onStreamFinished: { try { app.st = JSON.parse(text) } catch (e) { console.warn("Settings state: " + e) } }
        }
    }
    // calls that answer with text (JSON): callApi(["apps", "list"], text => ...)
    property var callQueue: []
    property var callCur: null
    function callApi(args, cb) { callQueue = callQueue.concat([{ args: args, cb: cb }]); if (!callProc.running && !advance.running) nextCall() }
    function nextCall() {
        if (callQueue.length === 0) return
        callCur = callQueue[0]; callQueue = callQueue.slice(1)
        callProc.command = ["sh", app.api].concat(callCur.args)
        callProc.running = true
    }
    Process {
        id: callProc
        stdout: StdioCollector {
            onStreamFinished: {
                const c = app.callCur; app.callCur = null
                try { if (c && c.cb) c.cb(text) } catch (e) { console.warn("Settings call: " + e) }
                advance.restart()
            }
        }
    }
    Timer { id: advance; interval: 40; onTriggered: { if (callProc.running) advance.restart(); else app.nextCall() } }
    function parse(text, fallback) { try { return JSON.parse(text) } catch (e) { return fallback } }

    function loadCamera() { callApi(["camera", "state"], t => { app.camera = parse(t, app.camera) }) }
    function scanWifi() { scanning = true; callApi(["wifi", "scan"], t => { app.wifiList = parse(t, []); app.scanning = false }) }
    function joinWifi(ssid, pass) {
        joining = true; joinMsg = ""
        callApi(["wifi", "join", ssid, pass], t => {
            const r = parse(t, { ok: false, msg: "No answer from the network service." })
            app.joining = false
            if (r.ok) { app.joinSsid = ""; app.joinMsg = ""; app.scanWifi(); app.refresh() }
            else { app.joinMsg = r.msg; app.joinSsid = ssid }
        })
    }
    function loadApps() { callApi(["apps", "list"], t => { app.appRoles = parse(t, []) }) }
    function loadMimes() { mimesLoading = true; callApi(["mime", "list"], t => { app.mimes = parse(t, []); app.mimesLoading = false }) }
    function loadBinds() {
        callApi(["binds", "list"], t => { app.binds = parse(t, []) })
        callApi(["binds", "fixed"], t => { app.fixedBinds = parse(t, []) })
    }
    // a key press -> "SUPER + SHIFT + T"
    function comboFromEvent(e) {
        const k = e.key
        if (k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_AltGr
            || k === Qt.Key_Super_L || k === Qt.Key_Super_R) return ""
        let name = ""
        if (k >= Qt.Key_A && k <= Qt.Key_Z) name = String.fromCharCode(k)
        else if (k >= Qt.Key_0 && k <= Qt.Key_9) name = String.fromCharCode(k)
        else if (k >= Qt.Key_F1 && k <= Qt.Key_F12) name = "F" + (k - Qt.Key_F1 + 1)
        else {
            const map = {}
            map[Qt.Key_Return] = "Return"; map[Qt.Key_Enter] = "Return"; map[Qt.Key_Tab] = "Tab"; map[Qt.Key_Backtab] = "Tab"
            map[Qt.Key_Space] = "space"; map[Qt.Key_BackSpace] = "BackSpace"; map[Qt.Key_Delete] = "Delete"
            map[Qt.Key_Home] = "Home"; map[Qt.Key_End] = "End"; map[Qt.Key_Left] = "Left"; map[Qt.Key_Right] = "Right"
            map[Qt.Key_Up] = "Up"; map[Qt.Key_Down] = "Down"; map[Qt.Key_PageUp] = "Prior"; map[Qt.Key_PageDown] = "Next"
            map[Qt.Key_Print] = "Print"; map[Qt.Key_Comma] = "comma"; map[Qt.Key_Period] = "period"; map[Qt.Key_Slash] = "slash"
            map[Qt.Key_Semicolon] = "semicolon"; map[Qt.Key_Minus] = "minus"; map[Qt.Key_Equal] = "equal"
            map[Qt.Key_BracketLeft] = "bracketleft"; map[Qt.Key_BracketRight] = "bracketright"
            map[Qt.Key_QuoteLeft] = "grave"; map[Qt.Key_Backslash] = "backslash"; map[Qt.Key_Apostrophe] = "apostrophe"
            name = map[k] || ""
        }
        if (name === "") return ""
        let c = ""
        if (e.modifiers & Qt.MetaModifier) c += "SUPER + "
        if (e.modifiers & Qt.ControlModifier) c += "CTRL + "
        if (e.modifiers & Qt.AltModifier) c += "ALT + "
        if ((e.modifiers & Qt.ShiftModifier) || k === Qt.Key_Backtab) c += "SHIFT + "
        return c + name
    }
    function setBind(id, combo) {
        captureId = ""
        callApi(["binds", "set", id, combo], t => {
            const s = t.trim()
            app.bindMsg = s.startsWith("ok ") ? "Saved: " + s.substring(3) : s.replace(/^error\s*/, "")
            app.loadBinds()
        })
    }

    property var queue: []
    function act(args) {
        if (args[0] === "open") closeRequested()     // menus opened from here need the keyboard, so this window gets out of the way
        queue = queue.concat([args]); if (!actProc.running) runNext() }
    function runNext() {
        if (queue.length === 0) { refresh(); if (page === 5) loadCamera(); return }
        const a = queue[0]; queue = queue.slice(1)
        actProc.command = ["sh", app.api].concat(a)
        actProc.running = true
    }
    Process { id: actProc; onExited: app.runNext() }
    Timer { interval: 4000; running: app.visible; repeat: true
            onTriggered: { if (!actProc.running) app.refresh(); if (app.page === 5) app.loadCamera() } }

    // ---- display changes: apply, then 12 seconds to keep or revert ----
    function recOf(m, mode, scale, transform) {
        return [m.name, mode, m.x + "x" + m.y, String(scale), String(transform), ""].join("\t")
    }
    function currentMode(m) { return m.width + "x" + m.height + "@" + m.rate }
    function sameMode(m, modeStr) {
        const p = modeStr.split("@")
        return p[0] === (m.width + "x" + m.height) && Math.abs(parseFloat(p[1]) - m.rate) < 0.6
    }
    function changeDisplay(m, mode, scale, transform) {
        if (pending) return
        const oldRec = recOf(m, currentMode(m), m.scale, m.transform)
        const newRec = recOf(m, mode, scale, transform)
        pending = { name: m.name, oldRec: oldRec, newRec: newRec }
        pendingLeft = 12
        act(["display", "live", newRec])
    }
    function keepDisplay() { if (!pending) return; act(["display", "save", pending.newRec]); pending = null }
    function revertDisplay() { if (!pending) return; act(["display", "live", pending.oldRec]); pending = null }
    Timer { interval: 1000; running: app.pending !== null; repeat: true
        onTriggered: { app.pendingLeft -= 1; if (app.pendingLeft <= 0) app.revertDisplay() } }

    // pointer speed: send the value shortly after you stop dragging
    property real pendingSens: 0
    Timer { id: sensTimer; interval: 160; onTriggered: app.act(["input", "set", "mouse_sens", String(app.pendingSens)]) }

    // ---- window ----
    Shortcut { sequence: "Escape"; enabled: app.captureId === ""; onActivated: app.closeRequested() }
    // while a shortcut waits for new keys, this item receives every key press
    Item {
        id: keyCatcher
        focus: app.captureId !== ""
        Keys.onPressed: event => {
            event.accepted = true
            if (event.key === Qt.Key_Escape) { app.captureId = ""; app.bindMsg = ""; return }
            const combo = app.comboFromEvent(event)
            if (combo !== "") app.setBind(app.captureId, combo)
        }
    }
    onCaptureIdChanged: if (captureId !== "") keyCatcher.forceActiveFocus()
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55); MouseArea { anchors.fill: parent; onClicked: app.closeRequested() } }

    Rectangle {
        id: win
        anchors.centerIn: parent
        opacity: app.visible ? 1 : 0
        scale: app.visible ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        width: Math.min(app.width - 80, 1040); height: Math.min(app.height - 80, 700)
        color: app.theme.bg
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
        MouseArea { anchors.fill: parent }      // clicks inside never close the window

        // ===== sidebar =====
        Rectangle {
            id: side
            width: 220
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            color: Qt.rgba(0, 0, 0, 0.22)
            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 4
                RowLayout {
                    Layout.leftMargin: 6; Layout.topMargin: 4; Layout.bottomMargin: 18
                    spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36; color: app.theme.icon
                        Text { anchors.centerIn: parent; text: "\uf013"; color: app.theme.bg
                               font.family: app.theme.font; font.pixelSize: app.theme.size + 6 }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { text: "Settings"; color: app.theme.bright; font.bold: true
                               font.family: app.theme.font; font.pixelSize: app.theme.size + 4 }
                        Text { text: "krmv-setup"; color: app.theme.dim
                               font.family: app.theme.font; font.pixelSize: app.theme.size - 3 }
                    }
                }
                Repeater {
                    model: app.pages
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool sel: app.page === index
                        Layout.fillWidth: true; Layout.preferredHeight: 40
                        color: sel ? Qt.rgba(1, 1, 1, 0.07) : (hov.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                        Rectangle { width: 3; height: parent.height; color: app.theme.icon; visible: item.sel }
                        Row {
                            anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                            spacing: 14
                            Text { width: 20; horizontalAlignment: Text.AlignHCenter; text: item.modelData.icon
                                   color: item.sel ? app.theme.icon : app.theme.dim
                                   font.family: app.theme.font; font.pixelSize: app.theme.size + 1 }
                            Text { text: item.modelData.name; color: item.sel ? app.theme.bright : app.theme.fg; font.bold: item.sel
                                   font.family: app.theme.font; font.pixelSize: app.theme.size }
                        }
                        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: app.page = item.index }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.leftMargin: 8
                    text: "Esc closes"; color: app.theme.dim
                    font.family: app.theme.font; font.pixelSize: app.theme.size - 3
                }
            }
        }

        // ===== page =====
        Flickable {
            id: flick
            anchors { left: side.right; right: parent.right; top: parent.top; bottom: parent.bottom }
            contentWidth: width
            contentHeight: pageCol.implicitHeight + 64
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: pageCol
                x: 32; y: 28
                width: flick.width - 64
                spacing: 16

                ColumnLayout {
                    spacing: 4
                    Layout.bottomMargin: 6
                    Text {
                        text: app.pages[app.page].name
                        color: app.theme.bright; font.bold: true
                        font.family: app.theme.font; font.pixelSize: app.theme.size + 12
                    }
                    Text {
                        text: app.pages[app.page].desc
                        color: app.theme.dim
                        font.family: app.theme.font; font.pixelSize: app.theme.size - 1
                    }
                }

                // =================================================== DISPLAY
                ColumnLayout {
                    visible: app.page === 0
                    Layout.fillWidth: true; spacing: 16

                    // keep / revert bar
                    Rectangle {
                        visible: app.pending !== null
                        Layout.fillWidth: true; implicitHeight: 54
                        color: Qt.rgba(0.88, 0.69, 0.41, 0.12)
                        border.width: 1; border.color: "#e0af68"
                        RowLayout {
                            anchors { fill: parent; leftMargin: 16; rightMargin: 12 }
                            spacing: 10
                            Text { Layout.fillWidth: true; color: app.theme.bright
                                   text: "Keep these display settings?  Going back in " + app.pendingLeft + " s"
                                   font.family: app.theme.font; font.pixelSize: app.theme.size }
                            UiButton { theme: app.theme; text: "Go back"; onClicked: app.revertDisplay() }
                            UiButton { theme: app.theme; text: "Keep"; kind: "primary"; onClicked: app.keepDisplay() }
                        }
                    }

                    Repeater {
                        model: app.st.monitors
                        delegate: UiCard {
                            id: monCard
                            required property var modelData
                            theme: app.theme
                            icon: "\uf108"; title: modelData.name + (modelData.make ? "   " + modelData.make + " " + modelData.model : "")
                            subtitle: modelData.width + " x " + modelData.height + " at " + Math.round(modelData.rate) + " Hz, scale " + modelData.scale

                            RowLayout {
                                Layout.fillWidth: true; spacing: 18
                                Item {   // a drawing of the screen, with the real proportions
                                    readonly property bool turned: monCard.modelData.transform % 2 === 1
                                    readonly property real ratio: turned ? monCard.modelData.width / monCard.modelData.height
                                                                         : monCard.modelData.height / monCard.modelData.width
                                    Layout.preferredWidth: 150; Layout.preferredHeight: 100
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.turned ? Math.min(90, 100 / Math.max(0.1, parent.ratio)) : 144
                                        height: parent.turned ? 100 : Math.min(100, 144 * parent.ratio)
                                        color: Qt.rgba(1, 1, 1, 0.05); border.width: 2; border.color: app.theme.icon
                                        Text { anchors.centerIn: parent; color: app.theme.bright; font.bold: true
                                               text: monCard.modelData.width + "\u00d7" + monCard.modelData.height
                                               font.family: app.theme.font; font.pixelSize: app.theme.size - 2 }
                                    }
                                }
                                ColumnLayout {
                                    spacing: 3
                                    Text { text: Math.round(monCard.modelData.rate) + " Hz"; color: app.theme.bright; font.bold: true
                                           font.family: app.theme.font; font.pixelSize: app.theme.size + 8 }
                                    Text { text: "Scale " + Math.round(monCard.modelData.scale * 100) + "%   \u00b7   rotation " + monCard.modelData.transform * 90 + "\u00b0"
                                           color: app.theme.dim; font.family: app.theme.font; font.pixelSize: app.theme.size - 2 }
                                }
                            }
                            UiRow {
                                theme: app.theme; title: "Size of everything"; subtitle: "Scale. 100% is sharpest and smallest."
                                UiSegment {
                                    theme: app.theme; current: monCard.modelData.scale
                                    options: [ { label: "100%", value: 1 }, { label: "125%", value: 1.25 }, { label: "150%", value: 1.5 },
                                               { label: "175%", value: 1.75 }, { label: "200%", value: 2 } ]
                                    onPicked: v => app.changeDisplay(monCard.modelData, app.currentMode(monCard.modelData), v, monCard.modelData.transform)
                                }
                            }
                            UiRow {
                                theme: app.theme; title: "Rotation"
                                UiSegment {
                                    theme: app.theme; current: monCard.modelData.transform
                                    options: [ { label: "0\u00b0", value: 0 }, { label: "90\u00b0", value: 1 }, { label: "180\u00b0", value: 2 }, { label: "270\u00b0", value: 3 } ]
                                    onPicked: v => app.changeDisplay(monCard.modelData, app.currentMode(monCard.modelData), monCard.modelData.scale, v)
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 8
                                Text { text: "Resolution and refresh rate"; color: app.theme.bright
                                       font.family: app.theme.font; font.pixelSize: app.theme.size }
                                Flow {
                                    Layout.fillWidth: true; spacing: 6
                                    Repeater {
                                        model: monCard.modelData.modes.slice(0, 18)
                                        delegate: UiButton {
                                            required property string modelData
                                            theme: app.theme
                                            text: modelData.replace(/\.00$/, "").replace("@", " @ ") + " Hz"
                                            kind: app.sameMode(monCard.modelData, modelData) ? "primary" : "secondary"
                                            onClicked: app.changeDisplay(monCard.modelData, modelData, monCard.modelData.scale, monCard.modelData.transform)
                                        }
                                    }
                                }
                                RowLayout {
                                    spacing: 8
                                    UiInput { id: customRes; theme: app.theme; placeholder: "Custom: 1440x1080 or 1440x1080@60"; implicitWidth: 300
                                              onAccepted: customBtn.clicked() }
                                    UiButton {
                                        id: customBtn
                                        theme: app.theme; text: "Use it"
                                        onClicked: {
                                            let v = customRes.text.trim()
                                            if (!/^\d{3,5}x\d{3,5}(@\d+(\.\d+)?)?$/.test(v)) return
                                            if (v.indexOf("@") < 0) v += "@" + Math.round(monCard.modelData.rate)
                                            app.changeDisplay(monCard.modelData, v, monCard.modelData.scale, monCard.modelData.transform)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiCard {
                        theme: app.theme
                        icon: "\uf0b2"; title: "Stretched resolution for games"
                        subtitle: "Play at 4:3 and stretch it over the whole 16:9 screen. Add  krmv-stretch %command%  to the game's Steam launch options once; this switch then turns it on and off for that game."
                        UiRow {
                            theme: app.theme; title: "Stretch"
                            Toggle { theme: app.theme; on: app.st.stretch.enabled; onToggled: app.act(["stretch", "enabled", app.st.stretch.enabled ? "0" : "1"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Method"
                            subtitle: app.st.stretch.method === "gamescope"
                                      ? "gamescope: the Steam overlay works, but some games limit the frame rate or capture the mouse differently."
                                      : "Native Wayland (recommended): same as SDL_VIDEO_DRIVER=wayland. Full speed, normal mouse. Pick the 4:3 resolution inside the game. No Steam overlay."
                            UiSegment {
                                theme: app.theme; current: app.st.stretch.method
                                options: [ { label: "Native Wayland", value: "wayland" }, { label: "gamescope", value: "gamescope" } ]
                                onPicked: v => app.act(["stretch", "method", v])
                            }
                        }
                        UiRow {
                            visible: app.st.stretch.method === "gamescope"
                            theme: app.theme; title: "Game resolution"; subtitle: "Only for the gamescope method."
                            UiSegment {
                                theme: app.theme; current: app.st.stretch.width + "x" + app.st.stretch.height
                                options: [ { label: "1024x768", value: "1024x768" }, { label: "1280x960", value: "1280x960" },
                                           { label: "1440x1080", value: "1440x1080" }, { label: "1600x1200", value: "1600x1200" } ]
                                onPicked: v => app.act(["stretch", "size", v])
                            }
                        }
                        UiButton { theme: app.theme; icon: "\uf0c5"; text: "Copy the Steam launch option"; onClicked: app.act(["stretch", "copy"]) }
                    }
                }

                // =================================================== NETWORK
                ColumnLayout {
                    visible: app.page === 1
                    Layout.fillWidth: true; spacing: 16

                    UiCard {
                        theme: app.theme
                        icon: "\uf1eb"; title: "Wi-Fi networks you know"
                        subtitle: "Connect, let a network connect by itself, or forget it."
                        Text {
                            visible: app.st.wifi.length === 0
                            text: "No saved Wi-Fi networks yet."; color: app.theme.dim
                            font.family: app.theme.font; font.pixelSize: app.theme.size - 1
                        }
                        Repeater {
                            model: app.st.wifi
                            delegate: Rectangle {
                                id: wrow
                                required property var modelData
                                Layout.fillWidth: true; implicitHeight: 50
                                color: Qt.rgba(1, 1, 1, 0.03)
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                                    spacing: 10
                                    Text { text: "\uf1eb"; color: wrow.modelData.active ? app.theme.icon : app.theme.dim
                                           font.family: app.theme.font; font.pixelSize: app.theme.size + 2 }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 0
                                        Text { text: wrow.modelData.name; color: app.theme.bright; elide: Text.ElideRight; Layout.fillWidth: true
                                               font.family: app.theme.font; font.pixelSize: app.theme.size }
                                        Text { text: wrow.modelData.active ? "Connected" : (wrow.modelData.auto ? "Connects by itself" : "Manual")
                                               color: wrow.modelData.active ? app.theme.icon : app.theme.dim
                                               font.family: app.theme.font; font.pixelSize: app.theme.size - 3 }
                                    }
                                    Text { text: "Auto"; color: app.theme.dim; font.family: app.theme.font; font.pixelSize: app.theme.size - 2 }
                                    Toggle { theme: app.theme; on: wrow.modelData.auto
                                             onToggled: app.act(["wifi", "auto", wrow.modelData.uuid, wrow.modelData.auto ? "no" : "yes"]) }
                                    UiButton { theme: app.theme; text: "Connect"; visible: !wrow.modelData.active
                                               onClicked: app.act(["wifi", "connect", wrow.modelData.uuid]) }
                                    UiButton { theme: app.theme; kind: app.confirmForget === wrow.modelData.uuid ? "danger" : "ghost"
                                               text: app.confirmForget === wrow.modelData.uuid ? "Really forget?" : "Forget"
                                               onClicked: {
                                                   if (app.confirmForget === wrow.modelData.uuid) { app.confirmForget = ""; app.act(["wifi", "forget", wrow.modelData.uuid]) }
                                                   else app.confirmForget = wrow.modelData.uuid
                                               } }
                                }
                            }
                        }
                    }

                    UiCard {
                        theme: app.theme
                        icon: "\uf002"; title: "Networks nearby"
                        subtitle: "Pick a network. If it needs a password you type it right here; a wrong password shows a message and you can try again."
                        RowLayout {
                            spacing: 8
                            UiButton { theme: app.theme; icon: "\uf021"; text: app.scanning ? "Scanning..." : "Scan again"; active: !app.scanning; onClicked: app.scanWifi() }
                            Text { visible: app.joinMsg !== "" && app.joinSsid === ""; text: app.joinMsg; color: app.theme.red
                                   font.family: app.theme.font; font.pixelSize: app.theme.size - 1 }
                        }
                        Text {
                            visible: !app.scanning && app.wifiList.length === 0
                            text: "No networks found. Is Wi-Fi switched on?"; color: app.theme.dim
                            font.family: app.theme.font; font.pixelSize: app.theme.size - 1
                        }
                        Repeater {
                            model: app.wifiList
                            delegate: ColumnLayout {
                                id: nrow
                                required property var modelData
                                readonly property bool saved: { for (const w of app.st.wifi) if (w.name === modelData.ssid) return true; return false }
                                Layout.fillWidth: true; spacing: 0
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 48
                                    color: Qt.rgba(1, 1, 1, 0.03)
                                    RowLayout {
                                        anchors { fill: parent; leftMargin: 14; rightMargin: 10 }
                                        spacing: 12
                                        Text { text: nrow.modelData.signal > 75 ? "\uf1eb" : (nrow.modelData.signal > 45 ? "\uf1eb" : "\uf1eb")
                                               color: nrow.modelData.signal > 60 ? app.theme.icon : (nrow.modelData.signal > 35 ? app.theme.fg : app.theme.dim)
                                               font.family: app.theme.font; font.pixelSize: app.theme.size + 2 }
                                        Text { text: nrow.modelData.ssid; color: app.theme.bright; elide: Text.ElideRight; Layout.fillWidth: true
                                               font.family: app.theme.font; font.pixelSize: app.theme.size }
                                        Text { visible: nrow.modelData.secure; text: "\uf023"; color: app.theme.dim
                                               font.family: app.theme.font; font.pixelSize: app.theme.size - 1 }
                                        Text { text: nrow.modelData.signal + "%"; color: app.theme.dim; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight
                                               font.family: app.theme.font; font.pixelSize: app.theme.size - 2 }
                                        Text { visible: nrow.modelData.inUse; text: "Connected"; color: app.theme.icon
                                               font.family: app.theme.font; font.pixelSize: app.theme.size - 2 }
                                        UiButton {
                                            visible: !nrow.modelData.inUse
                                            theme: app.theme; text: "Connect"; active: !app.joining
                                            onClicked: {
                                                app.joinMsg = ""
                                                if (nrow.modelData.secure && !nrow.saved) { app.joinSsid = nrow.modelData.ssid; pwBox.text = ""; pwBox.focusInput() }
                                                else app.joinWifi(nrow.modelData.ssid, "")
                                            }
                                        }
                                    }
                                }
                                // the password line, right under the network
                                Rectangle {
                                    visible: app.joinSsid === nrow.modelData.ssid
                                    Layout.fillWidth: true; implicitHeight: pwCol.implicitHeight + 20
                                    color: Qt.rgba(1, 1, 1, 0.05)
                                    ColumnLayout {
                                        id: pwCol
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 10 }
                                        spacing: 8
                                        Text {
                                            visible: app.joinMsg !== ""
                                            Layout.fillWidth: true; text: app.joinMsg; color: app.theme.red; font.bold: true; wrapMode: Text.Wrap
                                            font.family: app.theme.font; font.pixelSize: app.theme.size - 1
                                        }
                                        RowLayout {
                                            spacing: 8
                                            UiInput { id: pwBox; theme: app.theme; secret: true; placeholder: "Password for " + nrow.modelData.ssid
                                                      Layout.fillWidth: true; maxLength: 128
                                                      onAccepted: if (text !== "") app.joinWifi(nrow.modelData.ssid, text) }
                                            UiButton { theme: app.theme; kind: "primary"; text: app.joining ? "Connecting..." : "Connect"; active: !app.joining
                                                       onClicked: if (pwBox.text !== "") app.joinWifi(nrow.modelData.ssid, pwBox.text) }
                                            UiButton { theme: app.theme; kind: "ghost"; text: "Cancel"; onClicked: { app.joinSsid = ""; app.joinMsg = "" } }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    UiCard {
                        theme: app.theme
                        icon: "\uf023"; title: "Private DNS"
                        subtitle: "Encrypted DNS (DNS-over-TLS) for the whole system. Pick one provider, or turn it off to go back to your network's own DNS."
                        Flow {
                            Layout.fillWidth: true; spacing: 8
                            Repeater {
                                model: [ { n: "AdGuard (blocks ads)", h: "dns.adguard-dns.com", k: "adguard-dns.com" },
                                         { n: "AdGuard (no filter)", h: "unfiltered.adguard-dns.com", k: "unfiltered.adguard" },
                                         { n: "AdGuard Family", h: "family.adguard-dns.com", k: "family.adguard" },
                                         { n: "Cloudflare", h: "cloudflare-dns.com", k: "cloudflare" },
                                         { n: "Google", h: "dns.google", k: "dns.google" },
                                         { n: "Quad9", h: "dns.quad9.net", k: "quad9" } ]
                                delegate: UiButton {
                                    required property var modelData
                                    theme: app.theme; text: modelData.n
                                    kind: app.st.dns.toLowerCase().indexOf(modelData.k) >= 0 ? "primary" : "secondary"
                                    onClicked: app.act(["dns", modelData.h])
                                }
                            }
                            UiButton { theme: app.theme; text: "Turn off"; kind: "danger"; onClicked: app.act(["dns", "stop"]) }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Changing it asks for your password."; color: app.theme.dim
                            font.family: app.theme.font; font.pixelSize: app.theme.size - 3
                        }
                    }
                }

                // =================================================== SOUND
                ColumnLayout {
                    visible: app.page === 2
                    Layout.fillWidth: true; spacing: 16
                    UiCard {
                        theme: app.theme
                        icon: "\uf028"; title: "Where the sound goes"
                        Repeater {
                            model: app.st.sinks
                            delegate: Rectangle {
                                id: srow
                                required property var modelData
                                readonly property bool sel: modelData.name === app.st.defaultSink
                                Layout.fillWidth: true; implicitHeight: 42
                                color: sel ? Qt.rgba(1, 1, 1, 0.07) : (sarea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                                Rectangle { width: 3; height: parent.height; color: app.theme.icon; visible: srow.sel }
                                Text { anchors { left: parent.left; leftMargin: 16; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                       text: srow.modelData.desc; elide: Text.ElideRight
                                       color: srow.sel ? app.theme.bright : app.theme.fg
                                       font.family: app.theme.font; font.pixelSize: app.theme.size }
                                MouseArea { id: sarea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: app.act(["audio", "sink", srow.modelData.name]) }
                            }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        icon: "\uf028"; title: "Laptop speakers too quiet?"
                        subtitle: "If headphones are loud but the speakers are weak, a hidden volume level is low. This raises every one of them to 100% and keeps it after a restart."
                        RowLayout {
                            spacing: 8
                            UiButton { theme: app.theme; kind: "primary"; icon: "\uf028"; text: "Raise all levels to 100%"; onClicked: app.act(["audio", "boost"]) }
                            UiButton { theme: app.theme; text: "Copy audio diagnostics"; onClicked: app.act(["audio", "diagnostics"]) }
                        }
                    }
                }

                // =================================================== INPUT
                ColumnLayout {
                    visible: app.page === 3
                    Layout.fillWidth: true; spacing: 16
                    UiCard {
                        theme: app.theme
                        icon: "\uf245"; title: "Mouse"
                        UiRow {
                            theme: app.theme; title: "Pointer speed"; subtitle: "Slower on the left, faster on the right."
                            Slider {
                                id: speed
                                theme: app.theme; width: 200
                                value: (app.st.input.mouseSens + 1) / 2
                                onMoved: v => { app.pendingSens = Math.round((v * 2 - 1) * 100) / 100; sensTimer.restart() }
                            }
                            Text { width: 42; horizontalAlignment: Text.AlignRight; color: app.theme.dim
                                   text: (app.st.input.mouseSens > 0 ? "+" : "") + app.st.input.mouseSens.toFixed(2)
                                   font.family: app.theme.font; font.pixelSize: app.theme.size - 2 }
                        }
                        UiRow {
                            theme: app.theme; title: "Acceleration"
                            subtitle: "Adaptive: a fast flick goes further. Flat: the cursor moves exactly as far as the mouse did."
                            UiSegment {
                                theme: app.theme; current: app.st.input.mouseAccel
                                options: [ { label: "Adaptive", value: "adaptive" }, { label: "Flat", value: "flat" } ]
                                onPicked: v => app.act(["input", "set", "mouse_accel", v])
                            }
                        }
                        UiRow {
                            theme: app.theme; title: "Scroll speed"
                            UiSegment {
                                theme: app.theme; current: app.st.input.mouseScroll
                                options: [ { label: "Slow", value: 0.5 }, { label: "Normal", value: 1 }, { label: "Fast", value: 2 }, { label: "Very fast", value: 3 } ]
                                onPicked: v => app.act(["input", "set", "mouse_scroll", String(v)])
                            }
                        }
                        UiRow {
                            theme: app.theme; title: "Natural scrolling"; subtitle: "The page follows the wheel, like a phone."
                            Toggle { theme: app.theme; on: app.st.input.mouseNatural; onToggled: app.act(["input", "set", "mouse_natural", app.st.input.mouseNatural ? "false" : "true"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Left-handed"; subtitle: "Swaps the left and right buttons."
                            Toggle { theme: app.theme; on: app.st.input.leftHanded; onToggled: app.act(["input", "set", "left_handed", app.st.input.leftHanded ? "false" : "true"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Mouse for games"
                            subtitle: "Flat profile for every real mouse, no acceleration. The touchpad is not touched."
                            Toggle { theme: app.theme; on: app.st.mouse; onToggled: app.act(["toggle-mouse"]) }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        icon: "\uf0c8"; title: "Touchpad"
                        UiRow {
                            theme: app.theme; title: "Natural scrolling"; subtitle: "Two fingers up moves the page up."
                            Toggle { theme: app.theme; on: app.st.input.tpNatural; onToggled: app.act(["input", "set", "tp_natural", app.st.input.tpNatural ? "false" : "true"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Scroll speed"
                            UiSegment {
                                theme: app.theme; current: app.st.input.tpScroll
                                options: [ { label: "Slow", value: 0.3 }, { label: "Calm", value: 0.5 }, { label: "Normal", value: 0.8 }, { label: "Fast", value: 1.2 }, { label: "Very fast", value: 2 } ]
                                onPicked: v => app.act(["input", "set", "tp_scroll", String(v)])
                            }
                        }
                        UiRow {
                            theme: app.theme; title: "Tap to click"
                            Toggle { theme: app.theme; on: app.st.input.tpTap; onToggled: app.act(["input", "set", "tp_tap", app.st.input.tpTap ? "false" : "true"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Ignore the touchpad while typing"
                            Toggle { theme: app.theme; on: app.st.input.tpDwt; onToggled: app.act(["input", "set", "tp_dwt", app.st.input.tpDwt ? "false" : "true"]) }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        icon: "\uf11c"; title: "Keyboard layouts"
                        subtitle: "ALT + SHIFT switches between them."
                        UiRow {
                            theme: app.theme; title: "Installed"; subtitle: app.st.layouts.replace(/,/g, "   \u00b7   ")
                            UiButton { theme: app.theme; text: "Add or remove..."; onClicked: app.act(["open", "layouts"]) }
                        }
                    }
                }

                // =================================================== WIDGETS
                ColumnLayout {
                    visible: app.page === 4
                    Layout.fillWidth: true; spacing: 16
                    UiCard {
                        theme: app.theme
                        icon: "\uf009"; title: "On the desktop and in the bar"
                        subtitle: "Net speed and media output are off until you switch them on."
                        Repeater {
                            model: app.widgets
                            delegate: UiRow {
                                required property var modelData
                                theme: app.theme; title: modelData.name
                                Toggle { theme: app.theme; on: modelData.enabled; onToggled: app.widgetToggled(modelData.id, !modelData.enabled) }
                            }
                        }
                        UiButton { theme: app.theme; icon: "\uf047"; text: "Move the widgets"; onClicked: app.moveWidgetsRequested() }
                    }
                }

                // =================================================== PRIVACY
                ColumnLayout {
                    visible: app.page === 5
                    Layout.fillWidth: true; spacing: 16
                    UiCard {
                        theme: app.theme
                        icon: "\uf030"; title: "Camera"
                        subtitle: "Switching the camera off blocks it for every app (the driver is unloaded). Apps that run in a Flatpak sandbox can also be allowed or blocked one by one."
                        UiRow {
                            theme: app.theme; title: "Camera access"
                            subtitle: !app.camera.present ? "No camera found on this computer."
                                      : (app.camera.blocked ? "Off: no app can use the camera." : "On: apps may ask to use the camera.")
                            Toggle { theme: app.theme; on: !app.camera.blocked; opacity: app.camera.present ? 1 : 0.4
                                     onToggled: if (app.camera.present) app.act(["camera", app.camera.blocked ? "unblock" : "block"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Using the camera right now"
                            subtitle: app.camera.inUse.length > 0 ? app.camera.inUse.join(",  ") : "No app."
                            UiButton { theme: app.theme; text: "Refresh"; onClicked: app.loadCamera() }
                        }
                        Repeater {
                            model: app.camera.portal
                            delegate: UiRow {
                                id: crow
                                required property var modelData
                                theme: app.theme; title: modelData.app; subtitle: modelData.allowed ? "Allowed" : "Blocked"
                                Toggle { theme: app.theme; on: crow.modelData.allowed
                                         onToggled: app.act(["camera", "portal", crow.modelData.app, crow.modelData.allowed ? "no" : "yes"]) }
                            }
                        }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.Wrap; color: app.theme.dim
                            text: "Apps that are not sandboxed open the camera directly, so only the main switch above can stop them."
                            font.family: app.theme.font; font.pixelSize: app.theme.size - 3
                        }
                    }
                    UiCard {
                        theme: app.theme
                        icon: "\uf124"; title: "Location"
                        subtitle: "Which apps may ask where you are. Changing it asks for your password."
                        Text {
                            visible: app.st.geo.length === 0
                            text: "GeoClue lists no apps yet. Add one below."; color: app.theme.dim
                            font.family: app.theme.font; font.pixelSize: app.theme.size - 1
                        }
                        Repeater {
                            model: app.st.geo
                            delegate: UiRow {
                                id: grow
                                required property var modelData
                                theme: app.theme; title: modelData.app; subtitle: modelData.allowed ? "Allowed" : "Blocked"
                                Toggle { theme: app.theme; on: grow.modelData.allowed
                                         onToggled: app.act(["geo", grow.modelData.app, grow.modelData.allowed ? "false" : "true"]) }
                            }
                        }
                        RowLayout {
                            spacing: 8
                            UiInput { id: geoApp; theme: app.theme; placeholder: "App id, e.g. firefox"; implicitWidth: 260
                                      onAccepted: geoAdd.clicked() }
                            UiButton { id: geoAdd; theme: app.theme; text: "Allow this app"
                                       onClicked: { if (/^[A-Za-z0-9._-]+$/.test(geoApp.text)) { app.act(["geo", geoApp.text, "true"]); geoApp.text = "" } } }
                        }
                    }
                }

                // =================================================== APPS
                ColumnLayout {
                    visible: app.page === 6
                    Layout.fillWidth: true; spacing: 16

                    UiCard {
                        theme: app.theme
                        icon: "\uf00a"; title: "Default apps"
                        subtitle: "Click Change, then pick the app that should open it. The change is saved at once."
                        Text {
                            visible: app.appRoles.length === 0
                            text: "Loading..."; color: app.theme.dim
                            font.family: app.theme.font; font.pixelSize: app.theme.size - 1
                        }
                        Repeater {
                            model: app.appRoles
                            delegate: ColumnLayout {
                                id: role
                                required property var modelData
                                Layout.fillWidth: true; spacing: 8
                                UiRow {
                                    theme: app.theme; title: role.modelData.label; subtitle: role.modelData.current
                                    UiButton {
                                        theme: app.theme; kind: app.openRole === role.modelData.id ? "primary" : "secondary"
                                        text: app.openRole === role.modelData.id ? "Close" : "Change"
                                        onClicked: app.openRole = (app.openRole === role.modelData.id ? "" : role.modelData.id)
                                    }
                                }
                                Flow {
                                    visible: app.openRole === role.modelData.id
                                    Layout.fillWidth: true; spacing: 6
                                    Repeater {
                                        model: role.modelData.candidates
                                        delegate: UiButton {
                                            required property var modelData
                                            theme: app.theme; text: modelData.name
                                            kind: modelData.name === role.modelData.current || modelData.file === role.modelData.current ? "primary" : "secondary"
                                            onClicked: { app.act(["apps", "set", role.modelData.id, modelData.file]); reloadApps.restart() }
                                        }
                                    }
                                    Text {
                                        visible: role.modelData.candidates.length === 0
                                        text: "No installed app can do this."; color: app.theme.dim
                                        font.family: app.theme.font; font.pixelSize: app.theme.size - 2
                                    }
                                }
                            }
                        }
                        Timer { id: reloadApps; interval: 900; onTriggered: app.loadApps() }
                    }

                    UiCard {
                        theme: app.theme
                        icon: "\uf15b"; title: "By file type"
                        subtitle: "For exact control: pick the app for one kind of file, for example image/png or application/pdf."
                        UiButton {
                            visible: app.mimes.length === 0
                            theme: app.theme; text: app.mimesLoading ? "Loading file types..." : "Show file types"; active: !app.mimesLoading
                            onClicked: app.loadMimes()
                        }
                        UiInput { id: mimeFilter; visible: app.mimes.length > 0; theme: app.theme; placeholder: "Search, e.g. png, pdf, video, text"; Layout.fillWidth: true }
                        Repeater {
                            model: app.mimes.filter(m => mimeFilter.text.trim() === "" ? false : m.mime.toLowerCase().indexOf(mimeFilter.text.trim().toLowerCase()) >= 0).slice(0, 8)
                            delegate: ColumnLayout {
                                id: mrow
                                required property var modelData
                                Layout.fillWidth: true; spacing: 8
                                UiRow {
                                    theme: app.theme; title: mrow.modelData.mime; subtitle: mrow.modelData.current !== "" ? mrow.modelData.current : "not set"
                                    UiButton {
                                        theme: app.theme; text: app.openMime === mrow.modelData.mime ? "Close" : "Change"
                                        onClicked: {
                                            if (app.openMime === mrow.modelData.mime) { app.openMime = ""; return }
                                            app.openMime = mrow.modelData.mime; app.mimeCands = []
                                            app.callApi(["mime", "candidates", mrow.modelData.mime], t => { app.mimeCands = app.parse(t, []) })
                                        }
                                    }
                                }
                                Flow {
                                    visible: app.openMime === mrow.modelData.mime
                                    Layout.fillWidth: true; spacing: 6
                                    Repeater {
                                        model: app.mimeCands
                                        delegate: UiButton {
                                            required property var modelData
                                            theme: app.theme; text: modelData.name
                                            kind: modelData.name === mrow.modelData.current ? "primary" : "secondary"
                                            onClicked: {
                                                app.act(["mime", "set", mrow.modelData.mime, modelData.file])
                                                const list = app.mimes.slice()
                                                for (const m of list) if (m.mime === mrow.modelData.mime) m.current = modelData.name
                                                app.mimes = list
                                                app.openMime = ""
                                            }
                                        }
                                    }
                                    Text {
                                        visible: app.mimeCands.length === 0
                                        text: "Looking for apps..."; color: app.theme.dim
                                        font.family: app.theme.font; font.pixelSize: app.theme.size - 2
                                    }
                                }
                            }
                        }
                    }
                }

                // =================================================== SHORTCUTS
                ColumnLayout {
                    visible: app.page === 7
                    Layout.fillWidth: true; spacing: 16

                    Rectangle {
                        visible: app.bindMsg !== ""
                        Layout.fillWidth: true; implicitHeight: 44
                        color: app.bindMsg.startsWith("Saved") ? Qt.rgba(0.05, 0.73, 0.84, 0.12) : Qt.rgba(0.97, 0.46, 0.56, 0.14)
                        border.width: 1; border.color: app.bindMsg.startsWith("Saved") ? app.theme.icon : app.theme.red
                        Text { anchors { fill: parent; leftMargin: 16; rightMargin: 12 } verticalAlignment: Text.AlignVCenter
                               text: app.bindMsg; color: app.theme.bright; elide: Text.ElideRight
                               font.family: app.theme.font; font.pixelSize: app.theme.size - 1 }
                    }

                    UiCard {
                        theme: app.theme
                        icon: "\uf11c"; title: "Your shortcuts"
                        subtitle: "Click Change, then press the keys you want. Combinations that are already taken are refused with the name of what uses them."
                        Repeater {
                            model: app.binds
                            delegate: UiRow {
                                id: brow
                                required property var modelData
                                theme: app.theme; title: modelData.desc
                                Rectangle {
                                    implicitWidth: kt.implicitWidth + 22; implicitHeight: 30
                                    color: app.captureId === brow.modelData.id ? Qt.rgba(0.88, 0.69, 0.41, 0.16) : Qt.rgba(0, 0, 0, 0.28)
                                    border.width: 1; border.color: app.captureId === brow.modelData.id ? "#e0af68" : Qt.rgba(1, 1, 1, 0.12)
                                    Text { id: kt; anchors.centerIn: parent
                                           text: app.captureId === brow.modelData.id ? "Press the new keys..." : brow.modelData.keys
                                           color: brow.modelData.custom ? app.theme.icon : app.theme.bright; font.bold: true
                                           font.family: app.theme.font; font.pixelSize: app.theme.size - 1 }
                                }
                                UiButton {
                                    theme: app.theme; text: app.captureId === brow.modelData.id ? "Cancel" : "Change"
                                    onClicked: { app.bindMsg = ""; app.captureId = (app.captureId === brow.modelData.id ? "" : brow.modelData.id) }
                                }
                            }
                        }
                        UiButton {
                            theme: app.theme; kind: "danger"; text: "Reset every shortcut to the default"
                            onClicked: app.callApi(["binds", "reset"], t => { app.bindMsg = "Saved: all shortcuts are back to the defaults"; app.loadBinds() })
                        }
                    }

                    UiCard {
                        theme: app.theme
                        icon: "\uf023"; title: "Built in (cannot be changed)"
                        subtitle: "Window, workspace and layout keys that always work."
                        Repeater {
                            model: app.fixedBinds
                            delegate: UiRow {
                                required property var modelData
                                theme: app.theme; title: modelData.desc
                                Text { text: modelData.keys; color: app.theme.dim; font.bold: true
                                       font.family: app.theme.font; font.pixelSize: app.theme.size - 1 }
                            }
                        }
                    }
                }

                // =================================================== SYSTEM
                ColumnLayout {
                    visible: app.page === 8
                    Layout.fillWidth: true; spacing: 16
                    UiCard {
                        theme: app.theme
                        icon: "\uf186"; title: "Screen"
                        UiRow {
                            theme: app.theme; title: "Night mode"; subtitle: "Warmer colors in the evening."
                            Toggle { theme: app.theme; on: app.st.night; onToggled: app.act(["toggle-night"]) }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        icon: "\uf023"; title: "Password dialog"
                        subtitle: "The window that asks for your password (pkexec, GParted, Ventoy...)."
                        UiRow {
                            theme: app.theme; title: "Style"
                            UiSegment {
                                theme: app.theme; current: app.st.polkitClassic ? "classic" : "themed"
                                options: [ { label: "Themed", value: "themed" }, { label: "Classic", value: "classic" } ]
                                onPicked: v => app.act(["polkit", v])
                            }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        icon: "\uf1f8"; title: "Free up disk space"
                        subtitle: "Removes the package cache, old logs and other leftovers. Opens in a terminal so you see what happens."
                        UiButton { theme: app.theme; icon: "\uf1f8"; text: "Clean up the system"; onClicked: app.act(["open", "cleanup"]) }
                    }
                }
            }
        }
    }
}
