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

    implicitWidth: 320
    implicitHeight: 300

    Rectangle {
        anchors.fill: parent
        color: "transparent"      // no card behind it: the wallpaper shows through

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "Now playing"
                color: widget.theme.icon; font.bold: true
                style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 12

                Rectangle {
                    Layout.preferredWidth: 88; Layout.preferredHeight: 88
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1; border.color: widget.theme.muted
                    Image {
                        id: art
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: widget.active ? widget.player.trackArtUrl : ""
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 176; sourceSize.height: 176
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "\uf001"
                        color: "#b3ffffff"
                        style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size + 16
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: widget.active ? widget.player.trackTitle : "No media playing"
                        color: "#ffffff"; font.bold: true
                        elide: Text.ElideRight
                        style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size
                    }
                    Text {
                        Layout.fillWidth: true
                        text: widget.active ? widget.player.trackArtist : "Start a player to see it here"
                        color: widget.theme.icon
                        elide: Text.ElideRight
                        style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: widget.active && widget.player.trackAlbum !== ""
                        text: widget.active ? widget.player.trackAlbum : ""
                        color: "#b3ffffff"
                        elide: Text.ElideRight
                        style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size - 2
                    }
                }
            }

            Slider {
                Layout.fillWidth: true
                theme: widget.theme
                enabled: widget.canSeekNow
                opacity: widget.canSeekNow ? 1 : 0.4
                value: widget.fraction
                onMoved: v => widget.seek(v)
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: widget.active ? widget.fmt(widget.player.position) : "0:00"
                    color: "#ffffff"
                    style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: widget.active && widget.player.lengthSupported && widget.player.length > 0 ? widget.fmt(widget.player.length) : "live"
                    color: "#b3ffffff"
                    style: Text.Raised; styleColor: "#99000000"; font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
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
}
