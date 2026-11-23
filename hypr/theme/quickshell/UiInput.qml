// UiInput.qml - a one-line text field with a placeholder.
import QtQuick

Rectangle {
    id: f
    required property var theme
    property alias text: input.text
    property string placeholder: ""
    property int maxLength: 64
    signal accepted()

    implicitWidth: 200
    implicitHeight: 34
    color: Qt.rgba(0, 0, 0, 0.25)
    border.width: 1
    border.color: input.activeFocus ? theme.icon : Qt.rgba(1, 1, 1, 0.12)

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        color: f.theme.bright; clip: true; maximumLength: f.maxLength
        selectByMouse: true
        font.family: f.theme.font; font.pixelSize: f.theme.size - 1
        onAccepted: f.accepted()
        Text {
            visible: input.text === "" && !input.activeFocus
            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
            text: f.placeholder; color: f.theme.dim
            font.family: f.theme.font; font.pixelSize: f.theme.size - 2
        }
    }
}
