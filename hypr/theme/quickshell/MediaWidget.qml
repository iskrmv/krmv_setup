// MediaWidget.qml - "now playing" for ANY media player that speaks MPRIS:
// Spotify, VLC, mpv (with mpv-mpris), YouTube / Netflix / music sites in Chrome or Firefox, ...
// In the bar: back / play-pause / next, the title and the current time.
// On hover: a floating popup with the full info and a slider you can seek with.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: media
    required property var theme
    property real maxWidth: 360
    property string popupId: "media"
    property string activePopup: ""
    signal popupRequested()

    // The player to show: one that is playing, else a paused one, else the first one
    readonly property var player: pickPlayer()
    function pickPlayer() {
        const ps = Mpris.players.values
        let paused = null
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying) return ps[i]
            if (paused === null && ps[i].playbackState === MprisPlaybackState.Paused) paused = ps[i]
        }
        return paused !== null ? paused : (ps.length > 0 ? ps[0] : null)
    }
    readonly property bool active: player !== null && player.trackTitle !== ""
    readonly property bool canSeekNow: active && player.canSeek && player.positionSupported && player.length > 0
    readonly property real fraction: canSeekNow ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec))
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60
        const ss = String(r).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss
    }

    visible: active
    implicitHeight: 30
    implicitWidth: Math.min(maxWidth, row.implicitWidth)

    // ---- the position only updates when asked: ask once a second (4x per second while the popup is open) ----
    Timer {
        interval: media.showPopup ? 250 : 1000
        running: media.active && media.player.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: media.player.positionChanged()
    }

    // ---- seeking (at most every 100 ms) ----
    property real dragFraction: -1
    property real pendingSeek: -1
    // After a seek the player needs a moment to report the new position. Until then the slider stays where you put it
    // (without this it jumped back to the old position and then forward again), and the position is read again twice.
    property bool holding: false
    property real holdFraction: 0
    Timer { id: holdTimer; interval: 1000; onTriggered: media.holding = false }
    Timer { id: refreshTimer; interval: 350; onTriggered: if (media.active) media.player.positionChanged() }
    function seek(f) {
        if (!canSeekNow) return
        dragFraction = f
        pendingSeek = f
        holdFraction = f; holding = true; holdTimer.restart(); refreshTimer.restart()
        if (!seekThrottle.running) flushSeek()
    }
    function flushSeek() {
        if (pendingSeek < 0 || !canSeekNow) return
        player.position = pendingSeek * player.length
        pendingSeek = -1
        player.positionChanged()
        refreshTimer.restart()
        seekThrottle.start()
    }
    Timer { id: seekThrottle; interval: 100; onTriggered: media.flushSeek() }

    // repeat: off -> playlist -> one track -> off
    function cycleLoop() {
        if (!active || !player.loopSupported) return
        const s = player.loopState
        player.loopState = (s === MprisLoopState.None) ? MprisLoopState.Playlist
                          : (s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
    }

    // ---- hover popup: stays open while the mouse is over the widget OR the popup; only one bar popup at a time ----
    property bool hoverPopup: false
    property bool showPopup: false
    readonly property bool wantPopup: active && (hover.hovered || hoverPopup)
    onWantPopupChanged: { if (wantPopup) { popupRequested(); showPopup = true; closeTimer.stop() } else closeTimer.restart() }
    onActivePopupChanged: { if (activePopup !== popupId && showPopup) { showPopup = false; hoverPopup = false; closeTimer.stop() } }
    Timer { id: closeTimer; interval: 250; onTriggered: media.showPopup = false }
    HoverHandler { id: hover }

    // ---- the bar widget ----
    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Row {
            id: buttons
            spacing: 10
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [
                    { glyph: "\uf048", kind: "prev" },
                    { glyph: "play",   kind: "toggle" },
                    { glyph: "\uf051", kind: "next" }
                ]
                delegate: Text {
                    id: btn
                    required property var modelData
                    readonly property bool enabledNow: media.active && (modelData.kind === "prev" ? media.player.canGoPrevious
                                                       : modelData.kind === "next" ? media.player.canGoNext
                                                       : media.player.canTogglePlaying)
                    text: modelData.kind === "toggle" ? (media.active && media.player.isPlaying ? "\uf04c" : "\uf04b") : modelData.glyph
                    color: !enabledNow ? media.theme.muted : (bArea.containsMouse ? media.theme.fg : media.theme.icon)
                    font.family: media.theme.font
                    font.pixelSize: media.theme.size
                    MouseArea {
                        id: bArea
                        anchors { fill: parent; margins: -4 }
                        hoverEnabled: true
                        onClicked: {
                            if (!btn.enabledNow) return
                            if (btn.modelData.kind === "prev") media.player.previous()
                            else if (btn.modelData.kind === "next") media.player.next()
                            else media.player.togglePlaying()
                        }
                    }
                }
            }
        }

        MarqueeText {
            id: title
            anchors.verticalCenter: parent.verticalCenter
            maxWidth: Math.min(280, Math.max(80, media.maxWidth - buttons.width - timeText.width - 2 * row.spacing))   // stops growing at 280 px
            text: media.active ? media.player.trackTitle + (media.player.trackArtist !== "" ? "  -  " + media.player.trackArtist : "") : ""
            color: media.theme.fg
            fontFamily: media.theme.font
            pixelSize: media.theme.size
        }

        Text {
            id: timeText
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            text: media.active ? media.fmt(media.player.position) : ""
            color: media.theme.dim
            font.family: media.theme.font
            font.pixelSize: media.theme.size - 1
        }
    }

    // ---- the floating popup ----
    PopupWindow {
        visible: media.showPopup && media.active
        anchor.item: media
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: 360
        implicitHeight: popupCol.implicitHeight + 32 + 6
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 6
            color: media.theme.bg
            border.width: 1
            border.color: media.theme.muted

            HoverHandler { onHoveredChanged: media.hoverPopup = hovered }

            ColumnLayout {
                id: popupCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Image {
                        visible: status === Image.Ready
                        source: media.active ? media.player.trackArtUrl : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 128
                        sourceSize.height: 128
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        MarqueeText {
                            Layout.fillWidth: true
                            maxWidth: 400
                            text: media.active ? media.player.trackTitle : ""
                            color: media.theme.fg; bold: true
                            fontFamily: media.theme.font; pixelSize: media.theme.size + 1
                        }
                        MarqueeText {
                            visible: text !== ""
                            Layout.fillWidth: true
                            maxWidth: 400
                            text: media.active ? media.player.trackArtist : ""
                            color: media.theme.icon
                            fontFamily: media.theme.font; pixelSize: media.theme.size
                        }
                        Text {
                            visible: text !== ""
                            Layout.fillWidth: true
                            text: media.active ? media.player.trackAlbum : ""
                            elide: Text.ElideRight
                            color: media.theme.dim
                            font.family: media.theme.font; font.pixelSize: media.theme.size - 2
                        }
                        Text {
                            Layout.fillWidth: true
                            text: media.active ? media.player.identity : ""
                            elide: Text.ElideRight
                            color: media.theme.dim
                            font.family: media.theme.font; font.pixelSize: media.theme.size - 3
                        }
                    }
                }

                Slider {
                    id: seekSlider
                    Layout.fillWidth: true
                    theme: media.theme
                    enabled: media.canSeekNow
                    opacity: media.canSeekNow ? 1 : 0.4
                    value: (pressed && media.dragFraction >= 0) ? media.dragFraction : (media.holding ? media.holdFraction : media.fraction)
                    onMoved: v => media.seek(v)
                    onPressedChanged: if (!pressed) media.dragFraction = -1
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: media.active ? media.fmt(media.holding && media.player.length > 0 ? media.holdFraction * media.player.length : media.player.position) : ""
                        color: media.theme.fg
                        font.family: media.theme.font; font.pixelSize: media.theme.size - 1
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: media.active && media.player.lengthSupported && media.player.length > 0 ? media.fmt(media.player.length) : "live"
                        color: media.theme.dim
                        font.family: media.theme.font; font.pixelSize: media.theme.size - 1
                    }
                }

                // ---- controls: back, play / pause, next, repeat ----
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 30

                    Text {
                        text: "\uf048"
                        color: (media.active && media.player.canGoPrevious) ? (backArea.containsMouse ? media.theme.fg : media.theme.icon) : media.theme.muted
                        font.family: media.theme.font; font.pixelSize: media.theme.size + 6
                        MouseArea { id: backArea; anchors { fill: parent; margins: -6 } hoverEnabled: true
                                    onClicked: if (media.active && media.player.canGoPrevious) media.player.previous() }
                    }
                    Text {
                        text: media.active && media.player.isPlaying ? "\uf04c" : "\uf04b"
                        color: (media.active && media.player.canTogglePlaying) ? (playArea.containsMouse ? media.theme.fg : media.theme.icon) : media.theme.muted
                        font.family: media.theme.font; font.pixelSize: media.theme.size + 10
                        MouseArea { id: playArea; anchors { fill: parent; margins: -6 } hoverEnabled: true
                                    onClicked: if (media.active && media.player.canTogglePlaying) media.player.togglePlaying() }
                    }
                    Text {
                        text: "\uf051"
                        color: (media.active && media.player.canGoNext) ? (nextArea.containsMouse ? media.theme.fg : media.theme.icon) : media.theme.muted
                        font.family: media.theme.font; font.pixelSize: media.theme.size + 6
                        MouseArea { id: nextArea; anchors { fill: parent; margins: -6 } hoverEnabled: true
                                    onClicked: if (media.active && media.player.canGoNext) media.player.next() }
                    }
                    Item {   // repeat: dim = off, lit = playlist, lit with a "1" = one track
                        readonly property bool supported: media.active && media.player.loopSupported
                        readonly property bool lit: supported && media.player.loopState !== MprisLoopState.None
                        implicitWidth: repeatGlyph.implicitWidth + 8
                        implicitHeight: repeatGlyph.implicitHeight
                        Text {
                            id: repeatGlyph
                            text: "\uf01e"
                            color: parent.supported ? (parent.lit ? media.theme.icon : media.theme.dim) : media.theme.muted
                            font.family: media.theme.font; font.pixelSize: media.theme.size + 4
                        }
                        Text {
                            visible: parent.supported && media.player.loopState === MprisLoopState.Track
                            anchors { right: parent.right; top: parent.top }
                            text: "1"
                            color: media.theme.icon; font.bold: true
                            font.family: media.theme.font; font.pixelSize: media.theme.size - 4
                        }
                        MouseArea { anchors { fill: parent; margins: -6 } onClicked: media.cycleLoop() }
                    }
                }
            }
        }
    }
}
