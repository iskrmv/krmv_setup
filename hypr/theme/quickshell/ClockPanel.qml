// ClockPanel.qml - the clock app: Timer, Alarm and Stopwatch. Opens under the bar's clock (click it, or SUPER + C).
// The panel has a FIXED size, so switching tabs never moves anything. Click outside or press Esc to close.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "ClockLogic.js" as L

PanelWindow {
    id: panel
    required property var theme
    required property var engine
    signal closeRequested()

    property int tab: 0                      // 0 timer, 1 alarm, 2 stopwatch
    property string message: ""              // a short hint or error under the inputs
    property var addDays: []                 // the days chosen for the new alarm (empty = once)

    anchors { top: true }                    // only the top edge: it is centered under the clock
    margins { top: 38 }
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    implicitWidth: 380
    implicitHeight: 440
    color: "transparent"

    Shortcut { sequence: "Escape"; onActivated: panel.closeRequested() }
    HyprlandFocusGrab { windows: [panel]; active: panel.visible; onCleared: panel.closeRequested() }
    onVisibleChanged: if (visible) message = ""

    function startCustom() {
        const sec = L.parseDuration(timerInput.text)
        if (sec <= 0) { message = "Type a time like 25, 1:30, 90s or 1h30m"; return }
        message = ""; timerInput.text = ""
        engine.startTimer(sec)
    }
    function addAlarm() {
        if (!engine.addAlarm(alarmTime.text, alarmLabel.text, addDays)) { message = "Type the time like 07:30"; return }
        message = ""; alarmTime.text = ""; alarmLabel.text = ""; addDays = []
    }
    function toggleDay(d) {
        const a = addDays.slice(); const i = a.indexOf(d)
        if (i >= 0) a.splice(i, 1); else a.push(d)
        addDays = a
    }

    Rectangle {
        anchors.fill: parent
        color: panel.theme.bg
        border.width: 1
        border.color: panel.theme.muted

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 14

            // ---- tabs ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 22
                Repeater {
                    model: ["Timer", "Alarm", "Stopwatch"]
                    delegate: Item {
                        id: tabItem
                        required property string modelData
                        required property int index
                        implicitWidth: tabText.implicitWidth
                        implicitHeight: 28
                        Text {
                            id: tabText
                            anchors.top: parent.top
                            text: tabItem.modelData
                            color: panel.tab === tabItem.index ? panel.theme.icon : panel.theme.dim
                            font.bold: panel.tab === tabItem.index
                            font.family: panel.theme.font; font.pixelSize: panel.theme.size + 1
                        }
                        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 2; color: panel.theme.icon; visible: panel.tab === tabItem.index }
                        MouseArea { anchors.fill: parent; onClicked: { panel.tab = tabItem.index; panel.message = "" } }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // ================= TIMER =================
            ColumnLayout {
                visible: panel.tab === 0
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 14

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: L.fmtDuration(panel.engine.timerState === "idle" ? 0 : panel.engine.timerLeft)
                    color: panel.engine.timerState === "running" ? panel.theme.icon : panel.theme.fg
                    font.bold: true
                    font.family: panel.theme.font; font.pixelSize: 64
                }
                Item {   // progress
                    Layout.fillWidth: true; Layout.preferredHeight: 6
                    Rectangle { anchors.fill: parent; color: panel.theme.muted }
                    Rectangle {
                        height: parent.height
                        width: panel.engine.timerState === "idle" || panel.engine.timerTotal <= 0 ? 0 : parent.width * Math.min(1, panel.engine.timerLeft / panel.engine.timerTotal)
                        color: panel.theme.icon
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: panel.engine.timerState === "running" ? "Running" : (panel.engine.timerState === "paused" ? "Paused" : "Pick a time to start")
                    color: panel.theme.dim
                    font.family: panel.theme.font; font.pixelSize: panel.theme.size
                }

                // idle: presets + custom time
                ColumnLayout {
                    visible: panel.engine.timerState === "idle"
                    Layout.fillWidth: true
                    spacing: 12
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [ { t: "1 min", s: 60 }, { t: "5 min", s: 300 }, { t: "10 min", s: 600 }, { t: "15 min", s: 900 }, { t: "30 min", s: 1800 }, { t: "1 hour", s: 3600 } ]
                            delegate: PanelButton { required property var modelData; theme: panel.theme; text: modelData.t; onClicked: panel.engine.startTimer(modelData.s) }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 32
                            color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
                            border.color: timerInput.activeFocus ? panel.theme.icon : panel.theme.muted
                            TextInput {
                                id: timerInput
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: panel.theme.fg; clip: true
                                font.family: panel.theme.font; font.pixelSize: panel.theme.size
                                onAccepted: panel.startCustom()
                                Text { visible: timerInput.text === ""; anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                       text: "Custom: 25, 1:30, 90s, 1h30m"; color: panel.theme.dim
                                       font.family: panel.theme.font; font.pixelSize: panel.theme.size - 1 }
                            }
                        }
                        PanelButton { theme: panel.theme; text: "Start"; accent: true; onClicked: panel.startCustom() }
                    }
                }
                // running / paused controls
                RowLayout {
                    visible: panel.engine.timerState !== "idle"
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    PanelButton {
                        theme: panel.theme; accent: true
                        text: panel.engine.timerState === "running" ? "Pause" : "Resume"
                        onClicked: panel.engine.timerState === "running" ? panel.engine.pauseTimer() : panel.engine.resumeTimer()
                    }
                    PanelButton { theme: panel.theme; text: "Reset"; onClicked: panel.engine.resetTimer() }
                }
                Item { Layout.fillHeight: true }
            }

            // ================= ALARM =================
            ColumnLayout {
                visible: panel.tab === 1
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 12

                Text {
                    text: L.nextAlarmText(panel.engine.alarms, new Date(panel.engine.nowMs)) || "No alarms yet"
                    color: panel.theme.dim
                    font.family: panel.theme.font; font.pixelSize: panel.theme.size
                }
                ListView {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 4
                    model: panel.engine.alarms
                    delegate: Rectangle {
                        id: aRow
                        required property var modelData
                        width: ListView.view.width; height: 50
                        color: "transparent"; border.width: 1; border.color: panel.theme.muted
                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                            spacing: 12
                            Text {
                                text: aRow.modelData.time
                                color: aRow.modelData.enabled ? panel.theme.fg : panel.theme.dim
                                font.bold: true
                                font.family: panel.theme.font; font.pixelSize: panel.theme.size + 6
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; visible: text !== ""
                                       text: aRow.modelData.label; color: panel.theme.fg
                                       font.family: panel.theme.font; font.pixelSize: panel.theme.size - 1 }
                                Text { text: L.daysText(aRow.modelData.days); color: panel.theme.dim
                                       font.family: panel.theme.font; font.pixelSize: panel.theme.size - 3 }
                            }
                            Toggle { theme: panel.theme; on: aRow.modelData.enabled; onToggled: panel.engine.setAlarmEnabled(aRow.modelData.id, !aRow.modelData.enabled) }
                            Text {
                                text: "\uf1f8"; color: trashArea.containsMouse ? panel.theme.red : panel.theme.dim
                                font.family: panel.theme.font; font.pixelSize: panel.theme.size + 1
                                MouseArea { id: trashArea; anchors { fill: parent; margins: -6 } hoverEnabled: true; onClicked: panel.engine.removeAlarm(aRow.modelData.id) }
                            }
                        }
                    }
                }

                // ---- new alarm ----
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.preferredWidth: 84; Layout.preferredHeight: 32
                        color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
                        border.color: alarmTime.activeFocus ? panel.theme.icon : panel.theme.muted
                        TextInput {
                            id: alarmTime
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: panel.theme.fg; clip: true; maximumLength: 5
                            font.family: panel.theme.font; font.pixelSize: panel.theme.size
                            onAccepted: panel.addAlarm()
                            Text { visible: alarmTime.text === ""; anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                   text: "07:30"; color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 32
                        color: Qt.rgba(1, 1, 1, 0.06); border.width: 1
                        border.color: alarmLabel.activeFocus ? panel.theme.icon : panel.theme.muted
                        TextInput {
                            id: alarmLabel
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: panel.theme.fg; clip: true
                            font.family: panel.theme.font; font.pixelSize: panel.theme.size
                            onAccepted: panel.addAlarm()
                            Text { visible: alarmLabel.text === ""; anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                   text: "Label (optional)"; color: panel.theme.dim; font.family: panel.theme.font; font.pixelSize: panel.theme.size - 1 }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        delegate: Rectangle {
                            id: dayBtn
                            required property string modelData
                            required property int index
                            readonly property bool on: panel.addDays.indexOf(index + 1) >= 0
                            Layout.preferredWidth: 32; Layout.preferredHeight: 28
                            color: on ? panel.theme.icon : "transparent"
                            border.width: 1; border.color: on ? panel.theme.icon : panel.theme.muted
                            Text { anchors.centerIn: parent; text: dayBtn.modelData; color: dayBtn.on ? panel.theme.bg : panel.theme.fg
                                   font.family: panel.theme.font; font.pixelSize: panel.theme.size - 2 }
                            MouseArea { anchors.fill: parent; onClicked: panel.toggleDay(dayBtn.index + 1) }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    PanelButton { theme: panel.theme; text: "Add alarm"; accent: true; onClicked: panel.addAlarm() }
                }
                Text {
                    visible: panel.addDays.length === 0
                    text: "No day chosen: the alarm rings once."
                    color: panel.theme.dim
                    font.family: panel.theme.font; font.pixelSize: panel.theme.size - 3
                }
            }

            // ================= STOPWATCH =================
            ColumnLayout {
                visible: panel.tab === 2
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 20
                Item { Layout.fillHeight: true }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: L.fmtStopwatch(panel.engine.swElapsed)
                    color: panel.engine.swRunning ? panel.theme.icon : panel.theme.fg
                    font.bold: true
                    font.family: panel.theme.font; font.pixelSize: 56
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    PanelButton { theme: panel.theme; accent: true; text: panel.engine.swRunning ? "Stop" : (panel.engine.swElapsed > 0 ? "Resume" : "Start"); onClicked: panel.engine.swToggle() }
                    PanelButton { theme: panel.theme; text: "Reset"; active: panel.engine.swElapsed > 0 && !panel.engine.swRunning; onClicked: panel.engine.swReset() }
                }
                Item { Layout.fillHeight: true }
            }

            // ---- hint / error line (the same place on every tab) ----
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                text: panel.message
                color: panel.theme.red
                elide: Text.ElideRight
                font.family: panel.theme.font; font.pixelSize: panel.theme.size - 2
            }
        }
    }
}
