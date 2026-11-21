// Chip.qml - a bar icon. Hovering it shows a floating popup (a text tip or a slider).
// A slider popup can have an "extra" area (per-app volumes, night mode) that opens smoothly with the small arrow.
import QtQuick
import Quickshell

Item {
    id: chip
    required property var theme
    property string icon: ""
    property color iconColor: theme.icon
    property string label: ""        // always-visible text (e.g. volume %)
    property string reserveLabel: "" // widest text the label can show: the chip keeps that width, so neighbours never shift
    property string tip: ""          // text shown in the floating popup on hover
    property bool ramIcon: false     // draw the RAM stick instead of a font glyph
    property bool slider: false      // popup shows a slider instead of the text tip
    property real sliderValue: 0     // 0..1
    property string sliderTitle: ""
    property Component extra: null   // optional extra content, opened with the small arrow under the slider
    property bool expanded: false
    readonly property bool hovered: area.containsMouse
    readonly property bool engaged: area.containsMouse || hoverPopup || showPopup   // icon or its popup is in use
    signal clicked()
    signal rightClicked()
    signal scrolled(int dy, bool inverted)
    signal sliderMoved(real value)

    // Only ONE popup is open at a time: hovering another icon closes this popup immediately
    property string popupId: ""
    property string activePopup: ""       // set by the bar: which icon owns the popup right now
    signal popupRequested()
    onActivePopupChanged: {
        if (popupId !== "" && activePopup !== popupId && showPopup) { showPopup = false; hoverPopup = false; closeTimer.stop() }
    }

    // The popup stays open while the mouse is over the icon OR over the popup itself
    property bool hoverPopup: false
    property bool showPopup: false
    readonly property bool wantPopup: (tip !== "" || slider) && (area.containsMouse || hoverPopup)
    onWantPopupChanged: { if (wantPopup) { popupRequested(); showPopup = true; closeTimer.stop() } else closeTimer.restart() }
    // While the popup grows or shrinks the window is re-positioned and the pointer can briefly "leave" it:
    // keep it open for a moment so that never closes it by accident.
    property bool holdOpen: false
    Timer { id: holdTimer; interval: 900; onTriggered: { chip.holdOpen = false; if (!chip.wantPopup) closeTimer.restart() } }
    Timer { id: closeTimer; interval: 250; onTriggered: { if (!chip.holdOpen) chip.showPopup = false } }

    // ---- popup geometry. The box height is animated (an accordion); the WINDOW changes size only twice:
    //      it grows at once when opening and shrinks after the closing animation has finished. ----
    readonly property real baseH: sliderCol.implicitHeight + 28
    readonly property real extraH: (expanded && extraLoader.item) ? extraLoader.item.implicitHeight + 10 : 0
    readonly property real targetH: slider ? baseH + extraH : tipText.implicitHeight + 28
    property real boxH: targetH
    Behavior on boxH { enabled: chip.slider; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    property real popupH: targetH
    onTargetHChanged: { if (targetH > popupH || !showPopup) popupH = targetH; else shrinkTimer.restart() }
    Timer { id: shrinkTimer; interval: 280; onTriggered: chip.popupH = chip.targetH }

    // the extra content stays loaded while it folds away
    property bool showExtra: false
    Timer { id: unloadTimer; interval: 280; onTriggered: chip.showExtra = false }
    onExpandedChanged: {
        holdOpen = true; holdTimer.restart(); closeTimer.stop()
        if (expanded) { unloadTimer.stop(); showExtra = true } else unloadTimer.restart()
    }
    onShowPopupChanged: {
        if (showPopup) popupH = targetH
        else { expanded = false; showExtra = false; holdOpen = false; holdTimer.stop(); hoverPopup = false }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 30

    Row {
        id: row
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        RamIcon { visible: chip.ramIcon; color: chip.iconColor }
        Text { visible: !chip.ramIcon; text: chip.icon; color: chip.iconColor; font.family: chip.theme.font; font.pixelSize: chip.theme.size + 2 }
        TextMetrics { id: reserveMetrics; text: chip.reserveLabel; font.family: chip.theme.font; font.pixelSize: chip.theme.size }
        Text {
            visible: chip.label !== ""; text: chip.label; color: chip.theme.fg
            width: chip.reserveLabel !== "" ? Math.ceil(reserveMetrics.advanceWidth) + 1 : implicitWidth
            horizontalAlignment: Text.AlignLeft
            font.family: chip.theme.font; font.pixelSize: chip.theme.size
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) chip.rightClicked(); else chip.clicked() }
        onWheel: wheel => chip.scrolled(wheel.angleDelta.y, wheel.inverted)
    }

    PopupWindow {
        visible: chip.showPopup
        anchor.item: chip
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        implicitWidth: chip.slider ? 300 : tipText.implicitWidth + 28
        implicitHeight: chip.popupH + 6
        color: "transparent"

        Rectangle {
            id: box
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 6 }
            height: chip.boxH
            clip: true
            color: chip.theme.bg
            border.color: chip.theme.muted
            border.width: 1

            HoverHandler { onHoveredChanged: chip.hoverPopup = hovered }

            Text {
                id: tipText
                visible: !chip.slider
                anchors.centerIn: parent
                text: chip.tip
                color: chip.theme.fg
                font.family: chip.theme.font
                font.pixelSize: chip.theme.size - 1
                lineHeight: 1.25
            }

            // the slider part (always the same)
            Column {
                id: sliderCol
                visible: chip.slider
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 10
                Text {
                    text: chip.sliderTitle
                    color: chip.theme.fg
                    font.family: chip.theme.font
                    font.pixelSize: chip.theme.size - 1
                }
                Slider {
                    width: parent.width
                    theme: chip.theme
                    value: chip.sliderValue
                    onMoved: v => chip.sliderMoved(v)
                    onWheeled: (dy, inv) => chip.scrolled(dy, inv)
                }
                // Small arrow (right): opens / closes the extra area. It turns smoothly.
                Item {
                    visible: chip.extra !== null
                    width: parent.width
                    height: 18
                    Text {
                        id: arrow
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: "\uf078"
                        rotation: chip.expanded ? 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        color: arrowArea.containsMouse ? chip.theme.icon : chip.theme.dim
                        font.family: chip.theme.font
                        font.pixelSize: chip.theme.size - 2
                    }
                    MouseArea { id: arrowArea; anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 40; hoverEnabled: true; onClicked: chip.expanded = !chip.expanded }
                }
            }

            // the extra content sits under the slider part and is revealed by the growing box
            Loader {
                id: extraLoader
                anchors { left: parent.left; right: parent.right; top: sliderCol.bottom; leftMargin: 14; rightMargin: 14; topMargin: 10 }
                active: chip.showExtra && chip.extra !== null
                sourceComponent: chip.extra
                opacity: chip.expanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
            }
        }
    }
}
