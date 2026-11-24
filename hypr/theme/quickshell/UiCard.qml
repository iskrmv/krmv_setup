// UiCard.qml - a section of a page: optional title + subtitle, then whatever you put inside.
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: c
    required property var theme
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 36
    color: Qt.rgba(1, 1, 1, 0.035)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.07)

    Rectangle { width: 28; height: 2; color: c.theme.icon }      // small accent mark on the top edge

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 12
        ColumnLayout {
            visible: c.title !== ""
            spacing: 3
            RowLayout {
                spacing: 10
                Text {
                    visible: c.icon !== ""
                    text: c.icon; color: c.theme.icon
                    font.family: c.theme.font; font.pixelSize: c.theme.size + 3
                }
                Text {
                    text: c.title; color: c.theme.bright; font.bold: true
                    font.family: c.theme.font; font.pixelSize: c.theme.size + 2
                }
            }
            Text {
                visible: c.subtitle !== ""
                Layout.fillWidth: true
                text: c.subtitle; color: c.theme.dim; wrapMode: Text.Wrap
                font.family: c.theme.font; font.pixelSize: c.theme.size - 2
            }
        }
        ColumnLayout { id: body; Layout.fillWidth: true; spacing: 12 }
    }
}
