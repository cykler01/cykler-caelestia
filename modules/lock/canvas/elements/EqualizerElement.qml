import QtQuick
import qs.modules.background

// The desktop's floor equalizer (modules/background/FloorEqualizer.qml) on the lock screen: a
// spectrum of whatever is playing, filling its box. Its look comes from this element's own
// options rather than the desktop's, so the two can differ
Item {
    id: root

    property real s: 1
    property var opts: ({})
    property var lock: null
    // In the layout editor it stays up through the quiet, so there's something to see and move
    property bool editing: false

    FloorEqualizer {
        anchors.fill: parent
        maxBarHeight: root.height
        positionSetting: root.opts.grow === "down" ? "ceiling" : "floor"
        styleSetting: root.opts.style ?? "bars"
        colourSetting: root.opts.colour ?? "theme"
        shapeSetting: root.opts.shape ?? "rounded"
        barsSetting: root.opts.bars ?? 0
        amplitudeSetting: 1
        smoothnessSetting: root.opts.smoothness ?? 1
        responseSetting: root.opts.response ?? "linear"
        autoHideSetting: (root.opts.autoHide ?? true) && !root.editing
    }
}
