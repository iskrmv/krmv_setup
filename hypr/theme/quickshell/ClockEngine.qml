// ClockEngine.qml - the brain of the clock app: timer, stopwatch, alarms, calendar reminders, and the ringing.
// It keeps running when the panel is closed. Timer, alarms and reminders are remembered in ~/.local/state/krmv-setup.
import QtQuick
import Quickshell
import Quickshell.Io
import "ClockLogic.js" as L

Scope {
    id: eng
    property bool panelOpen: false                        // the panel asks for faster updates while it is visible
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/krmv-setup"
    property real nowMs: Date.now()

    // ---- timer ----
    property int timerTotal: 0                            // seconds of the current (or last) timer
    property real timerEndsAt: 0                          // ms since 1970 while running
    property real timerPausedLeft: 0                      // seconds left while paused
    property string timerState: "idle"                    // idle | running | paused
    readonly property real timerLeft: timerState === "running" ? Math.max(0, (timerEndsAt - nowMs) / 1000)
                                      : (timerState === "paused" ? timerPausedLeft : timerTotal)

    // ---- stopwatch ----
    property bool swRunning: false
    property real swStartedAt: 0
    property real swBase: 0                               // ms collected before the last start
    readonly property real swElapsed: swRunning ? swBase + (nowMs - swStartedAt) : swBase

    // ---- alarms: [{ id, time: "07:30", label, days: [1..7] (empty = once), enabled }] ----
    property var alarms: []
    property var lastFired: ({})
    property real snoozeAt: 0

    // ---- calendar reminders: [{ id, date: "2026-11-20", time: "14:30", text, done }] ----
    // At the chosen minute a notification pops up (the bar is the notification daemon). A reminder that came due
    // while the bar was not running fires at the next start. Fired reminders are removed after 14 days.
    property var reminders: []
    function noteKey(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0")
    }
    function remindersOn(key) {
        return reminders.filter(r => r.date === key).sort((x, y) => x.time < y.time ? -1 : 1)
    }
    function hasReminder(key) { return reminders.some(r => r.date === key) }
    function validTime(t) { return /^([01]\d|2[0-3]):[0-5]\d$/.test(t) }
    function addReminder(key, time, text) {
        const v = String(text || "").trim()
        if (v === "" || !validTime(time)) return false
        reminders = reminders.concat([{ id: Date.now() + Math.floor(Math.random() * 1000), date: key, time: time, text: v, done: false }])
        saveReminders()
        checkReminders()
        return true
    }
    function removeReminder(id) {
        reminders = reminders.filter(r => r.id !== id)
        saveReminders()
    }
    function checkReminders() {
        const now = new Date()
        const nowStr = noteKey(now) + " " + String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0")
        let changed = false
        const keep = []
        for (const r of reminders) {
            if (!r.done && (r.date + " " + r.time) <= nowStr) {
                remindProc.command = ["notify-send", "-u", "critical", "-i", "appointment-soon", "Reminder  " + r.time, r.text]
                remindProc.running = true
                r.done = true; changed = true
            }
            // forget fired reminders after 14 days
            if (r.done && (now.getTime() - new Date(r.date + "T" + r.time + ":00").getTime()) > 14 * 86400000) { changed = true; continue }
            keep.push(r)
        }
        if (changed) { reminders = keep; saveReminders() }
    }
    Process { id: remindProc }
    Timer { interval: 20000; running: eng.reminders.length > 0; repeat: true; onTriggered: eng.checkReminders() }

    // ---- ringing ----
    property bool ringing: false
    property string ringKind: ""                          // timer | alarm
    property string ringTitle: ""
    property string ringSub: ""

    readonly property bool hasWork: timerState === "running" || swRunning || snoozeAt > 0 || ringing || panelOpen
                                    || alarms.some(a => a.enabled)

    // One tick per second is all alarms need; faster only while you are looking at the panel
    Timer {
        interval: eng.panelOpen ? (eng.swRunning ? 100 : 250) : 1000
        running: eng.hasWork
        repeat: true
        triggeredOnStart: true
        onTriggered: { eng.nowMs = Date.now(); eng.check() }
    }

    function check() {
        const now = new Date(nowMs)
        if (timerState === "running" && nowMs >= timerEndsAt) {
            const total = timerTotal
            timerState = "idle"; timerEndsAt = 0; saveTimer()
            ring("timer", "Timer finished", L.fmtDuration(total))
        }
        if (snoozeAt > 0 && nowMs >= snoozeAt) {
            snoozeAt = 0
            ring("alarm", ringTitle !== "" ? ringTitle : "Alarm", "Snoozed alarm")
        }
        let changed = false
        const list = alarms.slice()
        for (let i = 0; i < list.length; i++) {
            const a = list[i]
            if (L.alarmDue(a, now, lastFired[a.id])) {
                lastFired[a.id] = L.alarmKey(now)
                if (!a.days || a.days.length === 0) { list[i] = Object.assign({}, a, { enabled: false }); changed = true }   // "once" alarms switch off
                ring("alarm", a.label !== "" ? a.label : "Alarm", a.time)
            }
        }
        if (changed) { alarms = list; saveAlarms() }
    }

    // ---- ringing: a notification, a looping sound and the ring window ----
    function ring(kind, title, sub) {
        ringKind = kind; ringTitle = title; ringSub = sub; ringing = true
        Quickshell.execDetached(["notify-send", "-u", "critical", "-i", "alarm-clock", title, sub])
    }
    function dismiss() { ringing = false }
    function snooze() { snoozeAt = Date.now() + 5 * 60 * 1000; ringing = false }
    Timer { interval: 60000; running: eng.ringing; onTriggered: eng.dismiss() }          // stops by itself after a minute
    Process {
        id: sound
        command: ["sh", "-c", "f=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; command -v pw-play >/dev/null 2>&1 && exec pw-play \"$f\"; exec paplay \"$f\""]
    }
    Timer { interval: 3000; running: eng.ringing; repeat: true; triggeredOnStart: true; onTriggered: if (!sound.running) sound.running = true }
    onRingingChanged: if (!ringing) sound.running = false

    // ---- timer controls ----
    function startTimer(sec) {
        if (sec <= 0) return
        timerTotal = sec; nowMs = Date.now(); timerEndsAt = nowMs + sec * 1000; timerState = "running"; saveTimer()
    }
    function pauseTimer() {
        if (timerState !== "running") return
        timerPausedLeft = Math.max(0, (timerEndsAt - Date.now()) / 1000); timerState = "paused"; saveTimer()
    }
    function resumeTimer() {
        if (timerState !== "paused") return
        nowMs = Date.now(); timerEndsAt = nowMs + timerPausedLeft * 1000; timerState = "running"; saveTimer()
    }
    function resetTimer() { timerState = "idle"; timerEndsAt = 0; saveTimer() }

    // ---- stopwatch controls ----
    function swToggle() {
        if (swRunning) { swBase = swElapsed; swRunning = false }
        else { nowMs = Date.now(); swStartedAt = nowMs; swRunning = true }
    }
    function swReset() { swRunning = false; swBase = 0 }

    // ---- alarm controls ----
    function addAlarm(time, label, days) {
        const t = L.normTime(time)
        if (t === "") return false
        const list = alarms.slice()
        list.push({ id: Date.now(), time: t, label: label || "", days: days.slice().sort(), enabled: true })
        list.sort((a, b) => a.time.localeCompare(b.time))
        alarms = list; saveAlarms()
        return true
    }
    function removeAlarm(id) { alarms = alarms.filter(a => a.id !== id); saveAlarms() }
    function setAlarmEnabled(id, on) { alarms = alarms.map(a => a.id === id ? Object.assign({}, a, { enabled: on }) : a); saveAlarms() }

    // ---- remembered between restarts ----
    Process { id: alarmsSave }
    Process { id: timerSave }
    Process { id: remindersSave }
    function saveReminders() {
        remindersSave.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/reminders.json\"", "_", stateDir, JSON.stringify(reminders)]
        remindersSave.running = true
    }
    function saveAlarms() {
        alarmsSave.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/alarms.json\"", "_", stateDir, JSON.stringify(alarms)]
        alarmsSave.running = true
    }
    function saveTimer() {
        timerSave.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/timer.json\"", "_", stateDir,
                             JSON.stringify({ state: timerState, endsAt: timerEndsAt, total: timerTotal, pausedLeft: timerPausedLeft })]
        timerSave.running = true
    }
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", eng.stateDir + "/alarms.json"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { const a = JSON.parse(text); if (Array.isArray(a)) eng.alarms = a } catch (e) {} } }
    }
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", eng.stateDir + "/timer.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const t = JSON.parse(text)
                    eng.timerTotal = t.total || 0
                    if (t.state === "paused") { eng.timerPausedLeft = t.pausedLeft; eng.timerState = "paused" }
                    else if (t.state === "running" && t.endsAt > Date.now()) { eng.timerEndsAt = t.endsAt; eng.timerState = "running" }
                } catch (e) {}
            }
        }
    }
    Process {
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null", "_", eng.stateDir + "/reminders.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const n = JSON.parse(text)
                    if (Array.isArray(n)) { eng.reminders = n; eng.checkReminders() }
                } catch (e) {}
            }
        }
    }
}
