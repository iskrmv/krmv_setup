// DesktopClock.qml - the desktop clock window: above the wallpaper, below your windows.
// Move it: double-click it (or press SUPER + SHIFT + W), drag it where you want it, press Enter. The place is remembered.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: widget
    property int posX: -1                    // -1 = default place (left side, vertically centered)
    property int posY: -1
    // options (Settings > Widgets > Clock widget)
    property bool showDay: true
    property bool showDate: true
    property bool use24Hour: false
    property bool withDecor: true
    property real sizeScale: 1.0
    readonly property int defaultX: 80
    readonly property int curX: posX >= 0 ? posX : defaultX
    readonly property int curY: posY >= 0 ? posY : Math.max(0, Math.round((screen.height - height) / 2))
    signal moveRequested()

    screen: Quickshell.screens[0]
    anchors { left: true; top: true }
    margins { left: curX; top: curY }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: face.implicitWidth
    implicitHeight: face.implicitHeight
    color: "transparent"

    ClockFace {
        id: face; anchors.fill: parent
        showDay: widget.showDay; showDate: widget.showDate; use24Hour: widget.use24Hour
        timeDecor: widget.withDecor ? "-" : ""; sizeScale: widget.sizeScale
    }
    MouseArea { anchors.fill: parent; onDoubleClicked: widget.moveRequested() }
}
