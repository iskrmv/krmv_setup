// MediaControls.qml - the control buttons of a media player. Only what the player really supports is shown:
//   shuffle (Spotify, VLC...), repeat (off / playlist / one track), back 10 s and forward 10 s (YouTube, podcasts, videos
//   - everything that can seek), previous / play-pause / next. A YouTube tab has no shuffle or repeat, so you do not see them.
// Used by the bar's hover popup and by the desktop media widget.
import QtQuick
import Quickshell.Services.Mpris

Item {
    id: c
    required property var theme
    property var player: null
    property bool shadow: false              // desktop widget: bright icons with a soft shadow
    property int size: 20                    // glyph size of the small buttons; play / pause is bigger

    readonly property bool ok: player !== null && player !== undefined
    readonly property bool canSeekNow: ok && player.canSeek && player.positionSupported && player.length > 0
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight + 4

    function seekBy(sec) {
        if (!canSeekNow) return
        player.position = Math.max(0, Math.min(player.length, player.position + sec))
        player.positionChanged()
    }
    function cycleLoop() {
        if (!ok || !player.loopSupported) return
        const s = player.loopState
        player.loopState = (s === MprisLoopState.None) ? MprisLoopState.Playlist
                          : (s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
    }

    // one button: every button is as tall as the big play button, so the whole row sits on one centre line
    component Btn: Item {
        id: b
        property string glyph: ""
        property string badge: ""
        property bool usable: true
        property bool lit: false
        property bool big: false
        signal clicked()
        implicitWidth: big ? 52 : 38
        implicitHeight: 52
        Rectangle {                                   // the visible shape (centered, 36 or 48 px)
            anchors.centerIn: parent
            width: b.big ? 48 : 36; height: width
            color: b.big ? (area.containsMouse && b.usable ? Qt.lighter(c.theme.icon, 1.15) : c.theme.icon)
                         : (area.containsMouse && b.usable ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
            border.width: b.big ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.3)
            opacity: b.usable ? 1 : 0.35
            Behavior on color { ColorAnimation { duration: 90 } }
            Text {
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                // the play triangle is heavy on its left side: nudge it right so it looks centered
                leftPadding: (b.big && b.glyph === "\uf04b") ? 3 : 0
                text: b.glyph
                color: b.big ? c.theme.bg : (!b.usable ? c.theme.muted : (b.lit ? c.theme.icon : (c.shadow ? "#ffffff" : c.theme.fg)))
                style: c.shadow && !b.big ? Text.Raised : Text.Normal; styleColor: "#99000000"
                font.family: c.theme.font; font.pixelSize: b.big ? c.size + 4 : c.size
            }
            Text {
                visible: b.badge !== ""
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 3; bottomMargin: 1 }
                text: b.badge; color: c.theme.icon; font.bold: true
                font.family: c.theme.font; font.pixelSize: c.theme.size - 5
            }
        }
        // a lit dot under shuffle / repeat when they are on
        Rectangle {
            visible: b.lit && !b.big
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
            width: 4; height: 4; color: c.theme.icon
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.usable) b.clicked() }
    }

    Row {
        id: row
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Btn {   // shuffle
            visible: c.ok && c.player.shuffleSupported
            glyph: "\uf074"; lit: c.ok && c.player.shuffle
            onClicked: c.player.shuffle = !c.player.shuffle
        }
        Btn { glyph: "\uf048"; usable: c.ok && c.player.canGoPrevious; onClicked: c.player.previous() }
        Btn { visible: c.canSeekNow; glyph: "\uf04a"; badge: "10"; onClicked: c.seekBy(-10) }
        Btn {
            big: true
            glyph: c.ok && c.player.isPlaying ? "\uf04c" : "\uf04b"
            usable: c.ok && c.player.canTogglePlaying
            onClicked: c.player.togglePlaying()
        }
        Btn { visible: c.canSeekNow; glyph: "\uf04e"; badge: "10"; onClicked: c.seekBy(10) }
        Btn { glyph: "\uf051"; usable: c.ok && c.player.canGoNext; onClicked: c.player.next() }
        Btn {   // repeat: dim = off, lit = playlist, lit with a "1" = one track
            visible: c.ok && c.player.loopSupported
            glyph: "\uf01e"
            lit: c.ok && c.player.loopState !== MprisLoopState.None
            badge: (c.ok && c.player.loopState === MprisLoopState.Track) ? "1" : ""
            onClicked: c.cycleLoop()
        }
    }
}
