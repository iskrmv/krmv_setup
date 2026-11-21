// WidgetMover.qml - the desktop widget editor. The screen dims; you can
//   - drag the clock, the network speed card and the media card (each one on its own) where you want them,
//   - switch widgets on and off in the list at the top (Clock, Network speed, Media output).
// The list comes from shell.qml, so a widget only needs an entry in widgetList to appear here.
// Enter saves, R puts every widget back to its default place, Esc cancels.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: mover
    required property var theme
    property real startX: 0
    property real startY: 0
    property real faceW: 600
    property real faceH: 200
    property real netStartX: 80
    property real netStartY: 300
    property real mediaStartX: 80
    property real mediaStartY: 500
    property var widgets: []                 // [{ id: "clock", name: "Clock", enabled: true }]
    signal done(var positions)             // { clock: [x, y], net: [x, y], media: [x, y] }
    signal resetRequested()
    signal cancelled()
    signal widgetToggled(string id, bool enabled)

    function isOn(id, fallback) { for (const w of widgets) if (w.id === id) return w.enabled; return fallback }
    readonly property bool clockOn: isOn("clock", true)
    readonly property bool netOn: isOn("netspeed", false)
    readonly property bool mediaOn: isOn("mediaout", false)
    function collect() {
        return { clock: [gClock.x, gClock.y], net: [gNet.x, gNet.y], media: [gMedia.x, gMedia.y],
                 clockOn: clockOn, netOn: netOn, mediaOn: mediaOn }
    }

    screen: Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    color: "transparent"

    Shortcut { sequence: "Escape"; onActivated: mover.cancelled() }
    Shortcut { sequence: "Return"; onActivated: mover.done(mover.collect()) }
    Shortcut { sequence: "Enter"; onActivated: mover.done(mover.collect()) }
    Shortcut { sequence: "R"; onActivated: mover.resetRequested() }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.102, 0.106, 0.149, 0.6)

        // the widget list
        Rectangle {
            id: listBox
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 50 }
            width: 340
            height: listCol.implicitHeight + 28
            color: mover.theme.bg
            border.width: 1
            border.color: mover.theme.muted

            Column {
                id: listCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 12
                Text {
                    text: "Desktop widgets"
                    color: mover.theme.icon; font.bold: true
                    font.family: mover.theme.font; font.pixelSize: mover.theme.size + 1
                }
                Repeater {
                    model: mover.widgets
                    delegate: RowLayout {
                        id: wRow
                        required property var modelData
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            text: wRow.modelData.name
                            color: mover.theme.fg
                            font.family: mover.theme.font; font.pixelSize: mover.theme.size
                        }
                        Toggle {
                            theme: mover.theme
                            on: wRow.modelData.enabled
                            onToggled: mover.widgetToggled(wRow.modelData.id, !wRow.modelData.enabled)
                        }
                    }
                }
                Text {
                    text: "Toggles save immediately. Drag the widgets, then press Enter to keep their places."
                    color: mover.theme.dim
                    font.family: mover.theme.font; font.pixelSize: mover.theme.size - 3
                }
            }
        }

        // the widgets (only while they are switched on); every one is dragged on its own
        DragGhost {
            id: gMedia
            theme: mover.theme
            visible: mover.mediaOn
            x: mover.mediaStartX; y: mover.mediaStartY
            width: mediaPreview.implicitWidth; height: mediaPreview.implicitHeight
            MediaOutputWidget { id: mediaPreview; theme: mover.theme }
        }
        DragGhost {
            id: gNet
            theme: mover.theme
            visible: mover.netOn
            x: mover.netStartX; y: mover.netStartY
            width: netPreview.implicitWidth; height: netPreview.implicitHeight
            NetSpeedWidget { id: netPreview; theme: mover.theme; iface: "wlan0"; downText: "1.2 MB/s"; upText: "340 KB/s"; receivedText: "2.1 GB"; sentText: "340 MB" }
        }
        DragGhost {
            id: gClock
            theme: mover.theme
            visible: mover.clockOn
            x: mover.startX; y: mover.startY
            width: mover.faceW; height: mover.faceH
            ClockFace { anchors.fill: parent }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 60 }
            text: "Drag each widget    Enter: save    R: default places    Esc: cancel"
            color: mover.theme.fg
            font.family: mover.theme.font; font.pixelSize: mover.theme.size + 2
        }
    }
}
