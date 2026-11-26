// krmv-tokyo - a minimal, animated and responsive SDDM login screen in the Tokyo Night colors of the desktop.
//   - still, animated (gif) or video wallpaper that follows the mouse a little
//   - clock whose digits roll, one login block whose password is a transparent line with dots that pop in
//   - every user can be picked (click, or Left / Right arrow keys on an empty password), session and keyboard layout
//     are choosable, power icons ask twice, the password can be shown, Caps Lock is announced
//   - everything scales with the screen and rearranges on narrow or portrait screens
// Icons are drawn (Icon.qml), so no icon font is needed.
// Test it without logging out:  sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/krmv-tokyo
import QtQuick

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#0f1019"
    clip: true

    // ---- look (the same colors as the bar) ----
    readonly property color fg: "#c0caf5"
    readonly property color dim: "#7982a9"
    readonly property color red: "#f7768e"
    readonly property color amber: "#e0af68"
    readonly property color blue: "#7aa2f7"
    readonly property color accent: config.accent ? config.accent : "#0db9d7"
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property real dimAmount: config.dim ? Number(config.dim) : 0.42

    // ---- responsive: one scale factor from the smaller side, and a few layout modes ----
    readonly property real u: Math.max(0.5, Math.min(width / 1920, height / 1080))
    readonly property bool narrow: width < 1000 * Math.max(0.75, u)
    readonly property bool portrait: height > width

    // ---- state ----
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property bool failed: false
    property bool busy: false
    property bool leaving: false
    property bool sessionMenu: false
    property bool showPw: false
    property string confirmPower: ""
    property var now: new Date()
    // staged start: each part fades in after the one before
    property bool readyClock: false
    property bool readyLogin: false
    property bool readyBottom: false

    readonly property string bgFile: config.background ? String(config.background) : ""
    readonly property string bgExt: bgFile.indexOf(".") >= 0 ? bgFile.split(".").pop().toLowerCase() : ""
    readonly property string bgKind: bgFile === "" ? "none"
                                     : (["mp4", "webm", "mkv", "mov", "avi"].indexOf(bgExt) >= 0 ? "video"
                                     : (bgExt === "gif" ? "gif" : "image"))

    function userAt(i, role) {            // role: "name" | "realName" | "icon"
        if (userModel.count <= 0) return ""
        const base = { name: Qt.UserRole + 1, realName: Qt.UserRole + 2, icon: Qt.UserRole + 4 }
        const v = userModel.data(userModel.index(i, 0), base[role])
        return v ? String(v) : ""
    }
    readonly property string userName: userAt(userIndex, "name") !== "" ? userAt(userIndex, "name") : String(userModel.lastUser)
    readonly property string userLabel: userAt(userIndex, "realName") !== "" ? userAt(userIndex, "realName") : userName
    function sessionLabel(i) {
        const n = sessionModel.data(sessionModel.index(i, 0), Qt.UserRole + 4)      // NameRole of SDDM's SessionModel
        return n ? String(n) : "Session"
    }
    function selectUser(i) {
        if (i === userIndex) { pw.forceActiveFocus(); return }
        userFade.restart()
        userIndex = i
        pw.text = ""; failed = false
        pw.forceActiveFocus()
    }
    function doLogin() {
        if (busy || pw.text === "") return
        failed = false; busy = true
        sddm.login(userName, pw.text, sessionIndex)
    }
    function power(kind) {
        if (confirmPower === kind) {
            confirmPower = ""
            if (kind === "reboot") sddm.reboot(); else if (kind === "off") sddm.powerOff(); else sddm.suspend()
        } else {
            confirmPower = kind; confirmTimer.restart()
        }
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer { id: confirmTimer; interval: 2600; onTriggered: root.confirmPower = "" }
    Timer { interval: 80;  running: true; onTriggered: root.readyClock = true }
    Timer { interval: 420; running: true; onTriggered: root.readyLogin = true }
    Timer { interval: 800; running: true; onTriggered: root.readyBottom = true }

    // =============================================================== wallpaper
    MouseArea {      // the wallpaper follows the mouse a little; a click elsewhere closes menus and keeps typing
        id: track
        anchors.fill: parent
        hoverEnabled: true
        z: -1
        onClicked: { root.sessionMenu = false; pw.forceActiveFocus() }
    }
    Item {
        id: stage
        width: root.width; height: root.height
        scale: 1.09
        readonly property real px: track.containsMouse ? -(track.mouseX / root.width - 0.5) * 34 * root.u : 0
        readonly property real py: track.containsMouse ? -(track.mouseY / root.height - 0.5) * 22 * root.u : 0
        x: px; y: py
        Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        opacity: root.readyClock ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 1100 } }

        Image {
            id: still
            visible: root.bgKind === "image" && status === Image.Ready
            anchors.fill: parent
            source: root.bgKind === "image" ? Qt.resolvedUrl(root.bgFile) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            transformOrigin: Item.Center
            // a very slow breathing keeps a still picture alive
            SequentialAnimation on scale {
                running: still.visible; loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.05; duration: 30000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.05; to: 1.0; duration: 30000; easing.type: Easing.InOutSine }
            }
        }
        AnimatedImage {
            visible: root.bgKind === "gif"
            anchors.fill: parent
            source: root.bgKind === "gif" ? Qt.resolvedUrl(root.bgFile) : ""
            fillMode: Image.PreserveAspectCrop
            playing: visible
        }
        Loader {
            anchors.fill: parent
            active: root.bgKind === "video"
            source: "VideoBackground.qml"
            onLoaded: item.source = Qt.resolvedUrl(root.bgFile)
        }
    }
    // dim the picture, darker toward the bottom, so every text stays readable
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.06, 0.1, root.dimAmount * 0.6) }
            GradientStop { position: 0.55; color: Qt.rgba(0.06, 0.06, 0.1, root.dimAmount) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.06, 0.1, Math.min(1, root.dimAmount + 0.35)) }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false; root.failed = true
            pw.text = ""
            shake.restart()
            pw.forceActiveFocus()
        }
        function onLoginSucceeded() { root.leaving = true }
    }

    // =============================================================== top left: the computer's name
    Text {
        anchors { left: parent.left; top: parent.top; margins: 34 * root.u }
        text: sddm.hostName
        color: root.dim
        font.family: root.fontFamily; font.pixelSize: 15 * root.u; font.letterSpacing: 3
        opacity: root.readyBottom ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: 700 } }
    }

    // =============================================================== clock
    Column {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (root.portrait ? 0.1 : 0.12)
        spacing: 2 * root.u
        opacity: root.readyClock ? 1 : 0
        property real shift: root.readyClock ? 0 : -28 * root.u
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
        Behavior on shift { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        transform: Translate { y: clock.shift }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            RollText { value: Qt.formatDateTime(root.now, "HH"); pixelSize: 132 * root.u; color: "white"; family: root.fontFamily }
            Text {
                text: ":"; color: root.accent
                font.family: root.fontFamily; font.pixelSize: 132 * root.u; font.weight: Font.Light
                SequentialAnimation on opacity {
                    running: true; loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.2; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.2; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            RollText { value: Qt.formatDateTime(root.now, "mm"); pixelSize: 132 * root.u; color: "white"; family: root.fontFamily }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(root.now, "dddd, d MMMM").toUpperCase()
            color: root.fg; opacity: 0.85
            font.family: root.fontFamily; font.pixelSize: 17 * root.u; font.letterSpacing: 5
        }
    }

    // =============================================================== login block
    Column {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (root.portrait ? 0.42 : 0.5)
        width: Math.min(380 * root.u, root.width - 60)
        spacing: 22 * root.u
        opacity: root.readyLogin ? 1 : 0
        property real shift: root.readyLogin ? 0 : 36 * root.u
        Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
        Behavior on shift { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
        transform: Translate { y: login.shift }

        // who is logging in (fades when you pick another user)
        Column {
            id: who
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 14 * root.u
            SequentialAnimation { id: userFade
                NumberAnimation { target: who; property: "opacity"; to: 0; duration: 100 }
                NumberAnimation { target: who; property: "opacity"; to: 1; duration: 260 }
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 92 * root.u; height: width
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 2; border.color: root.accent
                Image {
                    id: face
                    anchors.fill: parent; anchors.margins: 2
                    source: root.userAt(root.userIndex, "icon") !== "" ? "file://" + root.userAt(root.userIndex, "icon") : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: root.userLabel.substring(0, 1).toUpperCase()
                    color: root.accent; font.bold: true
                    font.family: root.fontFamily; font.pixelSize: 42 * root.u
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.userLabel
                color: "white"; font.bold: true
                font.family: root.fontFamily; font.pixelSize: 24 * root.u
            }
        }

        // the password: no box, no fill, just a line; the dots pop in as you type
        Item {
            id: pwField
            width: parent.width; height: 56 * root.u
            property real shakeX: 0
            transform: Translate { x: pwField.shakeX }
            SequentialAnimation { id: shake
                NumberAnimation { target: pwField; property: "shakeX"; to: -18 * root.u; duration: 60 }
                NumberAnimation { target: pwField; property: "shakeX"; to: 15 * root.u; duration: 90 }
                NumberAnimation { target: pwField; property: "shakeX"; to: -10 * root.u; duration: 80 }
                NumberAnimation { target: pwField; property: "shakeX"; to: 5 * root.u; duration: 70 }
                NumberAnimation { target: pwField; property: "shakeX"; to: 0; duration: 60 }
            }

            // the real input is invisible; it keeps the keyboard focus and the text
            TextInput {
                id: pw
                width: 1; height: 1; opacity: 0
                echoMode: TextInput.Password
                enabled: !root.busy
                focus: true
                onAccepted: root.doLogin()
                onTextChanged: root.failed = false
                Keys.onEscapePressed: { text = ""; root.sessionMenu = false }
                Keys.onLeftPressed: event => {
                    if (text === "" && userModel.count > 1) { root.selectUser((root.userIndex - 1 + userModel.count) % userModel.count); event.accepted = true }
                    else event.accepted = false
                }
                Keys.onRightPressed: event => {
                    if (text === "" && userModel.count > 1) { root.selectUser((root.userIndex + 1) % userModel.count); event.accepted = true }
                    else event.accepted = false
                }
            }

            // eye: show or hide what you typed
            Item {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: 40 * root.u; height: width
                opacity: pw.text !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Icon {
                    anchors.centerIn: parent; width: 22 * root.u; height: width
                    kind: root.showPw ? "eyeoff" : "eye"
                    color: eyeArea.containsMouse ? "white" : root.dim
                }
                MouseArea { id: eyeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.showPw = !root.showPw; pw.forceActiveFocus() } }
            }

            // what you typed: one dot per character, each with its own position (no layout that could stack them),
            // the group stays centered and slides apart smoothly as it grows
            Item {
                id: dots
                anchors.fill: parent
                visible: !root.showPw
                readonly property int count: Math.min(pw.text.length, 22)
                readonly property real dot: 9 * root.u
                readonly property real gap: 10 * root.u
                readonly property real step: dot + gap
                readonly property real total: count > 0 ? count * step - gap : 0
                readonly property real left0: width / 2 - total / 2
                Repeater {
                    model: 22
                    delegate: Rectangle {
                        id: dotItem
                        required property int index
                        readonly property bool on: index < dots.count
                        width: dots.dot; height: dots.dot
                        anchors.verticalCenter: parent.verticalCenter
                        x: dots.left0 + index * dots.step
                        Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                        color: root.failed ? root.red : "white"
                        scale: on ? 1 : 0
                        opacity: on ? 1 : 0
                        Behavior on scale { NumberAnimation { duration: 190; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }
                Rectangle {     // the cursor, right after the last dot
                    width: 2; height: 24 * root.u; color: root.accent
                    visible: pw.activeFocus && !root.busy
                    anchors.verticalCenter: parent.verticalCenter
                    x: dots.left0 + dots.total + (dots.count > 0 ? dots.gap : 0) - 1
                    Behavior on x { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                    SequentialAnimation on opacity {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0; duration: 520 }
                        NumberAnimation { from: 0; to: 1; duration: 520 }
                    }
                }
            }
            Text {
                visible: root.showPw && pw.text !== ""
                anchors { left: parent.left; right: parent.right; leftMargin: 46 * root.u; rightMargin: 46 * root.u; verticalCenter: parent.verticalCenter }
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideLeft
                text: pw.text; color: root.failed ? root.red : "white"
                font.family: root.fontFamily; font.pixelSize: 22 * root.u
            }
            Text {
                anchors.centerIn: parent
                text: root.busy ? "Logging in..." : "Password"
                color: root.dim; font.family: root.fontFamily; font.pixelSize: 18 * root.u; font.letterSpacing: 2
                opacity: pw.text === "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            // arrow (or three dots while logging in)
            Item {
                id: go
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 40 * root.u; height: width
                opacity: (pw.text !== "" || root.busy) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Icon {
                    anchors.centerIn: parent; width: 24 * root.u; height: width
                    visible: !root.busy
                    kind: "arrow"
                    color: goArea.containsMouse ? "white" : root.accent
                    anchors.horizontalCenterOffset: goArea.containsMouse ? 4 : 0
                    Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
                Row {
                    anchors.centerIn: parent; spacing: 5 * root.u; visible: root.busy
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            required property int index
                            width: 6 * root.u; height: width; color: root.accent
                            SequentialAnimation on opacity {
                                running: root.busy; loops: Animation.Infinite
                                PauseAnimation { duration: index * 140 }
                                NumberAnimation { from: 0.2; to: 1; duration: 280 }
                                NumberAnimation { from: 1; to: 0.2; duration: 280 }
                                PauseAnimation { duration: (2 - index) * 140 }
                            }
                        }
                    }
                }
                MouseArea { id: goArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.doLogin() }
            }

            // the line under it: grey, with a bright part that grows from the middle on focus or error
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Qt.rgba(1, 1, 1, 0.28) }
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                height: 2
                width: (pw.activeFocus || root.failed) ? parent.width : 0
                color: root.failed ? root.red : root.accent
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // hints: wrong password, Caps Lock
        Item {
            width: parent.width; height: 22 * root.u
            Row {
                anchors.centerIn: parent
                spacing: 8 * root.u
                opacity: (root.failed || keyboard.capsLock) ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Icon {
                    width: 16 * root.u; height: width; anchors.verticalCenter: parent.verticalCenter
                    kind: "caps"; visible: !root.failed; color: root.amber
                }
                Text {
                    text: root.failed ? "Wrong password. Try again." : "Caps Lock is on"
                    color: root.failed ? root.red : root.amber
                    font.family: root.fontFamily; font.pixelSize: 14 * root.u
                }
            }
        }
    }

    // =============================================================== other users (click, or Left / Right keys)
    Row {
        id: users
        visible: userModel.count > 1
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: (root.narrow ? 100 : 38) * root.u }
        spacing: 20 * root.u
        opacity: root.readyBottom ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700 } }
        Repeater {
            model: userModel
            delegate: Item {
                id: urow
                required property int index
                required property string name
                readonly property bool current: index === root.userIndex
                width: 74 * root.u; height: 80 * root.u
                opacity: current ? 1 : (uarea.containsMouse ? 0.9 : 0.55)
                Behavior on opacity { NumberAnimation { duration: 160 } }
                Rectangle {
                    id: tile
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 46 * root.u; height: width
                    color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: urow.current ? 2 : 1
                    border.color: urow.current ? root.accent : Qt.rgba(1, 1, 1, 0.25)
                    scale: uarea.pressed ? 0.92 : (uarea.containsMouse ? 1.08 : 1)
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent
                           text: root.userAt(urow.index, "realName") !== "" ? root.userAt(urow.index, "realName").substring(0, 1).toUpperCase() : urow.name.substring(0, 1).toUpperCase()
                           color: urow.current ? root.accent : "white"; font.bold: true
                           font.family: root.fontFamily; font.pixelSize: 20 * root.u }
                }
                Text {
                    anchors { horizontalCenter: parent.horizontalCenter; top: tile.bottom; topMargin: 7 * root.u }
                    width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: urow.name; color: "white"
                    font.family: root.fontFamily; font.pixelSize: 12 * root.u
                }
                MouseArea { id: uarea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectUser(urow.index) }
            }
        }
    }

    // =============================================================== bottom left: session + keyboard layout
    Row {
        id: leftBar
        anchors { left: parent.left; bottom: parent.bottom; margins: 34 * root.u }
        spacing: 24 * root.u
        opacity: root.readyBottom ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700 } }

        Item {
            id: sessionChip
            width: sRow.implicitWidth; height: 32 * root.u
            visible: sessionModel.count > 0
            Row {
                id: sRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.u
                Icon { width: 20 * root.u; height: width; anchors.verticalCenter: parent.verticalCenter; kind: "session"
                       color: sArea.containsMouse ? "white" : root.blue }
                Text {
                    visible: !root.narrow
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.sessionLabel(root.sessionIndex)
                    color: sArea.containsMouse ? "white" : root.blue
                    font.family: root.fontFamily; font.pixelSize: 15 * root.u
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
                Icon { visible: sessionModel.count > 1; width: 16 * root.u; height: width; anchors.verticalCenter: parent.verticalCenter; kind: "chevron"
                       color: root.dim; rotation: root.sessionMenu ? 180 : 0
                       Behavior on rotation { NumberAnimation { duration: 180 } } }
            }
            MouseArea { id: sArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (sessionModel.count > 1) root.sessionMenu = !root.sessionMenu }
            // the list of sessions opens upwards
            Rectangle {
                id: menuBox
                visible: opacity > 0
                opacity: root.sessionMenu ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                anchors { left: parent.left; bottom: parent.top; bottomMargin: 12 * root.u }
                transform: Translate { y: root.sessionMenu ? 0 : 8 * root.u
                                       Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } } }
                width: 250 * root.u                       // a fixed width: the rows below fill it, nothing depends on them
                height: sessionModel.count * 36 * root.u + 16
                color: Qt.rgba(0.06, 0.06, 0.1, 0.92)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.18)
                Column {
                    id: menuCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 }
                    Repeater {
                        model: sessionModel
                        delegate: Rectangle {
                            id: srow
                            required property int index
                            required property string name
                            width: parent.width; height: 36 * root.u
                            color: mArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Rectangle { width: 3; height: parent.height; color: root.accent; visible: srow.index === root.sessionIndex }
                            Text { anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                   text: srow.name; color: srow.index === root.sessionIndex ? root.accent : "white"
                                   font.family: root.fontFamily; font.pixelSize: 15 * root.u }
                            MouseArea { id: mArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.sessionIndex = srow.index; root.sessionMenu = false; pw.forceActiveFocus() } }
                        }
                    }
                }
            }
        }

        Item {
            id: layoutChip
            visible: keyboard.layouts.length > 1
            width: lRow.implicitWidth; height: 32 * root.u
            Row {
                id: lRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.u
                Icon { width: 22 * root.u; height: width; anchors.verticalCenter: parent.verticalCenter; kind: "keyboard"
                       color: lArea.containsMouse ? "white" : root.dim }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyboard.layouts.length > 0 ? String(keyboard.layouts[keyboard.currentLayout].shortName).toUpperCase() : ""
                    color: lArea.containsMouse ? "white" : root.dim
                    font.family: root.fontFamily; font.pixelSize: 15 * root.u
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
            MouseArea { id: lArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length }
        }
    }

    // =============================================================== bottom right: power (icons only, asks twice)
    Row {
        anchors { right: parent.right; bottom: parent.bottom; margins: 28 * root.u }
        spacing: 8 * root.u
        opacity: root.readyBottom ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700 } }
        PowerButton { u: root.u; family: root.fontFamily; kind: "sleep";  label: "Sleep";     tint: root.dim
                      canDo: sddm.canSuspend;  confirming: root.confirmPower === "suspend"; onActivated: root.power("suspend") }
        PowerButton { u: root.u; family: root.fontFamily; kind: "reboot"; label: "Reboot";    tint: root.fg
                      canDo: sddm.canReboot;   confirming: root.confirmPower === "reboot";  onActivated: root.power("reboot") }
        PowerButton { u: root.u; family: root.fontFamily; kind: "power";  label: "Shut down"; tint: root.red
                      canDo: sddm.canPowerOff; confirming: root.confirmPower === "off";     onActivated: root.power("off") }
    }

    // leaving: everything fades to black before the session starts
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.leaving ? 1 : 0; visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 500 } } }

    Component.onCompleted: pw.forceActiveFocus()
}
