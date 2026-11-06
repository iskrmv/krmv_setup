// NotificationCard.qml - one notification with a countdown bar at the bottom
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property var theme
    required property var notif          // Notification
    property int duration: 10000
    property real remaining: 1.0          // 1 -> 0 over `duration` ms
    readonly property bool critical: notif.urgency === NotificationUrgency.Critical

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 27
    color: theme.bg
    border.width: 1
    border.color: critical ? theme.red : theme.muted

    function iconSource() {
        if (notif.image !== "") return notif.image
        const a = notif.appIcon
        if (a === "") return ""
        return a.startsWith("/") ? "file://" + a : "image://icon/" + a
    }
    function hasExtraActions() {
        for (let i = 0; i < notif.actions.length; i++)
            if (notif.actions[i].identifier !== "default") return true
        return false
    }
    // Click: jump to the app's window (switches to its workspace), then run the default action
    // (e.g. open that chat). Without a default action the notification is just closed.
    function activate() {
        Quickshell.execDetached(["sh", "-c", "sh \"$HOME/.config/hypr/scripts/focus-app.sh\" \"$1\" \"$2\"",
                                 "_", notif.appName, notif.desktopEntry || ""])
        for (let i = 0; i < notif.actions.length; i++)
            if (notif.actions[i].identifier === "default") { notif.actions[i].invoke(); return }
        notif.dismiss()
    }
    function sendReply() {
        if (replyInput.text.trim() === "") return
        notif.sendInlineReply(replyInput.text)
        replyInput.text = ""
    }

    // The countdown. It pauses while the mouse is over the card.
    NumberAnimation on remaining {
        from: 1; to: 0
        duration: card.duration
        paused: hover.hovered || replyInput.activeFocus      // no countdown while you read or type
        onFinished: card.notif.expire()
    }
    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) card.notif.dismiss(); else card.activate() }
    }

    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            IconImage {
                visible: card.iconSource() !== ""
                source: card.iconSource()
                implicitSize: 40
                Layout.alignment: Qt.AlignTop
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    text: card.notif.summary
                    color: card.theme.fg; font.bold: true
                    font.family: card.theme.font; font.pixelSize: card.theme.size - 1
                    elide: Text.ElideRight
                }
                Text {
                    visible: card.notif.body !== ""
                    Layout.fillWidth: true
                    text: card.notif.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: card.theme.fg
                    font.family: card.theme.font; font.pixelSize: card.theme.size - 2
                }
                Text {
                    text: card.notif.appName
                    color: card.theme.dim
                    font.family: card.theme.font; font.pixelSize: card.theme.size - 4
                }
            }
        }

        RowLayout {
            visible: card.hasExtraActions()
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: card.notif.actions
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    visible: modelData.identifier !== "default"
                    implicitWidth: label.implicitWidth + 20
                    implicitHeight: 26
                    color: btnArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    border.width: 1
                    border.color: card.theme.muted
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: btn.modelData.text
                        color: card.theme.icon
                        font.family: card.theme.font; font.pixelSize: card.theme.size - 3
                    }
                    MouseArea { id: btnArea; anchors.fill: parent; hoverEnabled: true; onClicked: btn.modelData.invoke() }
                }
            }
        }

        // Inline reply (Telegram, Discord, ...): shown when the app supports replying from the notification
        Rectangle {
            visible: card.notif.hasInlineReply === true
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: replyInput.activeFocus ? card.theme.icon : card.theme.muted
            TextInput {
                id: replyInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                color: card.theme.fg; clip: true
                font.family: card.theme.font; font.pixelSize: card.theme.size - 2
                onAccepted: card.sendReply()
                Text {
                    visible: replyInput.text === ""
                    anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                    text: (card.notif.inlineReplyPlaceholder || "Reply") + "  (Enter to send)"
                    color: card.theme.dim; elide: Text.ElideRight
                    font.family: card.theme.font; font.pixelSize: card.theme.size - 2
                }
            }
        }
    }

    // Countdown bar (full width = just arrived, empty = about to disappear)
    Rectangle {
        anchors { left: parent.left; bottom: parent.bottom }
        height: 3
        width: parent.width * card.remaining
        color: card.critical ? card.theme.red : card.theme.icon
    }
}
