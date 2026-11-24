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
    implicitHeight: Math.max(44, txt.implicitHeight + 10)
    // a hairline above every row except the first one of its card
    readonly property bool first: !parent || parent.children.length === 0 || parent.children[0] === r
    Rectangle { visible: !r.first; anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: -6 } height: 1; color: Qt.rgba(1, 1, 1, 0.06) }

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
