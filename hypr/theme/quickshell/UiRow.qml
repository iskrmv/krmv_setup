// UiRow.qml - one setting: a title (and a short explanation) on the left, the control on the right.
import QtQuick
import QtQuick.Layouts

Item {
    id: r
    required property var theme
    property string title: ""
    property string subtitle: ""
    default property alias control: slot.data

    Layout.fillWidth: true
    implicitHeight: Math.max(38, txt.implicitHeight + 4)

    Column {
        id: txt
        anchors { left: parent.left; right: slot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
        spacing: 2
        Text {
            width: parent.width
            text: r.title; color: r.theme.bright; elide: Text.ElideRight
            font.family: r.theme.font; font.pixelSize: r.theme.size
        }
        Text {
            visible: r.subtitle !== ""
            width: parent.width
            text: r.subtitle; color: r.theme.dim; wrapMode: Text.Wrap
            font.family: r.theme.font; font.pixelSize: r.theme.size - 3
        }
    }
    Row {
        id: slot
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8
    }
}
