// SpinIcon.qml - the scan/refresh button. While `spinning` it shows a spinner that rotates smoothly.
import QtQuick

Text {
    id: t
    required property var theme
    property string idleIcon: "\uf021"      // shown when idle
    property string spinIcon: "\uf021"      // shown while spinning
    property bool spinning: false
    signal clicked()

    width: 22; height: 22                   // fixed box: the icon never changes the layout
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: spinning ? spinIcon : idleIcon
    color: spinning ? theme.icon : theme.fg
    font.family: theme.font
    font.pixelSize: theme.size + 1

    RotationAnimator on rotation {
        running: t.spinning
        from: 0; to: 360
        duration: 800
        loops: Animation.Infinite
        onRunningChanged: if (!running) t.rotation = 0
    }
    MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: t.clicked() }
}
