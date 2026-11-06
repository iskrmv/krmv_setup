// RamIcon.qml - a RAM stick drawn with shapes (font independent, same color as the other icons)
import QtQuick

Item {
    id: ram
    property color color: "#a9b1d6"
    implicitWidth: 20
    implicitHeight: 20

    // board
    Rectangle { x: 0; y: 4; width: 20; height: 8; color: "transparent"; border.color: ram.color; border.width: 1 }
    // memory chips
    Repeater {
        model: 3
        Rectangle { required property int index; x: 3 + index * 6; y: 6; width: 4; height: 4; color: ram.color }
    }
    // gold contacts
    Repeater {
        model: 5
        Rectangle { required property int index; x: 2 + index * 4; y: 13; width: 2; height: 3; color: ram.color }
    }
}
