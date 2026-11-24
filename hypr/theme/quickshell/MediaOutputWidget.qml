// MediaOutputWidget.qml - desktop "now playing" card for any MPRIS player.
// It mirrors the bar MediaWidget's player selection and time formatting. DesktopClock.qml shows it under the clock.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: widget
    property var theme
    width: implicitWidth
    height: implicitHeight

    readonly property var player: pickPlayer()
    readonly property bool active: player !== null && player !== undefined && player.trackTitle !== ""
    readonly property bool canSeekNow: active && player.canSeek && player.positionSupported && player.length > 0
    readonly property real fraction: canSeekNow ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    function pickPlayer() {
        const ps = Mpris.players.values
        let paused = null
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].isPlaying) return ps[i]
            if (paused === null && ps[i].playbackState === MprisPlaybackState.Paused) paused = ps[i]
        }
        return paused !== null ? paused : (ps.length > 0 ? ps[0] : null)
    }
    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec))
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60
        const ss = String(r).padStart(2, "0")
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss
    }
    function togglePlay() { if (active && player.canTogglePlaying) player.togglePlaying() }
    function nextTrack() { if (active && player.canGoNext) player.next() }
    function previousTrack() { if (active && player.canGoPrevious) player.previous() }
    function seek(f) {
        if (!canSeekNow) return
        player.position = f * player.length
        player.positionChanged()
    }

    // Ask the player for its position once a second while it is playing
    Timer {
        interval: 1000
        running: widget.visible && widget.active && widget.player.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: widget.player.positionChanged()
    }

    implicitWidth: 380
    implicitHeight: col.implicitHeight + 20

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
        spacing: 14

        // ---- artwork + what is playing ----
        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Rectangle {
                Layout.preferredWidth: 104; Layout.preferredHeight: 104
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
                Image {
                    id: art
                    anchors.fill: parent; anchors.margins: 1
                    visible: status === Image.Ready
                    source: widget.active ? widget.player.trackArtUrl : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 208; sourceSize.height: 208
                }
                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "\uf001"
                    color: "#80ffffff"
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: 38
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    text: widget.active && widget.player.isPlaying ? "NOW PLAYING" : (widget.active ? "PAUSED" : "NOTHING PLAYING")
                    color: widget.theme.icon; font.bold: true; font.letterSpacing: 2
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size - 4
                }
                Text {
                    Layout.fillWidth: true
                    text: widget.active ? widget.player.trackTitle : "Start a player to see it here"
                    color: "#ffffff"; font.bold: widget.active
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: widget.active ? widget.theme.size + 6 : widget.theme.size
                }
                Text {
                    Layout.fillWidth: true
                    visible: widget.active && widget.player.trackArtist !== ""
                    text: widget.active ? widget.player.trackArtist : ""
                    color: "#e6ffffff"; elide: Text.ElideRight
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size + 1
                }
                Text {
                    Layout.fillWidth: true
                    visible: widget.active && widget.player.trackAlbum !== ""
                    text: widget.active ? widget.player.trackAlbum : ""
                    color: "#99ffffff"; elide: Text.ElideRight
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size - 2
                }
            }
        }

        // ---- progress ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            opacity: widget.canSeekNow ? 1 : 0.5
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 14
                Rectangle { id: track; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter } height: 3; color: Qt.rgba(1, 1, 1, 0.25) }
                Rectangle { anchors { left: track.left; verticalCenter: track.verticalCenter } height: 3; width: track.width * widget.fraction; color: widget.theme.icon }
                Rectangle {   // the handle: appears on hover
                    visible: seekArea.containsMouse && widget.canSeekNow
                    anchors.verticalCenter: track.verticalCenter
                    x: Math.max(0, Math.min(track.width - width, track.width * widget.fraction - width / 2))
                    width: 10; height: 10; color: "#ffffff"
                }
                MouseArea {
                    id: seekArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: widget.canSeekNow ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: mouse => widget.seek(Math.max(0, Math.min(1, mouse.x / width)))
                    onPositionChanged: mouse => { if (pressed) widget.seek(Math.max(0, Math.min(1, mouse.x / width))) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: widget.active ? widget.fmt(widget.player.position) : "0:00"
                    color: "#e6ffffff"
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size - 2
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: widget.active && widget.player.lengthSupported && widget.player.length > 0 ? widget.fmt(widget.player.length) : "live"
                    color: "#99ffffff"
                    style: Text.Raised; styleColor: "#99000000"
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size - 2
                }
            }
        }

        MediaControls {
            Layout.alignment: Qt.AlignHCenter
            theme: widget.theme
            player: widget.active ? widget.player : null
            shadow: true
        }
        MediaExtras {
            Layout.fillWidth: true
            theme: widget.theme
            player: widget.active ? widget.player : null
            shadow: true
        }
    }
}
