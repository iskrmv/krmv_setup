// PowerButton.qml - an icon-only power button: hover grows it and shows its name, the first click arms it
// (amber, with a shrinking line), a second click within 2.6 seconds does it.
import QtQuick

Item {
    id: b
    property string kind: "power"
    property string label: ""
    property bool canDo: true
    property bool confirming: false
    property color tint: "white"
    property color confirmColor: "#e0af68"
    property real u: 1
    property string family: "JetBrainsMono Nerd Font"
    signal activated()

    width: 46 * u
    height: 46 * u
    opacity: canDo ? 1 : 0.28

    Icon {
        anchors.centerIn: parent
        width: 25 * b.u; height: 25 * b.u
        kind: b.kind
        color: b.confirming ? b.confirmColor : (area.containsMouse ? "white" : b.tint)
        scale: area.pressed ? 0.86 : (area.containsMouse ? 1.16 : 1)
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    // the line that runs out while the button waits for the second click
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 2 }
        height: 2; color: b.confirmColor
        visible: b.confirming
        NumberAnimation on width { running: b.confirming; from: 30 * b.u; to: 0; duration: 2600 }
    }
    // name, above the icon
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.top; bottomMargin: 8 * b.u }
        width: tip.implicitWidth + 22; height: tip.implicitHeight + 12
        color: Qt.rgba(0.06, 0.06, 0.1, 0.92)
        border.width: 1; border.color: b.confirming ? b.confirmColor : Qt.rgba(1, 1, 1, 0.18)
        opacity: (area.containsMouse || b.confirming) ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        Text {
            id: tip
            anchors.centerIn: parent
            text: b.confirming ? "Click again: " + b.label.toLowerCase() : b.label
            color: b.confirming ? b.confirmColor : "white"
            font.family: b.family; font.pixelSize: 13 * b.u
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (b.canDo) b.activated()
    }
}
