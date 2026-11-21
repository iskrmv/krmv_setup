// DragGhost.qml - a widget preview you can drag around inside the widget editor.
import QtQuick

Item {
    id: g
    property var theme
    default property alias content: holder.data
    Item { id: holder; anchors.fill: parent }
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: g.theme.icon }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeAllCursor
        drag.target: g
        drag.minimumX: 0; drag.maximumX: Math.max(0, g.parent.width - g.width)
        drag.minimumY: 0; drag.maximumY: Math.max(0, g.parent.height - g.height)
    }
}
