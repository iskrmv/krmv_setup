// ClockLogic.js - the pure functions of the clock app (timer, alarm, stopwatch). No UI in here, so they are easy to test.
.pragma library

// "25" -> 25 minutes, "1:30" -> 1 min 30 s, "0:45:00" -> 45 min, "90s" / "5m" / "1h30m" also work. Returns seconds, or -1 if invalid.
function parseDuration(text) {
    const t = String(text || "").trim().toLowerCase()
    if (t === "") return -1
    let m = t.match(/^(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?$/)
    if (m && (m[1] || m[2] || m[3])) return (+m[1] || 0) * 3600 + (+m[2] || 0) * 60 + (+m[3] || 0)
    if (/^\d+$/.test(t)) return parseInt(t, 10) * 60                       // a plain number = minutes
    m = t.match(/^(\d+):(\d{1,2})$/)
    if (m) return parseInt(m[1], 10) * 60 + parseInt(m[2], 10)             // mm:ss
    m = t.match(/^(\d+):(\d{1,2}):(\d{1,2})$/)
    if (m) return parseInt(m[1], 10) * 3600 + parseInt(m[2], 10) * 60 + parseInt(m[3], 10)   // h:mm:ss
    return -1
}

function pad(n) { return (n < 10 ? "0" : "") + n }

// 65 -> "01:05", 3725 -> "1:02:05"
function fmtDuration(sec) {
    sec = Math.max(0, Math.ceil(sec))
    const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
    return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s)
}

// stopwatch: milliseconds -> "01:05.3"
function fmtStopwatch(ms) {
    ms = Math.max(0, Math.floor(ms))
    const total = Math.floor(ms / 1000), tenth = Math.floor((ms % 1000) / 100)
    const h = Math.floor(total / 3600), m = Math.floor((total % 3600) / 60), s = total % 60
    return (h > 0 ? h + ":" + pad(m) : pad(m)) + ":" + pad(s) + "." + tenth
}

// "7:5" -> "07:05", "0730" -> "07:30", "25:00" -> "" (invalid)
function normTime(text) {
    const t = String(text || "").trim()
    let m = t.match(/^(\d{1,2})[:.](\d{1,2})$/)
    if (!m) m = t.match(/^(\d{2})(\d{2})$/)
    if (!m) return ""
    const h = parseInt(m[1], 10), mi = parseInt(m[2], 10)
    if (h > 23 || mi > 59) return ""
    return pad(h) + ":" + pad(mi)
}

// days: array of 1..7 (Monday = 1 ... Sunday = 7), empty = once
function dayName(d) { return ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][d] }
function daysText(days) {
    if (!days || days.length === 0) return "Once"
    if (days.length === 7) return "Every day"
    if (days.length === 5 && [1, 2, 3, 4, 5].every(d => days.indexOf(d) >= 0)) return "Weekdays"
    return days.slice().sort((a, b) => a - b).map(dayName).join(" ")
}

// Should this alarm ring at `date`? lastKey is the "date + time" it last rang at (so it rings once per minute).
function alarmDue(alarm, date, lastKey) {
    if (!alarm.enabled) return false
    const hhmm = pad(date.getHours()) + ":" + pad(date.getMinutes())
    if (alarm.time !== hhmm) return false
    const wd = date.getDay() === 0 ? 7 : date.getDay()
    if (alarm.days && alarm.days.length > 0 && alarm.days.indexOf(wd) < 0) return false
    const key = date.getFullYear() + "-" + date.getMonth() + "-" + date.getDate() + " " + hhmm
    return lastKey !== key
}
function alarmKey(date) {
    return date.getFullYear() + "-" + date.getMonth() + "-" + date.getDate() + " " + pad(date.getHours()) + ":" + pad(date.getMinutes())
}

// "in 7 h 30 min" for the next enabled alarm
function nextAlarmText(alarms, now) {
    let best = -1
    for (const a of alarms) {
        if (!a.enabled) continue
        for (let add = 0; add < 8; add++) {
            const d = new Date(now.getTime() + add * 86400000)
            const wd = d.getDay() === 0 ? 7 : d.getDay()
            if (a.days && a.days.length > 0 && a.days.indexOf(wd) < 0) continue
            const parts = a.time.split(":")
            const t = new Date(d.getFullYear(), d.getMonth(), d.getDate(), +parts[0], +parts[1], 0).getTime()
            if (t > now.getTime() && (best < 0 || t < best)) { best = t; break }
        }
    }
    if (best < 0) return ""
    const mins = Math.round((best - now.getTime()) / 60000)
    const h = Math.floor(mins / 60), m = mins % 60
    return "Next alarm in " + (h > 0 ? h + " h " : "") + m + " min"
}
