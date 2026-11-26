import QtQuick
import qs.modules.lock.center

// The profile picture, in the shape chosen under Nexus > Lock screen > Profile picture. Pulses
// while face auth is looking, as it does anywhere else on the lock screen
Item {
    id: root

    property real s: 1

    property var opts: ({})
    property var lock: null

    readonly property real size: 110 * root.s

    implicitWidth: pic.implicitWidth
    implicitHeight: pic.implicitHeight

    ProfilePic {
        id: pic

        anchors.centerIn: parent
        // ProfilePic sizes itself to 70% of the width it's given
        centerWidth: root.size / 0.7
        pam: root.lock?.pam ?? null
    }
}
