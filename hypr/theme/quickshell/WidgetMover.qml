// WidgetMover.qml - the desktop widget editor. The screen dims; you can
//   - drag a widget where you want it,
//   - switch widgets on and off in the list at the top (more widgets will appear in this list later),
// Enter saves, R puts the clock back to its default place, Delete hides the clock, Esc cancels.
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
    property var widgets: []                 // [{ id: "clock", name: "Clock", enabled: true }]
    signal done(real x, real y)
    signal resetRequested()
    signal cancelled()
    signal widgetToggled(string id, bool enabled)

    readonly property bool clockOn: { for (const w of widgets) if (w.id === "clock") return w.enabled; return true }

    screen: Quickshell.screens[0]
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: true
    color: "transparent"

    Shortcut { sequence: "Escape"; onActivated: mover.cancelled() }
    Shortcut { sequence: "Return"; onActivated: mover.done(ghost.x, ghost.y) }
    Shortcut { sequence: "Enter"; onActivated: mover.done(ghost.x, ghost.y) }
    Shortcut { sequence: "R"; onActivated: mover.resetRequested() }
    Shortcut { sequence: "Delete"; onActivated: mover.widgetToggled("clock", false) }

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
                    text: "More widgets will show up here."
                    color: mover.theme.dim
                    font.family: mover.theme.font; font.pixelSize: mover.theme.size - 3
                }
            }
        }

        // the clock (only while it is switched on)
        Item {
            id: ghost
            visible: mover.clockOn
            x: mover.startX; y: mover.startY
            width: mover.faceW; height: mover.faceH

            ClockFace { anchors.fill: parent }
            Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: mover.theme.icon }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                drag.target: ghost
                drag.minimumX: 0; drag.maximumX: Math.max(0, mover.width - ghost.width)
                drag.minimumY: 0; drag.maximumY: Math.max(0, mover.height - ghost.height)
            }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 60 }
            text: "Drag the clock    Enter: save    R: default place    Delete: hide the clock    Esc: cancel"
            color: mover.theme.fg
            font.family: mover.theme.font; font.pixelSize: mover.theme.size + 2
        }
    }
}
