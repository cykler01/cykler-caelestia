import QtQuick
import Caelestia.Config
import qs.services

// A line from the desktop's bottom text (services/BottomText.qml), one of the lines set in
// Nexus. It moves on to another line as often as the desktop's does; with the desktop's bottom
// text switched off, this keeps it turning over itself
TextBlock {
    id: root

    content: BottomText.current

    Component.onCompleted: {
        if (BottomText.current === "")
            BottomText.pick();
    }

    Timer {
        interval: Math.max(1000, GlobalConfig.utilities.bottomText.cycleInterval)
        running: !GlobalConfig.utilities.bottomText.enabled && BottomText.texts.length > 1
        repeat: true
        onTriggered: BottomText.pick()
    }
}
