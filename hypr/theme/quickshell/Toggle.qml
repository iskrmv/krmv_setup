// Toggle.qml - simple on/off switch
import QtQuick

Rectangle {
    id: t
    required property var theme
    property bool on: false
    signal toggled()
    width: 42; height: 22; radius: 0
    color: on ? theme.icon : theme.muted
    Rectangle {
        width: 16; height: 16; radius: 0; y: 3
        x: t.on ? 23 : 3
        color: t.theme.bg
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea { anchors.fill: parent; onClicked: t.toggled() }
}
