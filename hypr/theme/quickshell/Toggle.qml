// Toggle.qml - on/off switch: a flat track with a square knob that slides.
import QtQuick

Rectangle {
    id: t
    required property var theme
    property bool on: false
    signal toggled()
    width: 44; height: 24
    color: on ? theme.icon : Qt.rgba(1, 1, 1, 0.14)
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
        width: 18; height: 18; y: 3
        x: t.on ? 23 : 3
        color: t.on ? t.theme.bg : "#d0d4e8"
        Behavior on x { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Rectangle { anchors.fill: parent; color: "#ffffff"; opacity: area.containsMouse ? 0.07 : 0 }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: t.toggled() }
}
