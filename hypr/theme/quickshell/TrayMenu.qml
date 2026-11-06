// TrayMenu.qml - tray icon right-click menu (drawn by us, matches the theme)
import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: pop
    required property var theme
    required property var sni        // SystemTrayItem
    required property Item target    // the icon the menu opens under
    property var currentMenu: null

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    implicitWidth: 230
    implicitHeight: col.implicitHeight + 16 + 6
    color: "transparent"

    function openMenu() {
        currentMenu = sni.menu
        visible = true
        closeTimer.interval = 3500   // closes itself if the mouse never enters the menu
        closeTimer.restart()
    }
    function closeMenu() { visible = false; closeTimer.stop() }

    Timer { id: closeTimer; onTriggered: pop.closeMenu() }
    QsMenuOpener { id: opener; menu: pop.currentMenu }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 6
        radius: 0
        color: pop.theme.bg
        border.color: pop.theme.muted
        border.width: 1

        HoverHandler {
            onHoveredChanged: {
                if (hovered) closeTimer.stop()
                else { closeTimer.interval = 600; closeTimer.restart() }
            }
        }

        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            spacing: 2

            // Back out of a submenu
            Rectangle {
                visible: pop.currentMenu !== pop.sni.menu
                Layout.fillWidth: true; height: 28; radius: 0
                color: backMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                Text {
                    anchors.verticalCenter: parent.verticalCenter; x: 10
                    text: "\uf053  Back"; color: pop.theme.icon
                    font.family: pop.theme.font; font.pixelSize: pop.theme.size - 1
                }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; onClicked: pop.currentMenu = pop.sni.menu }
            }

            Text {
                visible: opener.children.values.length === 0
                text: "Menu is empty"
                color: pop.theme.muted; leftPadding: 10; topPadding: 4; bottomPadding: 4
                font.family: pop.theme.font; font.pixelSize: pop.theme.size - 1
            }

            Repeater {
                model: opener.children
                delegate: Item {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: modelData.isSeparator ? 9 : 30

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 8; height: 1
                        color: pop.theme.muted
                    }
                    Rectangle {
                        visible: !entry.modelData.isSeparator
                        anchors.fill: parent; radius: 0
                        color: ma.containsMouse && entry.modelData.enabled ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.text
                                elide: Text.ElideRight
                                color: entry.modelData.enabled ? pop.theme.fg : pop.theme.muted
                                font.family: pop.theme.font; font.pixelSize: pop.theme.size - 1
                            }
                            Text {
                                visible: entry.modelData.hasChildren
                                text: "\uf054"; color: pop.theme.muted
                                font.family: pop.theme.font; font.pixelSize: pop.theme.size - 3
                            }
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent; hoverEnabled: true
                            enabled: entry.modelData.enabled
                            onClicked: {
                                if (entry.modelData.hasChildren) pop.currentMenu = entry.modelData
                                else { entry.modelData.triggered(); pop.closeMenu() }
                            }
                        }
                    }
                }
            }
        }
    }
}
