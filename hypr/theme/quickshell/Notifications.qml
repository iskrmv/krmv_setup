// Notifications.qml - notification daemon + popups (top right, below the bar).
// Every notification stays 10 seconds and shows a countdown bar at the bottom.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root
    required property var theme
    property int timeout: 10000   // ms, the same for every notification

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notification => { notification.tracked = true }
        // Newer Quickshell versions can show a reply box for chat apps. Older ones ignore this line.
        Component.onCompleted: { try { server.inlineReplySupported = true } catch (e) {} }
    }

    PanelWindow {
        screen: Quickshell.screens[0]
        visible: server.trackedNotifications.values.length > 0
        anchors { top: true; right: true }
        margins { top: 38; right: 12 }
        exclusionMode: ExclusionMode.Ignore
        focusable: true            // lets you type into the reply box
        implicitWidth: 360
        implicitHeight: list.implicitHeight
        color: "transparent"

        ColumnLayout {
            id: list
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications
                delegate: NotificationCard {
                    required property var modelData
                    theme: root.theme
                    notif: modelData
                    duration: root.timeout
                }
            }
        }
    }
}
