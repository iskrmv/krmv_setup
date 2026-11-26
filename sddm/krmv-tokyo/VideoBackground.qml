// VideoBackground.qml - a looping, silent video wallpaper (mp4, webm, mkv ...).
// Main.qml loads this file through a Loader, so if QtMultimedia is not installed the login screen simply keeps its
// plain background instead of failing. Install it with:  sudo pacman -S qt6-multimedia qt6-multimedia-ffmpeg
import QtQuick
import QtMultimedia

Item {
    id: root
    property url source
    MediaPlayer {
        id: player
        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: out
        Component.onCompleted: play()
    }
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
