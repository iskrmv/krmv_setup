// UiButton.qml - the one button style of the apps (Settings, Clock). kind: primary | secondary | danger | ghost
import QtQuick

Rectangle {
    id: b
    required property var theme
    property string text: ""
    property string icon: ""
    property string kind: "secondary"
    property bool active: true
    signal clicked()

    implicitWidth: row.implicitWidth + 28
    implicitHeight: 34
    readonly property bool hot: area.containsMouse && active
    color: kind === "primary" ? (hot ? Qt.lighter(theme.icon, 1.12) : theme.icon)
         : kind === "ghost" ? (hot ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
         : (hot ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04))
    border.width: (kind === "primary" || kind === "ghost") ? 0 : 1
    border.color: kind === "danger" ? theme.red : Qt.rgba(1, 1, 1, 0.14)
    opacity: active ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: 90 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: b.icon !== ""
            text: b.icon
            color: b.kind === "primary" ? b.theme.bg : (b.kind === "danger" ? b.theme.red : b.theme.icon)
            font.family: b.theme.font; font.pixelSize: b.theme.size
        }
        Text {
            visible: b.text !== ""
            text: b.text
            color: b.kind === "primary" ? b.theme.bg : (b.kind === "danger" ? b.theme.red : b.theme.bright)
            font.family: b.theme.font; font.pixelSize: b.theme.size - 1
            font.bold: b.kind === "primary"
        }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.active) b.clicked() }
}
