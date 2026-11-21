// DesktopWidgetWindow.qml - a window for one desktop widget: above the wallpaper, below your windows.
// Put the widget inside it:   DesktopWidgetWindow { posX: 100; posY: 200; NetSpeedWidget { } }
// Double-click it to open the widget editor, where every widget can be dragged to its place.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win
    property int posX: 80
    property int posY: 80
    default property alias content: holder.data
    signal moveRequested()

    screen: Quickshell.screens[0]
    anchors { left: true; top: true }
    margins { left: win.posX; top: win.posY }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: Math.max(1, holder.childrenRect.width)
    implicitHeight: Math.max(1, holder.childrenRect.height)
    color: "transparent"

    Item { id: holder; anchors.fill: parent }
    MouseArea { anchors.fill: parent; onDoubleClicked: win.moveRequested() }
}
