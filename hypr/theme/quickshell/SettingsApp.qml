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
                        layouts: "", monitors: [], geo: [], wifi: [], sinks: [], defaultSink: "", dns: "" })
    property var pending: null                     // a display change waiting for "Keep / Revert": { name, oldRec, newRec }
    property int pendingLeft: 0
    property string confirmForget: ""              // uuid of the Wi-Fi network that asks "really forget?"

    readonly property var pages: [
        { name: "Display",  icon: "\uf108" },
        { name: "Network",  icon: "\uf1eb" },
        { name: "Sound",    icon: "\uf028" },
        { name: "Input",    icon: "\uf11c" },
        { name: "Widgets",  icon: "\uf009" },
        { name: "Privacy",  icon: "\uf124" },
        { name: "Apps",     icon: "\uf00a" },
        { name: "System",   icon: "\uf013" }
    ]

    screen: Quickshell.screens[0]
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"

    onVisibleChanged: if (visible) refresh()

    // ---- talking to the backend ----
    function refresh() { if (!stateProc.running) stateProc.running = true }
    Process {
        id: stateProc
        command: ["sh", app.api, "state"]
        stdout: StdioCollector {
            onStreamFinished: { try { app.st = JSON.parse(text) } catch (e) { console.warn("Settings state: " + e) } }
        }
    }
    property var queue: []
    function act(args) {
        if (args[0] === "open") closeRequested()     // menus opened from here need the keyboard, so this window gets out of the way
        queue = queue.concat([args]); if (!actProc.running) runNext() }
    function runNext() {
        if (queue.length === 0) { refresh(); return }
        const a = queue[0]; queue = queue.slice(1)
        actProc.command = ["sh", app.api].concat(a)
        actProc.running = true
    }
    Process { id: actProc; onExited: app.runNext() }
    Timer { interval: 4000; running: app.visible; repeat: true; onTriggered: if (!actProc.running) app.refresh() }

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

    // ---- window ----
    Shortcut { sequence: "Escape"; onActivated: app.closeRequested() }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.55); MouseArea { anchors.fill: parent; onClicked: app.closeRequested() } }

    Rectangle {
        id: win
        anchors.centerIn: parent
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
                Text {
                    Layout.leftMargin: 8; Layout.topMargin: 6; Layout.bottomMargin: 14
                    text: "Settings"; color: app.theme.bright; font.bold: true
                    font.family: app.theme.font; font.pixelSize: app.theme.size + 6
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

                Text {
                    text: app.pages[app.page].name
                    color: app.theme.bright; font.bold: true
                    font.family: app.theme.font; font.pixelSize: app.theme.size + 10
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
                        border.width: 1; border.color: app.theme.yellow
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
                            title: modelData.name + (modelData.make ? "   " + modelData.make + " " + modelData.model : "")
                            subtitle: modelData.width + " x " + modelData.height + " at " + Math.round(modelData.rate) + " Hz, scale " + modelData.scale

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
                        title: "Stretched resolution for games"
                        subtitle: "Run a game at 4:3 and stretch it over the whole 16:9 screen. Add  krmv-stretch %command%  to the game's Steam launch options once; this switch then turns it on and off. Uses gamescope."
                        UiRow {
                            theme: app.theme; title: "Stretch"
                            Toggle { theme: app.theme; on: app.st.stretch.enabled; onToggled: app.act(["stretch", "enabled", app.st.stretch.enabled ? "0" : "1"]) }
                        }
                        UiRow {
                            theme: app.theme; title: "Game resolution"
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
                        title: "Wi-Fi networks you know"
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
                        UiButton { theme: app.theme; icon: "\uf067"; text: "Connect to a new network"; onClicked: app.act(["open", "wifi-new"]) }
                    }

                    UiCard {
                        theme: app.theme
                        title: "Private DNS"
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
                        title: "Where the sound goes"
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
                        title: "Laptop speakers too quiet?"
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
                        title: "Mouse"
                        UiRow {
                            theme: app.theme; title: "Mouse for games"
                            subtitle: "Flat profile, no acceleration: a fast flick moves the cursor exactly as far as the mouse moved. The touchpad is not touched."
                            Toggle { theme: app.theme; on: app.st.mouse; onToggled: app.act(["toggle-mouse"]) }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        title: "Keyboard layouts"
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
                        title: "On the desktop and in the bar"
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
                        title: "Location"
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
                        title: "Default apps"
                        subtitle: "Which app opens web links, files, images, videos, PDFs, music..."
                        UiButton { theme: app.theme; text: "Choose default apps..."; onClicked: app.act(["open", "apps"]) }
                    }
                    UiCard {
                        theme: app.theme
                        title: "Keyboard shortcuts"
                        subtitle: "See every shortcut, or change the ones you can change."
                        UiButton { theme: app.theme; text: "Open the shortcut list..."; onClicked: app.act(["open", "shortcuts"]) }
                    }
                }

                // =================================================== SYSTEM
                ColumnLayout {
                    visible: app.page === 7
                    Layout.fillWidth: true; spacing: 16
                    UiCard {
                        theme: app.theme
                        title: "Screen"
                        UiRow {
                            theme: app.theme; title: "Night mode"; subtitle: "Warmer colors in the evening."
                            Toggle { theme: app.theme; on: app.st.night; onToggled: app.act(["toggle-night"]) }
                        }
                    }
                    UiCard {
                        theme: app.theme
                        title: "Password dialog"
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
                        title: "Free up disk space"
                        subtitle: "Removes the package cache, old logs and other leftovers. Opens in a terminal so you see what happens."
                        UiButton { theme: app.theme; icon: "\uf1f8"; text: "Clean up the system"; onClicked: app.act(["open", "cleanup"]) }
                    }
                }
            }
        }
    }
}
