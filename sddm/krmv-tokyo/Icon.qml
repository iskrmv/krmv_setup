// Icon.qml - small line icons drawn with Canvas, so the login screen never depends on an icon font being installed.
// kind: power | reboot | sleep | arrow | eye | eyeoff | caps | keyboard | session | chevron | check
import QtQuick

Item {
    id: ic
    property string kind: "power"
    property color color: "white"
    property real strokeWidth: Math.max(1.6, width / 11)
    implicitWidth: 24
    implicitHeight: 24

    Canvas {
        id: cv
        anchors.fill: parent
        antialiasing: true
        renderTarget: Canvas.Image             // painted at once, never a stale picture stretched to a new size
        renderStrategy: Canvas.Immediate
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: ic
            function onColorChanged() { cv.requestPaint() }
            function onKindChanged() { cv.requestPaint() }
        }
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height, c = w / 2, r = w * 0.34
            ctx.strokeStyle = ic.color
            ctx.fillStyle = ic.color
            ctx.lineWidth = ic.strokeWidth
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            const k = ic.kind
            if (k === "power") {
                ctx.beginPath(); ctx.arc(c, c + h * 0.04, r, -Math.PI / 2 + 0.62, Math.PI * 1.5 - 0.62); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(c, h * 0.12); ctx.lineTo(c, c * 0.98); ctx.stroke()
            } else if (k === "reboot") {
                const a0 = -Math.PI * 0.32, a1 = a0 + Math.PI * 1.7
                ctx.beginPath(); ctx.arc(c, c, r, a0, a1); ctx.stroke()
                const ex = c + r * Math.cos(a1), ey = c + r * Math.sin(a1)
                const tx = -Math.sin(a1), ty = Math.cos(a1)               // direction of travel at the end of the arc
                const nx = Math.cos(a1), ny = Math.sin(a1)                // pointing out of the circle
                const s = w * 0.17
                ctx.beginPath()
                ctx.moveTo(ex + tx * s * 0.2 + nx * s, ey + ty * s * 0.2 + ny * s)
                ctx.lineTo(ex + tx * s * 1.1, ey + ty * s * 1.1)
                ctx.lineTo(ex + tx * s * 0.2 - nx * s, ey + ty * s * 0.2 - ny * s)
                ctx.stroke()
            } else if (k === "sleep") {
                ctx.beginPath(); ctx.arc(c, c, r * 1.08, 0, Math.PI * 2); ctx.fill()
                ctx.globalCompositeOperation = "destination-out"
                ctx.beginPath(); ctx.arc(c + r * 0.62, c - r * 0.5, r * 0.95, 0, Math.PI * 2); ctx.fill()
                ctx.globalCompositeOperation = "source-over"
            } else if (k === "arrow") {
                ctx.beginPath(); ctx.moveTo(w * 0.2, c); ctx.lineTo(w * 0.8, c); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(w * 0.58, h * 0.3); ctx.lineTo(w * 0.8, c); ctx.lineTo(w * 0.58, h * 0.7); ctx.stroke()
            } else if (k === "eye" || k === "eyeoff") {
                ctx.beginPath()
                ctx.moveTo(w * 0.08, c)
                ctx.quadraticCurveTo(c, h * 0.06, w * 0.92, c)
                ctx.quadraticCurveTo(c, h * 0.94, w * 0.08, c)
                ctx.stroke()
                ctx.beginPath(); ctx.arc(c, c, r * 0.4, 0, Math.PI * 2); ctx.stroke()
                if (k === "eyeoff") { ctx.beginPath(); ctx.moveTo(w * 0.18, h * 0.84); ctx.lineTo(w * 0.82, h * 0.16); ctx.stroke() }
            } else if (k === "caps") {
                ctx.beginPath()
                ctx.moveTo(c, h * 0.12); ctx.lineTo(w * 0.86, h * 0.5); ctx.lineTo(w * 0.64, h * 0.5); ctx.lineTo(w * 0.64, h * 0.7)
                ctx.lineTo(w * 0.36, h * 0.7); ctx.lineTo(w * 0.36, h * 0.5); ctx.lineTo(w * 0.14, h * 0.5); ctx.closePath()
                ctx.stroke()
                ctx.beginPath(); ctx.moveTo(w * 0.36, h * 0.88); ctx.lineTo(w * 0.64, h * 0.88); ctx.stroke()
            } else if (k === "keyboard") {
                ctx.strokeRect(w * 0.08, h * 0.24, w * 0.84, h * 0.52)
                for (let i = 0; i < 4; i++) ctx.fillRect(w * (0.2 + i * 0.17), h * 0.36, w * 0.09, h * 0.08)
                ctx.fillRect(w * 0.28, h * 0.56, w * 0.44, h * 0.08)
            } else if (k === "session") {
                ctx.strokeRect(w * 0.1, h * 0.16, w * 0.8, h * 0.52)
                ctx.beginPath(); ctx.moveTo(c, h * 0.68); ctx.lineTo(c, h * 0.84); ctx.moveTo(w * 0.32, h * 0.86); ctx.lineTo(w * 0.68, h * 0.86); ctx.stroke()
            } else if (k === "chevron") {
                ctx.beginPath(); ctx.moveTo(w * 0.22, h * 0.38); ctx.lineTo(c, h * 0.64); ctx.lineTo(w * 0.78, h * 0.38); ctx.stroke()
            } else if (k === "check") {
                ctx.beginPath(); ctx.moveTo(w * 0.2, h * 0.52); ctx.lineTo(w * 0.42, h * 0.74); ctx.lineTo(w * 0.82, h * 0.28); ctx.stroke()
            }
        }
    }
}
