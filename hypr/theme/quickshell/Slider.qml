// Slider.qml - minimal square slider (0..1), no QtQuick.Controls needed
import QtQuick

Item {
    id: s
    required property var theme
    property real value: 0
    signal moved(real value)      // user dragged/clicked: new value 0..1
    signal wheeled(int dy, bool inverted)   // wheel over the slider (inverted = the device uses natural scrolling)
    readonly property bool pressed: area.pressed

    implicitWidth: 200
    implicitHeight: 20

    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; color: s.theme.muted }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, s.value)); height: 4; color: s.theme.icon }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 8; height: 16
        x: Math.max(0, Math.min(parent.width - width, parent.width * s.value - width / 2))
        color: s.theme.icon
    }

    MouseArea {
        id: area
        anchors.fill: parent
        function setFrom(x) { s.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: mouse => setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
        onWheel: wheel => s.wheeled(wheel.angleDelta.y, wheel.inverted)
    }
}
