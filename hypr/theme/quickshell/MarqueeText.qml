// MarqueeText.qml - a one-line text that stops growing at `maxWidth`. When the text is longer than the space,
// it waits a moment, slowly scrolls to the left so you can read the rest, waits, and starts again.
import QtQuick

Item {
    id: m
    property string text: ""
    property color color: "#ffffff"
    property int pixelSize: 14
    property bool bold: false
    property string fontFamily: ""
    property real maxWidth: 300

    clip: true
    implicitWidth: Math.min(label.implicitWidth, maxWidth)
    implicitHeight: label.implicitHeight
    width: implicitWidth
    height: implicitHeight

    readonly property real overflow: Math.max(0, label.implicitWidth - width)
    onOverflowChanged: if (overflow === 0) label.x = 0
    onTextChanged: label.x = 0

    Text {
        id: label
        text: m.text
        color: m.color
        font.pixelSize: m.pixelSize
        font.bold: m.bold
        font.family: m.fontFamily
    }

    SequentialAnimation {
        running: m.overflow > 0 && m.visible
        loops: Animation.Infinite
        PauseAnimation { duration: 2500 }                                    // read the beginning first
        NumberAnimation {                                                    // slowly roll to the left
            target: label; property: "x"
            to: -(m.overflow + 8)
            duration: Math.max(900, m.overflow * 30)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1800 }                                    // read the end
        NumberAnimation { target: label; property: "opacity"; to: 0; duration: 180 }
        PropertyAction { target: label; property: "x"; value: 0 }
        NumberAnimation { target: label; property: "opacity"; to: 1; duration: 180 }
    }
}
