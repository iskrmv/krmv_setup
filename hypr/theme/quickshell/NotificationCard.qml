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
        if (a.startsWith("/")) return "file://" + a
        // check = true: an icon the theme does not have gives "" instead of the pink/black "missing" checkerboard
        return Quickshell.iconPath(a, true)
    }
    // a glyph that stands in when there is no usable icon (theme colored)
    function fallbackGlyph() {
        const a = (notif.appIcon || "").toLowerCase()
        if (a.indexOf("battery") >= 0) return (a.indexOf("empty") >= 0 || a.indexOf("low") >= 0) ? "\uf244" : "\uf243"
        if (a.indexOf("network") >= 0 || a.indexOf("wifi") >= 0) return "\uf1eb"
        if (a.indexOf("mail") >= 0 || a.indexOf("message") >= 0) return "\uf0e0"
        if (a.indexOf("volume") >= 0 || a.indexOf("audio") >= 0) return "\uf028"
        if (a.indexOf("appointment") >= 0 || a.indexOf("alarm") >= 0 || a.indexOf("clock") >= 0) return "\uf017"
        return critical ? "\uf071" : "\uf0f3"
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
        card.wantsTyping(false)
    }
    // Keyboard focus is requested only while you type a reply; a new notification never steals it.
    signal wantsTyping(bool on)
    Timer { id: focusTimer; interval: 80; onTriggered: replyInput.forceActiveFocus() }

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

            Item {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                IconImage {
                    id: cardIcon
                    anchors.fill: parent
                    visible: card.iconSource() !== "" && status === Image.Ready
                    source: card.iconSource()
                    implicitSize: 40
                }
                // no icon, or one that could not be loaded: a tile in the theme colors
                Rectangle {
                    anchors.fill: parent
                    visible: !cardIcon.visible
                    color: card.critical ? Qt.rgba(0.97, 0.46, 0.56, 0.14) : Qt.rgba(0.05, 0.73, 0.84, 0.13)
                    border.width: 1; border.color: card.critical ? card.theme.red : card.theme.icon
                    Text {
                        anchors.centerIn: parent
                        text: card.fallbackGlyph()
                        color: card.critical ? card.theme.red : card.theme.icon
                        font.family: card.theme.font; font.pixelSize: 20
                    }
                }
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
            MouseArea { anchors.fill: parent; onPressed: mouse => { card.wantsTyping(true); focusTimer.restart(); mouse.accepted = false } }
            TextInput {
                id: replyInput
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                color: card.theme.fg; clip: true
                font.family: card.theme.font; font.pixelSize: card.theme.size - 2
                onAccepted: card.sendReply()
                Keys.onEscapePressed: { replyInput.focus = false; card.wantsTyping(false) }
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
