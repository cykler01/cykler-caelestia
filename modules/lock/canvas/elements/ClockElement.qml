import QtQuick
import qs.modules.lock.layouts

// The time, drawn as the face option picks (modules/lock/layouts/ClockFace.qml)
ClockFace {
    property real s: 1
    property var lock: null
    property var opts: ({})

    face: opts.face ?? "line"
    faceScale: s
    accent: opts.accent ?? true
    alignment: opts.align === "left" ? Qt.AlignLeft : opts.align === "right" ? Qt.AlignRight : Qt.AlignHCenter
}
