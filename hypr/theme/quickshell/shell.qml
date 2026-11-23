// ~/.config/hypr/theme/quickshell/shell.qml
// Other files: Chip, Slider, RamIcon, Clock, Toggle, TrayMenu, NetPanel, BtPanel, PowerMenu, Osd, MediaWidget, MarqueeText, ClockFace, DesktopClock, WidgetMover, ClockEngine, ClockPanel, AlarmRing, PanelButton, Notifications, NotificationCard, NetSpeedWidget, MediaOutputWidget, MediaControls, MediaExtras (.qml) - must live in this same folder
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Widgets

ShellRoot {
    id: root

    // ---- Theme (Tokyo Night) ----
    readonly property var theme: ({
        bg: "#1a1b26", fg: "#a9b1d6", muted: "#444b6a", cyan: "#0db9d7",
        bright: "#c0caf5", purple: "#ad8ee6", red: "#f7768e", yellow: "#e0af68", blue: "#7aa2f7",
        dim: "#787c99",         // secondary text
        icon: "#0db9d7",        // ONE color for ALL icons (off state: muted, problem: red)
        font: "JetBrainsMono Nerd Font", size: 14,
        naturalScroll: false,   // keep false: Hyprland already handles scroll direction (the sliders detect a trackpad themselves)
        trayHide: ["nm-applet", "networkmanager", "nm-tray", "blueman"]  // tray apps to hide (matched against id or title)
    })

    // ---- State ----
    property string openPanel: ""          // "", "wifi", "bt", "clock"
    property bool powerOpen: false         // the full-screen power menu
    property string activePopup: ""        // which bar icon owns the hover popup (only one at a time)
    property bool volEngaged: false        // volume icon / popup in use (then no OSD)
    property bool brightEngaged: false
    property bool osdReady: false          // ignore the changes that happen while the bar starts
    property string cpuTip: "CPU\nmeasuring..."
    property string memTip: "RAM\n..."
    property string diskTip: "Disk\n..."
    property bool cpuHover: false
    property bool memHover: false
    property bool diskHover: false
    readonly property bool statsActive: cpuHover || memHover || diskHover   // stats are sampled ONLY while hovering
    property bool hasBright: false
    property real brightPct: 0             // 0..1
    property real pendingBright: 0
    property bool brightDirty: false
    property bool wifiOn: false
    property string netType: "none"        // "ethernet" | "wifi" | "none"
    property bool ethUp: false
    property string wifiName: ""
    property bool btOn: false
    property bool hasBat: false
    property int batPct: 0
    property bool batCharging: false
    property double closedAt: 0
    property string closedName: ""
    property real lastTotal: 0
    property real lastIdle: 0

    // ---- Battery: UPower events (instant). Falls back to slow /sys polling when UPower is not running ----
    readonly property var upDev: UPower.displayDevice
    readonly property bool upOk: upDev !== null && upDev !== undefined && upDev.energyCapacity > 0
    readonly property real upPct: upOk ? Math.max(0, Math.min(100, upDev.energy / upDev.energyCapacity * 100)) : 0
    // UPower states: 1 charging, 2 discharging, 3 empty, 4 fully charged, 5 pending charge, 6 pending discharge
    readonly property int upState: upOk ? Number(upDev.state) : 0
    readonly property bool hasBatt: upOk || hasBat
    readonly property real battPct: upOk ? upPct : batPct
    readonly property bool battCharging: upOk ? (upState === 1 || upState === 4 || upState === 5) : batCharging

    function fmtDur(sec) {
        sec = Math.round(sec)
        if (sec <= 0) return "calculating..."
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return (h > 0 ? h + " h " : "") + m + " min"
    }
    readonly property string batTip: {
        if (!hasBatt) return ""
        const lines = ["Battery", "Charge: " + Math.round(battPct) + "%"]
        if (!upOk) { lines.push("Status: " + (battCharging ? "Plugged in" : "On battery")); return lines.join("\n") }
        const d = upDev
        const names = { 1: "Charging", 2: "Discharging", 3: "Empty", 4: "Fully charged", 5: "Plugged in, not charging", 6: "On battery" }
        lines.push("Status: " + (names[upState] || "Unknown"))
        if (upState === 1) lines.push("Until full: " + fmtDur(d.timeToFull))
        else if (upState === 2) lines.push("Time left: " + fmtDur(d.timeToEmpty))
        if (Math.abs(d.changeRate) > 0.05) lines.push("Power: " + Math.abs(d.changeRate).toFixed(1) + " W (" + (d.changeRate > 0 ? "charging" : "using") + ")")
        if (d.healthSupported) {
            const h = d.healthPercentage <= 1 ? d.healthPercentage * 100 : d.healthPercentage
            lines.push("Health: " + Math.round(h) + "%")
        }
        lines.push("Energy: " + d.energy.toFixed(1) + " / " + d.energyCapacity.toFixed(1) + " Wh")
        return lines.join("\n")
    }

    // ---- Volume: PipeWire events (instant, no polling) ----
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool hasAudio: sink !== null && sink !== undefined && sink.audio !== null && sink.audio !== undefined
    readonly property real volume: hasAudio ? sink.audio.volume : 0
    readonly property bool muted: hasAudio ? sink.audio.muted : false
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    function setVolume(v) { if (hasAudio) sink.audio.volume = Math.max(0, Math.min(1, v)) }
    function toggleMute() { if (hasAudio) sink.audio.muted = !sink.audio.muted }
    // 5% per mouse-wheel notch (120 units); a trackpad sends many small amounts, so it scrolls smoothly
    function scrollDelta(dy) { return (theme.naturalScroll ? -dy : dy) / 120 * 0.05 }
    // Volume / brightness: wheel up OR two fingers up = more, on every device.
    // A mouse wheel notch is always a multiple of 120 and keeps its direction. Anything else is a touchpad,
    // which (natural scrolling) reports the opposite sign, so it is flipped: two fingers up = more.
    function controlScrollDelta(dy, inverted) {
        const notch = Math.abs(dy) >= 120 && Math.abs(dy) % 120 === 0
        return (notch ? dy : -dy) / 120 * 0.05
    }

    // ---- Per-app volume mixer (opened with the small arrow in the volume popup) ----
    // Every app that has an audio stream is listed (playing or paused), one row per app. Apps that are running and can
    // make sound but have no stream right now (Telegram, Discord, ...) are listed too, and THEIR slider works as well:
    // the volume you set is remembered and applied the moment the app starts making sound.
    readonly property var appNames: ({
        steam: "Steam", telegram: "Telegram", discord: "Discord", vesktop: "Discord", spotify: "Spotify",
        torbrowser: "Tor Browser", firefox: "Firefox", chrome: "Chrome", chromium: "Chromium", brave: "Brave",
        vlc: "VLC", mpv: "mpv", zoom: "Zoom", slack: "Slack", teams: "Teams", signal: "Signal",
        element: "Element", obs: "OBS", whatsapp: "WhatsApp", thunderbird: "Thunderbird", skype: "Skype"
    })
    function friendly(str) {      // "steamwebhelper" -> "Steam", "org.telegram.desktop" -> "Telegram"
        const n = String(str || "").toLowerCase().replace(/[^a-z0-9]/g, "")
        for (const k in appNames) if (n.indexOf(k) >= 0) return appNames[k]
        return ""
    }
    function appName(n) {
        const p = n.properties
        return friendly(p["application.process.binary"]) || friendly(p["application.name"])
               || p["application.name"] || n.description || n.name
    }
    readonly property var rawStreams: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio !== null)
    PwObjectTracker { objects: root.rawStreams }
    function buildGroups(list) {
        const map = {}, out = []
        for (let i = 0; i < list.length; i++) {
            const n = list[i]
            if (!n.ready) continue
            const nm = appName(n)
            if (!map[nm]) { map[nm] = { name: nm, nodes: [] }; out.push(map[nm]) }
            map[nm].nodes.push(n)
        }
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }
    readonly property var appGroups: buildGroups(rawStreams)

    property var runningClasses: []
    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl clients -j | jq -r '.[].class'"]
        stdout: StdioCollector { onStreamFinished: root.runningClasses = text.trim().split("\n") }
    }
    function refreshClients() { clientsProc.running = true }
    function computeSilent() {
        const have = {}
        appGroups.forEach(g => { have[g.name] = true })
        const out = []
        runningClasses.forEach(c => { const f = friendly(c); if (f && !have[f] && out.indexOf(f) < 0) out.push(f) })
        return out
    }
    readonly property var silentApps: computeSilent()
    readonly property var appRows: {
        const rows = appGroups.slice()
        silentApps.forEach(nm => rows.push({ name: nm, nodes: [] }))
        return rows
    }

    // Remembered per-app volumes: { "Telegram": { vol: 0.4, muted: false }, ... }
    property var appPrefs: ({})
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", root.stateDir + "/app-volumes.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { root.appPrefs = JSON.parse(text) } catch (e) {} }
        }
    }
    Process { id: prefsSave }
    Timer {
        id: prefsSaveTimer
        interval: 500
        onTriggered: {
            prefsSave.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/app-volumes.json\"", "_", root.stateDir, JSON.stringify(root.appPrefs)]
            prefsSave.running = true
        }
    }
    function setPref(name, vol, muted) {
        const p = Object.assign({}, appPrefs)
        const old = p[name] || { vol: 1.0, muted: false }
        p[name] = { vol: vol !== undefined ? vol : old.vol, muted: muted !== undefined ? muted : old.muted }
        appPrefs = p
        prefsSaveTimer.restart()
    }
    // When a stream appears for an app with a remembered volume, apply it (once per stream)
    property var appliedNodes: ({})
    function applyPrefs() {
        for (const g of appGroups) {
            const pref = appPrefs[g.name]
            if (!pref) continue
            for (const n of g.nodes) {
                if (!n.audio || appliedNodes[n.id]) continue
                n.audio.volume = pref.vol
                n.audio.muted = pref.muted
                appliedNodes[n.id] = true
            }
        }
    }
    Timer { id: applyTimer; interval: 500; onTriggered: root.applyPrefs() }   // a moment after the stream appears
    onAppGroupsChanged: applyTimer.restart()

    Component {
        id: appMixer
        Column {
            width: parent ? parent.width : 300
            spacing: 12
            Component.onCompleted: root.refreshClients()

            Rectangle { width: parent.width; height: 1; color: root.theme.muted }

            Text {
                visible: root.appRows.length === 0
                text: "No apps with audio"
                color: root.theme.dim
                font.family: root.theme.font; font.pixelSize: root.theme.size - 1
            }

            Repeater {
                model: root.appRows
                delegate: ColumnLayout {
                    id: appRow
                    required property var modelData
                    readonly property bool hasStream: modelData.nodes.length > 0
                    readonly property var pref: root.appPrefs[modelData.name]
                    width: parent.width
                    spacing: 4

                    readonly property real avgVol: {
                        if (!hasStream) return pref ? pref.vol : 1.0
                        let sum = 0, cnt = 0
                        for (const n of modelData.nodes) if (n.audio) { sum += n.audio.volume; cnt++ }
                        return cnt > 0 ? sum / cnt : (pref ? pref.vol : 1.0)
                    }
                    readonly property bool allMuted: {
                        if (!hasStream) return pref ? pref.muted : false
                        let any = false
                        for (const n of modelData.nodes) if (n.audio) { any = true; if (!n.audio.muted) return false }
                        return any
                    }
                    // Volume is written two ways: through Quickshell and through wpctl (the stream's PipeWire id),
                    // so the slider works whichever of them the app's stream accepts.
                    property real pendingVol: -1
                    function sendWp() {
                        // third path: the PulseAudio sink-input API, which pipewire-pulse applies to every app
                        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/hypr/scripts/appvol.sh", modelData.name, String(Math.round(pendingVol * 100))])
                        for (const n of modelData.nodes) Quickshell.execDetached(["wpctl", "set-volume", String(n.id), pendingVol.toFixed(3)])
                        pendingVol = -1
                    }
                    Timer { id: wpTimer; interval: 70; onTriggered: if (appRow.pendingVol >= 0) appRow.sendWp() }
                    function setVol(v) {
                        for (const n of modelData.nodes) if (n.audio) n.audio.volume = v
                        pendingVol = v
                        if (!wpTimer.running) { sendWp(); wpTimer.start() }
                        root.setPref(modelData.name, v, undefined)
                    }
                    function toggleMute() {
                        const m = !allMuted
                        for (const n of modelData.nodes) {
                            if (n.audio) n.audio.muted = m
                            Quickshell.execDetached(["wpctl", "set-mute", String(n.id), m ? "1" : "0"])
                        }
                        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/hypr/scripts/appvol.sh", modelData.name, m ? "mute" : "unmute"])
                        root.setPref(modelData.name, undefined, m)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: appRow.modelData.name
                            color: root.theme.fg
                            font.family: root.theme.font; font.pixelSize: root.theme.size - 1
                        }
                        Text {
                            visible: !appRow.hasStream
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: "  no sound right now, applies when it plays"
                            color: root.theme.dim
                            font.family: root.theme.font; font.pixelSize: root.theme.size - 3
                        }
                        Item { visible: appRow.hasStream; Layout.fillWidth: true }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: appRow.allMuted ? "\uf026" : "\uf028"
                            color: appRow.allMuted ? root.theme.red : root.theme.icon
                            font.family: root.theme.font; font.pixelSize: root.theme.size + 1
                            MouseArea { anchors { fill: parent; margins: -4 } onClicked: appRow.toggleMute() }
                        }
                        Slider {
                            Layout.fillWidth: true
                            theme: root.theme
                            value: appRow.avgVol
                            onMoved: v => appRow.setVol(Math.max(0, Math.min(1, v)))
                        }
                        Text {
                            Layout.preferredWidth: 40
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(appRow.avgVol * 100) + "%"
                            color: root.theme.fg
                            font.family: root.theme.font; font.pixelSize: root.theme.size - 2
                        }
                    }
                }
            }
        }
    }

    // ---- Night mode (blue light filter, hyprsunset). Shown under the brightness slider. ----
    property bool nightOn: false
    Process {
        command: ["sh", "-c", "sh \"$HOME/.config/hypr/scripts/nightmode.sh\" status"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.nightOn = text.trim() === "on" }
    }
    function toggleNight() {
        nightOn = !nightOn
        Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/hypr/scripts/nightmode.sh", nightOn ? "on" : "off"])
        osd.showMessage("night", nightOn ? "Night mode on" : "Night mode off", "")
    }
    Component {
        id: nightMixer
        Column {
            width: parent ? parent.width : 280
            spacing: 12
            Rectangle { width: parent.width; height: 1; color: root.theme.muted }
            RowLayout {
                width: parent.width
                Text {
                    Layout.fillWidth: true
                    text: "\uf186   Night mode"
                    color: root.theme.fg
                    font.family: root.theme.font; font.pixelSize: root.theme.size
                }
                Toggle { theme: root.theme; on: root.nightOn; onToggled: root.toggleNight() }
            }
        }
    }

    // ---- Brightness: updates instantly in the bar, applies to the hardware at most every 60 ms ----
    function setBrightness(v) {
        brightPct = Math.max(0.01, Math.min(1, v))
        pendingBright = brightPct
        brightDirty = true
        if (!brightThrottle.running) flushBrightness()
    }
    function flushBrightness() {
        brightDirty = false
        Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(pendingBright * 100) + "%"])
        brightThrottle.start()
    }
    Timer { id: brightThrottle; interval: 60; onTriggered: if (root.brightDirty) root.flushBrightness() }

    // Backup path: scripts/brightness.sh also calls  qs -p <shell.qml> ipc call bar brightness
    IpcHandler {
        target: "bar"
        function brightness(): void { brightProc.running = true }
    }

    function closePanel() {
        if (openPanel !== "") { closedName = openPanel; closedAt = Date.now() }
        openPanel = ""
    }
    function togglePanel(name) {
        if (openPanel === name) { closePanel(); return }
        if (closedName === name && Date.now() - closedAt < 400) return   // the outside click was on this very icon
        openPanel = name
    }

    // ---- Keyboard layout indicator (EN / RU), updated by Hyprland events ----
    property string kbLayout: "EN"
    property string kbName: ""
    readonly property var kbCodes: ({ English: "EN", Russian: "RU", German: "DE", French: "FR", Spanish: "ES", Uzbek: "UZ",
        Turkish: "TR", Arabic: "AR", Italian: "IT", Ukrainian: "UA", Chinese: "ZH", Japanese: "JA", Korean: "KO",
        Portuguese: "PT", Polish: "PL", Kazakh: "KK", Kyrgyz: "KY", Tajik: "TG", Persian: "FA", Hindi: "HI" })
    function layoutCode(name) {
        const w = name.split(/[ (]/)[0]
        return kbCodes[w] !== undefined ? kbCodes[w] : name.substring(0, 2).toUpperCase()
    }
    function setLayout(name, announce) {
        const code = layoutCode(name)
        const changed = code !== kbLayout
        kbName = name
        kbLayout = code
        // info box when the layout is switched (not while the bar starts)
        if (announce && osdReady && changed) osd.showMessage("keyboard", name, "Keyboard layout: " + code)
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") setLayout(event.data.split(",").slice(1).join(","), true)
        }
    }
    Process {
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n1"]
        running: true
        stdout: StdioCollector { onStreamFinished: if (text.trim() !== "") root.setLayout(text.trim(), false) }
    }

    // ---- Clock app: timer, alarm, stopwatch, notes (the engine keeps running when the panel is closed) ----
    ClockEngine { id: clockEngine; panelOpen: root.openPanel === "clock" }
    AlarmRing { theme: root.theme; engine: clockEngine }

    // ---- Desktop widgets ----
    // The clock's place is remembered in ~/.local/state/krmv-setup/clock-position
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/krmv-setup"

    // ---- Network speed: one small /sys read every 2 s, shared by the bar chip and the desktop card ----
    property string netIface: ""
    property real netRxBytes: 0
    property real netTxBytes: 0
    property real netDownRate: 0              // bytes / second
    property real netUpRate: 0
    property real netPrevRx: 0
    property real netPrevTx: 0
    property real netPrevAt: 0

    function fmtRate(v) {
        v = Math.max(0, v)
        if (v >= 1048576) return (v / 1048576).toFixed(1) + "M"
        if (v >= 1024) return (v / 1024).toFixed(v >= 10240 ? 0 : 1) + "K"
        return Math.round(v) + "B"
    }
    function fmtBytes(v) {
        v = Math.max(0, v)
        if (v >= 1073741824) return (v / 1073741824).toFixed(2) + " GB"
        if (v >= 1048576) return (v / 1048576).toFixed(1) + " MB"
        if (v >= 1024) return (v / 1024).toFixed(1) + " KB"
        return Math.round(v) + " B"
    }
    readonly property string netSpeedText: "\u2193 " + fmtRate(netDownRate) + " \u2191 " + fmtRate(netUpRate)
    readonly property string netSpeedTip: "Interface: " + (netIface !== "" ? netIface : "none")
                                          + "\nReceived: " + fmtBytes(netRxBytes)
                                          + "\nSent: " + fmtBytes(netTxBytes)
                                          + "\nSpeed: \u2193 " + fmtRate(netDownRate) + " \u2191 " + fmtRate(netUpRate)

    Process {
        id: netSpeedProc
        command: ["sh", "-c", "iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}'); [ -n \"$iface\" ] || iface=$(ls /sys/class/net 2>/dev/null | grep -E '^(en|eth|wl)' | head -1); [ -n \"$iface\" ] || exit 0; echo \"$iface\"; cat /sys/class/net/$iface/statistics/rx_bytes 2>/dev/null || echo 0; cat /sys/class/net/$iface/statistics/tx_bytes 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n")
                if (p.length < 3 || p[0] === "") return
                if (p[0] !== root.netIface) root.netPrevAt = 0   // interface changed: skip the first rate sample
                root.netIface = p[0]
                const rx = parseFloat(p[1]) || 0, tx = parseFloat(p[2]) || 0
                const now = Date.now()
                if (root.netPrevAt > 0) {
                    const dt = Math.max(0.1, (now - root.netPrevAt) / 1000)
                    root.netDownRate = Math.max(0, (rx - root.netPrevRx) / dt)
                    root.netUpRate = Math.max(0, (tx - root.netPrevTx) / dt)
                }
                root.netPrevRx = rx; root.netPrevTx = tx; root.netPrevAt = now
                root.netRxBytes = rx; root.netTxBytes = tx
            }
        }
    }
    Timer {
        interval: 2000; running: root.widgetEnabled.netspeed === true || root.widgetEnabled.netspeedbar === true; repeat: true; triggeredOnStart: true
        onTriggered: netSpeedProc.running = true
    }

    property bool moveMode: false
    property int clockX: -1
    property int clockY: -1
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", root.stateDir + "/clock-position"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                if (p.length === 2 && !isNaN(p[0]) && !isNaN(p[1])) { root.clockX = parseInt(p[0]); root.clockY = parseInt(p[1]) }
            }
        }
    }
    // Places of the two cards (the clock keeps its own file, clock-position). -1 = default place under the clock.
    property int netX: -1
    property int netY: -1
    property int mediaX: -1
    property int mediaY: -1
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", root.stateDir + "/card-positions"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(v => parseInt(v))
                if (p.length === 4 && p.every(v => !isNaN(v))) { root.netX = p[0]; root.netY = p[1]; root.mediaX = p[2]; root.mediaY = p[3] }
            }
        }
    }
    Process { id: posSave }
    function savePositions(pos) {
        // only widgets that were switched on in the editor are moved; the others keep their place
        if (pos.clockOn) { clockX = Math.round(pos.clock[0]); clockY = Math.round(pos.clock[1]) }
        if (pos.netOn) { netX = Math.round(pos.net[0]); netY = Math.round(pos.net[1]) }
        if (pos.mediaOn) { mediaX = Math.round(pos.media[0]); mediaY = Math.round(pos.media[1]) }
        posSave.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s %s' \"$2\" \"$3\" > \"$1/clock-position\" && printf '%s %s %s %s' \"$4\" \"$5\" \"$6\" \"$7\" > \"$1/card-positions\"",
                           "_", stateDir, String(clockX), String(clockY), String(netX), String(netY), String(mediaX), String(mediaY)]
        posSave.running = true
    }
    function resetPositions() {
        clockX = -1; clockY = -1; netX = -1; netY = -1; mediaX = -1; mediaY = -1
        posSave.command = ["sh", "-c", "rm -f \"$1/clock-position\" \"$1/card-positions\"", "_", stateDir]
        posSave.running = true
    }
    // default places: the clock, then the net speed card below it, then the media card below that
    readonly property int clockTop: clockWidget.curY
    readonly property int netPosX: netX >= 0 ? netX : clockWidget.curX
    readonly property int netPosY: netY >= 0 ? netY : clockTop + (widgetEnabled.clock !== false ? clockWidget.height + 10 : 0)
    readonly property int mediaPosX: mediaX >= 0 ? mediaX : clockWidget.curX
    readonly property int mediaPosY: mediaY >= 0 ? mediaY : netPosY + (widgetEnabled.netspeed === true ? netWindow.height + 10 : 0)
    // Which desktop widgets are switched on. Clock stays on by default; the two new cards are off.
    property var widgetEnabled: ({ clock: true, netspeed: false, netspeedbar: false, mediaout: false })
    readonly property var widgetList: [
        { id: "clock", name: "Clock", enabled: widgetEnabled.clock !== false },
        { id: "netspeedbar", name: "Network speed (top bar)", enabled: widgetEnabled.netspeedbar === true },
        { id: "netspeed", name: "Network speed (desktop)", enabled: widgetEnabled.netspeed === true },
        { id: "mediaout", name: "Media output", enabled: widgetEnabled.mediaout === true }
    ]
    function setWidgetEnabled(id, on) {
        const w = Object.assign({}, widgetEnabled)
        w[id] = on
        widgetEnabled = w
        // feedback: a small info box says what happened
        let nm = id
        for (const it of widgetList) if (it.id === id) nm = it.name
        if (osdReady) osd.showMessage("widget", nm + (on ? " is ON" : " is OFF"), "")
        widgetsSave.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/widgets.json\"", "_", stateDir, JSON.stringify(w)]
        widgetsSave.running = true
    }
    function toggleWidget(id) { setWidgetEnabled(id, widgetEnabled[id] !== true) }
    // SUPER + SHIFT + W calls:  qs -p <shell.qml> ipc call widgets move
    // Toggles: qs -p <shell.qml> ipc call widgets netspeed | netspeedbar | mediaout
    IpcHandler {
        target: "widgets"
        function move(): void { root.moveMode = true }
        function clock(): void { root.togglePanel("clock") }               // SUPER + C
        function netspeed(): void { root.toggleWidget("netspeed") }          // desktop card
        function netspeedbar(): void { root.toggleWidget("netspeedbar") }    // top bar
        function mediaout(): void { root.toggleWidget("mediaout") }
        function status(): string { return JSON.stringify(root.widgetEnabled) }   // qs -p <shell.qml> ipc call widgets status
    }
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", root.stateDir + "/widgets.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.widgetEnabled = Object.assign({ clock: true, netspeed: false, netspeedbar: false, mediaout: false }, JSON.parse(text)) }
                catch (e) {}
            }
        }
    }
    Process { id: widgetsSave }

    // Password dialog (polkit agent) in the bar's theme. Loaded on its own so that an old Quickshell without the
    // polkit module cannot break the bar: then the stock hyprpolkitagent is started instead.
    Process {
        id: polkitFallback
        command: ["sh", "-c", "for b in /usr/lib/hyprpolkitagent/hyprpolkitagent /usr/libexec/hyprpolkitagent; do [ -x \"$b\" ] && exec \"$b\"; done; systemctl --user start hyprpolkitagent.service"]
    }
    // polkit-stock file (Settings > Password dialog) = use the classic hyprpolkitagent dialog instead of the themed one
    Process {
        id: polkitMode
        command: ["sh", "-c", "test -e \"$1/polkit-stock\"", "_", root.stateDir]
        running: true
        onExited: (code, st) => {
            if (code === 0) { polkitFallback.running = true; return }
            const c = Qt.createComponent("PolkitDialog.qml")
            const finish = () => {
                if (c.status === Component.Ready) { root.polkitObj = c.createObject(root, { theme: root.theme }); polkitBackup.start() }
                else if (c.status === Component.Error) { console.warn("PolkitDialog: " + c.errorString()); polkitFallback.running = true }
            }
            if (c.status === Component.Loading) c.statusChanged.connect(finish)
            else finish()
        }
    }
    // Live switching (Settings > Password dialog): the classic agent must be gone before the themed one can register.
    property var polkitObj: null
    Process { id: polkitStopStock; command: ["sh", "-c", "systemctl --user stop hyprpolkitagent.service 2>/dev/null; pkill -x hyprpolkitagent 2>/dev/null; true"]
        onExited: polkitStart.start() }
    Timer { id: polkitStart; interval: 700
        onTriggered: {
            if (root.polkitObj) return
            const c = Qt.createComponent("PolkitDialog.qml")
            if (c.status === Component.Ready) root.polkitObj = c.createObject(root, { theme: root.theme })
            else { console.warn("PolkitDialog: " + c.errorString()); polkitFallback.running = true }
        }
    }
    IpcHandler {
        target: "polkit"
        function themed(): void { polkitBackup.stop(); polkitStopStock.running = true }
        function classic(): void {
            if (root.polkitObj) { root.polkitObj.destroy(); root.polkitObj = null }
            polkitBackup.stop()
            polkitFallback.running = true
        }
    }
    // Safety net: if the themed agent could not register, the classic one takes over (a second agent just exits).
    Timer { id: polkitBackup; interval: 6000; onTriggered: polkitFallback.running = true }
    DesktopClock {
        id: clockWidget
        visible: !root.moveMode && root.widgetEnabled.clock !== false
        posX: root.clockX
        posY: root.clockY
        onMoveRequested: root.moveMode = true
    }
    DesktopWidgetWindow {
        id: netWindow
        visible: !root.moveMode && root.widgetEnabled.netspeed === true
        posX: root.netPosX
        posY: root.netPosY
        onMoveRequested: root.moveMode = true
        NetSpeedWidget {
            theme: root.theme
            iface: root.netIface
            downText: root.fmtRate(root.netDownRate) + "/s"
            upText: root.fmtRate(root.netUpRate) + "/s"
            receivedText: root.fmtBytes(root.netRxBytes)
            sentText: root.fmtBytes(root.netTxBytes)
        }
    }
    DesktopWidgetWindow {
        id: mediaWindow
        visible: !root.moveMode && root.widgetEnabled.mediaout === true
        posX: root.mediaPosX
        posY: root.mediaPosY
        onMoveRequested: root.moveMode = true
        MediaOutputWidget { theme: root.theme }
    }
    Switcher { theme: root.theme }

    // The Settings app (SUPER + I): sidebar with pages, backend is scripts/settings-api.sh
    property bool settingsOpen: false
    SettingsApp {
        visible: root.settingsOpen
        theme: root.theme
        widgets: root.widgetList
        onCloseRequested: root.settingsOpen = false
        onWidgetToggled: (id, on) => root.setWidgetEnabled(id, on)
        onMoveWidgetsRequested: { root.settingsOpen = false; root.moveMode = true }
    }
    IpcHandler {
        target: "settings"
        function open(): void { root.settingsOpen = true }
        function close(): void { root.settingsOpen = false }
        function toggle(): void { root.settingsOpen = !root.settingsOpen }
    }
    WidgetMover {
        visible: root.moveMode
        theme: root.theme
        widgets: root.widgetList
        startX: clockWidget.curX
        startY: clockWidget.curY
        faceW: clockWidget.width
        faceH: clockWidget.height
        netStartX: root.netPosX
        netStartY: root.netPosY
        mediaStartX: root.mediaPosX
        mediaStartY: root.mediaPosY
        onDone: positions => { root.savePositions(positions); root.moveMode = false }
        onResetRequested: { root.resetPositions(); root.moveMode = false }
        onCancelled: root.moveMode = false
        onWidgetToggled: (id, on) => root.setWidgetEnabled(id, on)
    }

    // ---- On-screen display for volume / brightness (Fn keys, scroll, sliders) and for messages ----
    Osd { id: osd; theme: root.theme }
    // scripts show a message with:  qs -p <shell.qml> ipc call osd message <icon> <text> <second line>
    IpcHandler {
        target: "osd"
        function message(icon: string, text: string, sub: string): void { osd.showMessage(icon, text, sub) }
        function mediakey(action: string): void { root.mediaKeyAction = action; mediaKeyTimer.restart() }
    }

    // ---- Media keys ----
    function pickMediaPlayer() {
        const ps = Mpris.players.values
        let paused = null
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying) return ps[i]
            if (paused === null && ps[i].playbackState === MprisPlaybackState.Paused) paused = ps[i]
        }
        return paused !== null ? paused : (ps.length > 0 ? ps[0] : null)
    }
    readonly property var mediaPlayer: pickMediaPlayer()
    // The info box appears ONLY for the media keys (the key script calls: ipc call osd mediakey <action>),
    // not when you click inside the player or press space in a video.
    property string mediaKeyAction: ""
    Timer { id: mediaKeyTimer; interval: 220; onTriggered: root.mediaKeyOsd() }     // let the player update first
    function mediaKeyOsd() {
        const p = mediaPlayer
        if (p === null) { osd.showMessage("music", "No media player", ""); return }
        if (mediaKeyAction === "next") osd.showMessage("next", p.trackTitle, p.trackArtist)
        else if (mediaKeyAction === "previous") osd.showMessage("prev", p.trackTitle, p.trackArtist)
        else osd.showMessage(p.isPlaying ? "play" : "pause", p.isPlaying ? "Playing" : "Paused", p.trackTitle)
    }
    Timer { interval: 4000; running: true; onTriggered: root.osdReady = true }
    onVolumeChanged: if (osdReady && !volEngaged) osd.show("volume", volume, muted)
    onMutedChanged: if (osdReady && !volEngaged) osd.show("volume", volume, muted)
    onBrightPctChanged: if (osdReady && hasBright && !brightEngaged) osd.show("brightness", brightPct, false)

    // ---- Notification daemon + popups (replaces mako) ----
    Notifications { theme: root.theme }

    // ---- Data collection (event driven or slow polling, to save battery) ----
    Process {
        id: statsProc
        command: ["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo; cut -d' ' -f1-3 /proc/loadavg; df -h --output=used,size,pcent / | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                const c = l[0].trim().split(/\s+/).slice(1).map(Number)
                const idle = c[3] + c[4]
                const total = c.reduce((a, b) => a + b, 0)
                let pct = "measuring..."
                if (root.lastTotal > 0) pct = Math.round(100 * (1 - (idle - root.lastIdle) / (total - root.lastTotal))) + "%"
                root.lastTotal = total
                root.lastIdle = idle
                root.cpuTip = "CPU\nUsage: " + pct + "\nLoad: " + l[3].trim()

                const mt = parseInt(l[1].replace(/\D/g, "")) / 1048576
                const ma = parseInt(l[2].replace(/\D/g, "")) / 1048576
                root.memTip = "RAM\nUsed: " + (mt - ma).toFixed(1) + " GB\nFree: " + ma.toFixed(1) + " GB\nTotal: " + mt.toFixed(1) + " GB"

                const d = l[4].trim().split(/\s+/)
                root.diskTip = "Disk (/)\nUsed: " + d[0] + "\nTotal: " + d[1] + "\nUsage: " + d[2]
            }
        }
    }
    // CPU/RAM/disk are only sampled while one of those icons is hovered
    onStatsActiveChanged: if (statsActive) lastTotal = 0
    Timer {
        interval: 500; running: root.statsActive; repeat: true; triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    Process {
        id: brightProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(",")
                root.hasBright = p.length >= 4
                if (root.hasBright && !root.brightDirty) root.brightPct = (parseFloat(p[3]) || 0) / 100
            }
        }
    }
    // The kernel announces every backlight change (Fn keys, brightnessctl, other apps) via udev:
    // zero polling, and the bar updates instantly. stdbuf keeps the output line-buffered.
    Process {
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        running: true
        stdout: SplitParser { onRead: brightDebounce.restart() }
    }
    Timer { id: brightDebounce; interval: 40; onTriggered: brightProc.running = true }
    Process {
        id: wifiProc
        command: ["sh", "-c", "nmcli radio wifi; echo --; nmcli -t -f TYPE,STATE device; echo --; nmcli -t -f active,ssid dev wifi | grep '^yes:' | head -1 | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("--\n")
                root.wifiOn = (parts[0] || "").trim() === "enabled"
                const devs = (parts[1] || "").trim().split("\n")
                root.ethUp = devs.indexOf("ethernet:connected") >= 0
                const wifiUp = devs.indexOf("wifi:connected") >= 0
                root.wifiName = (parts[2] || "").trim()
                root.netType = root.ethUp ? "ethernet" : (wifiUp ? "wifi" : "none")
            }
        }
    }
    // NetworkManager tells us about changes: no polling needed for the internet icon
    Process {
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser { onRead: nmDebounce.restart() }
    }
    Timer { id: nmDebounce; interval: 400; onTriggered: wifiProc.running = true }
    Process {
        id: btProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: StdioCollector { onStreamFinished: root.btOn = text.trim() === "on" }
    }
    Process {
        id: batProc
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -d \"$b\" ] && cat $b/capacity $b/status && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n")
                root.hasBat = l.length >= 2 && l[0] !== ""
                if (root.hasBat) {
                    root.batPct = parseInt(l[0])
                    root.batCharging = l[1] === "Charging" || l[1] === "Full"
                }
            }
        }
    }
    Timer {   // safety net for things without events: every 20 s
        interval: 20000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { wifiProc.running = true; btProc.running = true; brightProc.running = true }
    }
    Timer {   // only used when UPower is not available
        interval: 60000; running: !root.upOk; repeat: true; triggeredOnStart: true
        onTriggered: batProc.running = true
    }

    // ---- Per screen: bar + panels ----
    Variants {
        model: Quickshell.screens

        Scope {
            id: scope
            required property var modelData

            PanelWindow {
                id: bar
                screen: scope.modelData
                anchors { top: true; left: true; right: true }
                implicitHeight: 32
                color: root.theme.bg

                // Left
                RowLayout {
                    id: leftRow
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                    spacing: 14

                    Chip { theme: root.theme; icon: "\uf303"; onClicked: Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/hypr/scripts/launcher.sh"]) }

                    Repeater {
                        model: Hyprland.workspaces
                        delegate: Text {
                            required property var modelData
                            visible: modelData.id > 0
                            text: modelData.id
                            color: modelData.focused ? root.theme.cyan : root.theme.muted
                            font.family: root.theme.font; font.pixelSize: root.theme.size; font.bold: modelData.focused
                            MouseArea { anchors.fill: parent; onClicked: modelData.activate() }
                        }
                    }

                }

                // Center
                Clock {
                    id: barClock
                    anchors.centerIn: parent
                    theme: root.theme
                    engine: clockEngine
                    suppressPopup: root.openPanel === "clock"
                    onClicked: root.togglePanel("clock")
                }

                // Now playing: centered in the free space between the left group and the clock,
                // with equal breathing room on both sides instead of being glued to the clock.
                MediaWidget {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.round((leftRow.x + leftRow.width + barClock.x - width) / 2)
                    theme: root.theme
                    maxWidth: Math.max(120, barClock.x - (leftRow.x + leftRow.width) - 48)
                    activePopup: root.activePopup
                    onPopupRequested: root.activePopup = "media"
                }

                // Right
                RowLayout {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                    spacing: 14

                    Chip {
                        theme: root.theme
                        popupId: "netspeed"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "netspeed"
                        visible: root.widgetEnabled.netspeedbar === true
                        icon: "\uDB81\uDCC5"
                        label: root.netSpeedText
                        reserveLabel: "\u2193 99.9M \u2191 99.9M"
                        tip: root.netSpeedTip
                    }

                    Chip { theme: root.theme; icon: "\uf2db"; tip: root.cpuTip; popupId: "cpu"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "cpu"; onHoveredChanged: root.cpuHover = hovered }
                    Chip { theme: root.theme; ramIcon: true;    tip: root.memTip; popupId: "mem"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "mem"; onHoveredChanged: root.memHover = hovered }
                    Chip { theme: root.theme; icon: "\uf0a0"; tip: root.diskTip; popupId: "disk"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "disk"; onHoveredChanged: root.diskHover = hovered }

                    Chip {
                        theme: root.theme
                        icon: "\uf11c"
                        label: root.kbLayout
                        tip: "Current layout: " + root.kbLayout + (root.kbName !== "" ? " (" + root.kbName + ")" : "")
                             + "
Click or ALT + SHIFT: next layout"
                             + "
Right-click: add / remove layouts"
                        popupId: "kb"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "kb"
                        onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
                        onRightClicked: Quickshell.execDetached(["sh", Quickshell.env("HOME") + "/.config/hypr/scripts/layout.sh"])
                    }

                    Chip {
                        theme: root.theme
                        popupId: "bright"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "bright"
                        visible: root.hasBright
                        icon: "\uf185"
                        label: Math.round(root.brightPct * 100) + "%"
                        reserveLabel: "100%"
                        slider: true
                        sliderValue: root.brightPct
                        sliderTitle: "Brightness " + Math.round(root.brightPct * 100) + "%"
                        extra: nightMixer
                        onSliderMoved: v => root.setBrightness(v)
                        onEngagedChanged: root.brightEngaged = engaged
                        onScrolled: (dy, inv) => root.setBrightness(root.brightPct + root.controlScrollDelta(dy, inv))
                    }

                    Chip {
                        theme: root.theme
                        popupId: "vol"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "vol"
                        icon: root.muted ? "\uf026" : "\uf028"
                        iconColor: root.muted ? root.theme.red : root.theme.icon
                        label: Math.round(root.volume * 100) + "%"
                        reserveLabel: "100%"
                        slider: true
                        sliderValue: root.volume
                        sliderTitle: (root.muted ? "Volume (muted) " : "Volume ") + Math.round(root.volume * 100) + "%"
                        extra: appMixer
                        onSliderMoved: v => root.setVolume(v)
                        onClicked: root.toggleMute()
                        onEngagedChanged: root.volEngaged = engaged
                        onScrolled: (dy, inv) => root.setVolume(root.volume + root.controlScrollDelta(dy, inv))
                    }

                    Chip {
                        theme: root.theme
                        popupId: "net"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "net"
                        // ethernet / wifi / off - follows the internet status
                        icon: root.netType === "ethernet" ? "\uDB80\uDE00" : ((root.wifiOn || root.netType === "wifi") ? "\uf1eb" : "\uDB81\uDDAA")
                        iconColor: root.netType !== "none" ? root.theme.icon : root.theme.muted
                        tip: root.openPanel === "wifi" ? "" : (
                            root.netType === "ethernet" ? "Ethernet connected" + (root.wifiName ? "\nWi-Fi: " + root.wifiName : "")
                            : root.netType === "wifi" ? root.wifiName
                            : (root.wifiOn ? "Not connected" : "Internet off"))
                        onClicked: root.togglePanel("wifi")
                    }

                    Chip {
                        theme: root.theme
                        popupId: "bt"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "bt"
                        icon: "\uf293"
                        iconColor: root.btOn ? root.theme.icon : root.theme.muted
                        tip: root.openPanel === "bt" ? "" : (root.btOn ? "Bluetooth on" : "Bluetooth off")
                        onClicked: root.togglePanel("bt")
                    }

                    Chip {
                        theme: root.theme
                        popupId: "batt"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "batt"
                        visible: root.hasBatt
                        icon: root.battCharging ? "\uf0e7" : (root.battPct > 75 ? "\uf240" : root.battPct > 50 ? "\uf241" : root.battPct > 25 ? "\uf242" : root.battPct > 10 ? "\uf243" : "\uf244")
                        iconColor: (!root.battCharging && root.battPct <= 15) ? root.theme.red : root.theme.icon
                        label: Math.round(root.battPct) + "%"
                        tip: root.batTip
                    }

                    // Tray
                    Repeater {
                        model: SystemTray.items
                        delegate: MouseArea {
                            id: trayItem
                            required property var modelData
                            visible: !root.theme.trayHide.some(h => (String(modelData.id) + " " + String(modelData.title)).toLowerCase().indexOf(h) >= 0)
                            implicitWidth: 20; implicitHeight: 20
                            Component.onCompleted: console.log("tray item:", modelData.id, "|", modelData.title)
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate()
                                else if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                    console.log("tray menu:", modelData.id, "hasMenu =", modelData.hasMenu)
                                    if (trayMenu.visible) trayMenu.closeMenu(); else trayMenu.openMenu()
                                } else focusProc.running = true   // jump to the app's window if it has one
                            }
                            // Left click: focus the app's window (switches to its workspace). No window? Let the app open it.
                            Process {
                                id: focusProc
                                command: ["sh", "-c", "sh \"$HOME/.config/hypr/scripts/focus-app.sh\" \"$1\" \"$2\"", "_", String(trayItem.modelData.id), String(trayItem.modelData.title)]
                                onExited: code => { if (code !== 0) trayItem.modelData.activate() }
                            }
                            TrayMenu { id: trayMenu; theme: root.theme; sni: trayItem.modelData; target: trayItem }
                            IconImage { anchors.fill: parent; source: trayItem.modelData.icon }
                        }
                    }

                    // Power button at the far right edge: opens the power menu
                    Chip {
                        theme: root.theme
                        popupId: "power"; activePopup: root.activePopup; onPopupRequested: root.activePopup = "power"
                        icon: "\uf011"
                        tip: "Power menu"
                        onClicked: root.powerOpen = true
                    }
                }
            }

            NetPanel {
                screen: scope.modelData
                theme: root.theme
                wifiOn: root.wifiOn
                ethernet: root.ethUp
                visible: root.openPanel === "wifi"
                onCloseRequested: root.closePanel()
                onPowerChanged: on => root.wifiOn = on
            }

            ClockPanel {
                screen: scope.modelData
                theme: root.theme
                engine: clockEngine
                visible: root.openPanel === "clock"
                onCloseRequested: root.closePanel()
            }

            PowerMenu {
                screen: scope.modelData
                theme: root.theme
                visible: root.powerOpen
                onCloseRequested: root.powerOpen = false
            }

            BtPanel {
                screen: scope.modelData
                theme: root.theme
                btOn: root.btOn
                visible: root.openPanel === "bt"
                onCloseRequested: root.closePanel()
                onPowerChanged: on => root.btOn = on
            }
        }
    }
}
