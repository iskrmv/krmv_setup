// UiSegment.qml - pick one of a few options (a segmented control).
// options: [ { label: "100%", value: 1 }, ... ]     current: the value that is selected     picked(value) when you click
import QtQuick

Rectangle {
    id: s
    required property var theme
    property var options: []
    property var current: ""
    signal picked(var value)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 34
    color: Qt.rgba(0, 0, 0, 0.25)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: s.options
            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool sel: String(modelData.value) === String(s.current)
                width: lbl.implicitWidth + 22; height: 28
                color: sel ? s.theme.icon : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                Behavior on color { ColorAnimation { duration: 90 } }
                Text {
                    id: lbl
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.sel ? s.theme.bg : s.theme.fg; font.bold: seg.sel
                    font.family: s.theme.font; font.pixelSize: s.theme.size - 1
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.picked(seg.modelData.value) }
            }
        }
    }
}
