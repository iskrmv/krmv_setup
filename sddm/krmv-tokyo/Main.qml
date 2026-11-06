import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1080

    // ---- Theme (same as the bar's shell.qml) ----
    readonly property color bg: "#1a1b26"
    readonly property color card: "#1f2335"
    readonly property color fg: "#a9b1d6"
    readonly property color muted: "#444b6a"
    readonly property color cyan: "#0db9d7"
    readonly property color purple: "#ad8ee6"
    readonly property color red: "#f7768e"
    readonly property color blue: "#7aa2f7"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool failed: false
    property var now: new Date()

    color: bg

    function userName(i) {
        const n = userModel.data(userModel.index(i, 0), Qt.UserRole + 1)
        return n ? n : userModel.lastUser
    }
    function sessionName(i) {
        const n = sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4)
        return n ? n : "Session"
    }
    function doLogin() {
        failed = false
        sddm.login(userName(userIndex), pw.text, sessionIndex)
    }

    Image {
        id: wall
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }
    // Darken the wallpaper so the text stays readable
    Rectangle { anchors.fill: parent; color: root.bg; opacity: 0.55; visible: wall.visible }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: root.now = new Date()
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.failed = true
            pw.text = ""
            pw.forceActiveFocus()
        }
    }

    // ---- Clock ----
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.14
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.cyan; font.bold: true
            font.family: root.fontFamily; font.pixelSize: 96
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM yyyy")
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: 20
        }
    }

    // ---- Login card ----
    Rectangle {
        id: loginCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.46
        width: 380; height: 190
        radius: 0
        color: root.card
        border.color: root.muted; border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 16

            // User (click to switch to the next one)
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (userModel.count > 1 ? "‹  " : "") + root.userName(root.userIndex) + (userModel.count > 1 ? "  ›" : "")
                color: root.cyan; font.bold: true
                font.family: root.fontFamily; font.pixelSize: 24
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
                }
            }

            // Password
            Rectangle {
                width: 320; height: 46; radius: 0
                color: root.bg
                border.width: 1
                border.color: root.failed ? root.red : (pw.activeFocus ? root.cyan : root.muted)

                TextInput {
                    id: pw
                    anchors.fill: parent; anchors.margins: 14
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.fg; clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.fontFamily; font.pixelSize: 18
                    focus: true
                    onAccepted: root.doLogin()
                    onTextChanged: root.failed = false

                    Text {
                        visible: pw.text === ""
                        anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                        text: "Password"
                        color: root.muted
                        font.family: root.fontFamily; font.pixelSize: 18
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.failed ? "Wrong password" : "Press Enter to log in"
                color: root.failed ? root.red : root.muted
                font.family: root.fontFamily; font.pixelSize: 14
            }
        }
    }

    // ---- Bottom bar: session + power ----
    Row {
        anchors { left: parent.left; bottom: parent.bottom; margins: 28 }
        spacing: 10
        Text {
            visible: sessionModel.count > 0
            text: "\uf2d0  " + root.sessionName(root.sessionIndex)
            color: root.blue
            font.family: root.fontFamily; font.pixelSize: 16
            MouseArea {
                anchors.fill: parent
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
            }
        }
    }

    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 }
        spacing: 24
        Text {
            visible: sddm.canReboot
            text: "\uf021  Reboot"
            color: root.fg
            font.family: root.fontFamily; font.pixelSize: 16
            MouseArea { anchors.fill: parent; onClicked: sddm.reboot() }
        }
        Text {
            visible: sddm.canPowerOff
            text: "\uf011  Shut down"
            color: root.red
            font.family: root.fontFamily; font.pixelSize: 16
            MouseArea { anchors.fill: parent; onClicked: sddm.powerOff() }
        }
    }

    Component.onCompleted: pw.forceActiveFocus()
}
