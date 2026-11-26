import QtQuick
import qs.modules.lock.layouts

// The status pills, which ones and in what order as set in Nexus > Lock screen > Status pills
StatusChips {
    property real s: 1
    property var lock: null
    property var opts: ({})

    uiScale: s * 0.9
    layoutDirection: opts.direction === "left" ? Qt.LeftToRight : Qt.RightToLeft
}
