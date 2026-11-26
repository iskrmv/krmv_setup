// RollText.qml - text whose changes roll: the old value slides up and fades, the new one slides in from below.
import QtQuick

Item {
    id: rt
    property string value: ""
    property string family: "JetBrainsMono Nerd Font"
    property color color: "white"
    property int pixelSize: 100
    property int weight: Font.Light
    property string shown: value
    property real offset: 0
    property real fade: 1

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: rt.shown
        color: rt.color
        font.family: rt.family; font.pixelSize: rt.pixelSize; font.weight: rt.weight
        y: rt.offset
        opacity: rt.fade
    }
    onValueChanged: if (value !== shown) swap.restart()
    SequentialAnimation {
        id: swap
        ParallelAnimation {
            NumberAnimation { target: rt; property: "fade"; to: 0; duration: 140 }
            NumberAnimation { target: rt; property: "offset"; to: -rt.pixelSize * 0.14; duration: 140 }
        }
        ScriptAction { script: { rt.shown = rt.value; rt.offset = rt.pixelSize * 0.14 } }
        ParallelAnimation {
            NumberAnimation { target: rt; property: "fade"; to: 1; duration: 240 }
            NumberAnimation { target: rt; property: "offset"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }
    }
}
