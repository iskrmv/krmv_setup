// PanelButton.qml - a small square text button
import QtQuick

Rectangle {
    id: b
    required property var theme
    property string text: ""
    property bool accent: false
    property bool active: true
    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 32
    color: (area.containsMouse && active) ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
    border.width: 1
    border.color: accent ? theme.icon : theme.muted
    opacity: active ? 1 : 0.4

    Text {
        id: label
        anchors.centerIn: parent
        text: b.text
        color: b.accent ? b.theme.icon : b.theme.fg
        font.family: b.theme.font
        font.pixelSize: b.theme.size - 1
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: if (b.active) b.clicked() }
}
