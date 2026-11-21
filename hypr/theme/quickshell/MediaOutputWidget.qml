// MediaOutputWidget.qml - desktop "now playing" card for any MPRIS player.
// It mirrors the bar MediaWidget's player selection and time formatting, but lives in its own window.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland

PanelWindow {
    id: widget
    required property var theme

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

    screen: Quickshell.screens[0]
    anchors { left: true; top: true }
    // Sits right under the desktop clock (and under the net speed card when that is on).
    property int clockX: -1
    property int clockY: -1
    property int stackOffset: 0
    margins { left: clockX >= 0 ? clockX : 80; top: (clockY >= 0 ? clockY + 200 : (screen ? Math.round(screen.height / 2) + 105 : 100)) + stackOffset }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    implicitWidth: 320
    implicitHeight: 256
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: widget.theme.bg
        border.width: 1
        border.color: widget.theme.muted

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: "Now playing"
                color: widget.theme.icon; font.bold: true
                font.family: widget.theme.font; font.pixelSize: widget.theme.size
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
                        color: widget.theme.dim
                        font.family: widget.theme.font; font.pixelSize: widget.theme.size + 16
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    Text {
                        Layout.fillWidth: true
                        text: widget.active ? widget.player.trackTitle : "No media playing"
                        color: widget.theme.fg; font.bold: true
                        elide: Text.ElideRight
                        font.family: widget.theme.font; font.pixelSize: widget.theme.size
                    }
                    Text {
                        Layout.fillWidth: true
                        text: widget.active ? widget.player.trackArtist : "Start a player to see it here"
                        color: widget.theme.icon
                        elide: Text.ElideRight
                        font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: widget.active && widget.player.trackAlbum !== ""
                        text: widget.active ? widget.player.trackAlbum : ""
                        color: widget.theme.dim
                        elide: Text.ElideRight
                        font.family: widget.theme.font; font.pixelSize: widget.theme.size - 2
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
                    color: widget.theme.fg
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: widget.active && widget.player.lengthSupported && widget.player.length > 0 ? widget.fmt(widget.player.length) : "live"
                    color: widget.theme.dim
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size - 1
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 26
                Text {
                    text: "\uf048"
                    color: (widget.active && widget.player.canGoPrevious) ? widget.theme.icon : widget.theme.muted
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size + 3
                    MouseArea { anchors { fill: parent; margins: -6 } onClicked: widget.previousTrack() }
                }
                Text {
                    text: widget.active && widget.player.isPlaying ? "\uf04c" : "\uf04b"
                    color: (widget.active && widget.player.canTogglePlaying) ? widget.theme.icon : widget.theme.muted
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size + 8
                    MouseArea { anchors { fill: parent; margins: -6 } onClicked: widget.togglePlay() }
                }
                Text {
                    text: "\uf051"
                    color: (widget.active && widget.player.canGoNext) ? widget.theme.icon : widget.theme.muted
                    font.family: widget.theme.font; font.pixelSize: widget.theme.size + 3
                    MouseArea { anchors { fill: parent; margins: -6 } onClicked: widget.nextTrack() }
                }
            }
        }
    }
}
