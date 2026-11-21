// PolkitDialog.qml - the password dialog for pkexec / sudogui / GParted / Ventoy ... in the bar's own theme.
// This is a polkit authentication agent written with Quickshell (Quickshell.Services.Polkit), so the window
// uses exactly the same colors, font and square corners as everything else. shell.qml loads this file on
// its own: if your Quickshell is too old for it, the stock hyprpolkitagent is started instead.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit

Scope {
    id: pk
    property var theme

    PolkitAgent { id: agent }

    readonly property var flow: agent.flow

    PanelWindow {
        id: dlg
        visible: agent.isActive && pk.flow !== null
        screen: Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: 460
        implicitHeight: card.implicitHeight
        color: "transparent"
        onVisibleChanged: if (visible) { pw.text = ""; focusTimer.restart() }

        Timer { id: focusTimer; interval: 120; onTriggered: pw.forceActiveFocus() }
        Connections {
            target: pk.flow
            function onAuthenticationFailed() { pw.text = ""; pw.forceActiveFocus() }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            implicitHeight: col.implicitHeight + 36
            color: pk.theme.bg
            border.width: 1
            border.color: pk.theme.icon

            ColumnLayout {
                id: col
                anchors { fill: parent; margins: 18 }
                spacing: 12

                Text {
                    text: "\uf023  Authentication required"
                    color: pk.theme.icon; font.bold: true
                    font.family: pk.theme.font; font.pixelSize: pk.theme.size + 2
                }
                Text {
                    Layout.fillWidth: true
                    text: pk.flow ? pk.flow.message : ""
                    color: pk.theme.fg; wrapMode: Text.Wrap
                    font.family: pk.theme.font; font.pixelSize: pk.theme.size
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!pk.flow && pk.flow.supplementaryMessage !== ""
                    text: pk.flow ? pk.flow.supplementaryMessage : ""
                    color: (!!pk.flow && pk.flow.supplementaryIsError) ? pk.theme.red : pk.theme.dim
                    wrapMode: Text.Wrap
                    font.family: pk.theme.font; font.pixelSize: pk.theme.size - 1
                }
                Text {
                    Layout.fillWidth: true
                    visible: !!pk.flow && pk.flow.failed
                    text: "Wrong password. Try again."
                    color: pk.theme.red; font.bold: true
                    font.family: pk.theme.font; font.pixelSize: pk.theme.size - 1
                }
                Text {
                    Layout.fillWidth: true
                    text: pk.flow && pk.flow.inputPrompt !== "" ? pk.flow.inputPrompt : "Password:"
                    color: pk.theme.dim
                    font.family: pk.theme.font; font.pixelSize: pk.theme.size - 1
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: pw.activeFocus ? pk.theme.icon : pk.theme.muted
                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: (!!pk.flow && pk.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                        color: pk.theme.fg; clip: true
                        font.family: pk.theme.font; font.pixelSize: pk.theme.size
                        onAccepted: if (pk.flow) pk.flow.submit(text)
                        Keys.onEscapePressed: if (pk.flow) pk.flow.cancelAuthenticationRequest()
                    }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Item { Layout.fillWidth: true }
                    PanelButton { theme: pk.theme; text: "Cancel"; onClicked: if (pk.flow) pk.flow.cancelAuthenticationRequest() }
                    PanelButton { theme: pk.theme; text: "Authenticate"; accent: true; onClicked: if (pk.flow) pk.flow.submit(pw.text) }
                }
            }
        }
    }
}
