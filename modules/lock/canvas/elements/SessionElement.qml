import QtQuick
import qs.modules.lock.layouts

// Log out, shut down, sleep and restart, as listed under Nexus > Lock screen > Session controls,
// which also switches them on and off
SessionBar {
    property real s: 1
    property var opts: ({})
    property var lock: null

    uiScale: s
}
