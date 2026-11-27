pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.modules.lock

// NOTE(fork): the lock screen itself: every element in the list (Config.lock.elements, or the old
// layout's preset until that's been edited) drawn where it was put, in list order, so later ones
// sit on top. Used by the lock surface, the settings page's preview and the layout editor alike.
//
// Elements can be set to show only before the sign-in starts ("rest") or only once it has
// ("active"). The first key or click starts it: anything typed, a check under way or a message to
// read holds it open, and it drops back after a while left alone with nothing typed. A list with no
// such elements never notices the difference.
//
// The password field can't be left out: a list without one gets one added in the middle near the
// bottom, so no layout can lock anyone out
Item {
    id: root

    // The lock surface, or null in the preview and the editor, where a dummy field stands in
    property var lock: null
    property var elements: LockPresets.effective(Config.lock)
    // In the editor: placeholders for empty elements, and which side of the curtain to show
    property bool editing: false
    // "" shows both sides, "rest" or "active" one side only. Only read while editing
    property string phase: ""

    // The editor's drag or resize in progress, so a drag moves one element rather than rewriting
    // the whole list on every pointer move
    property int liveIndex: -1
    // Several elements dragged together all take the same offset
    property var liveGroup: []
    property point liveOffset: Qt.point(0, 0)
    property real liveScale: 1
    property size liveBox: Qt.size(0, 0)

    readonly property real uiScale: Math.max(0.6, Math.min(1.6, height / 1080))
    // Goes up whenever an element's host is made or unmade, for whoever looks hosts up by index
    property int hostsRevision: 0

    readonly property bool hasPassword: root.elements.some(e => e.id === "password" && e.enabled !== false)
    readonly property var shownElements: root.hasPassword ? root.elements : [...root.elements, LockPresets.e("password", 0.5, 0.85, "c")]
    readonly property bool hasCurtain: root.elements.some(e => (e.showOn ?? "always") !== "always")

    readonly property var pam: root.lock?.pam ?? null
    readonly property bool busy: !!pam && (pam.buffer.length > 0 || pam.passwd.active || pam.state !== Pam.None)
    property bool lifted: false
    readonly property bool up: lifted || busy

    function hostAt(index: int): Item {
        return repeater.itemAt(index);
    }

    function lift(): void {
        root.lifted = true;
        dropTimer.restart();
    }

    function shownFor(showOn: string): real {
        const on = showOn ?? "always";
        if (on === "always")
            return 1;
        if (root.editing)
            return root.phase === "" || root.phase === on ? 1 : 0;
        return (on === "active") === root.up ? 1 : 0;
    }

    onBusyChanged: {
        if (root.busy)
            root.lift();
        else
            dropTimer.restart();
    }

    Timer {
        id: dropTimer

        interval: 20000
        onTriggered: {
            if (root.busy)
                restart();
            else
                root.lifted = false;
        }
    }

    Repeater {
        id: repeater

        // A count rather than the list, so changing an element updates its host in place instead
        // of tearing every element down and building it again
        model: root.shownElements.length

        onItemAdded: root.hostsRevision++
        onItemRemoved: root.hostsRevision++

        ElementHost {
            element: root.shownElements[index] ?? ({})
            lock: root.lock
            uiScale: root.uiScale
            editing: root.editing
            shown: root.shownFor(element.showOn)
            liveOffset: root.liveIndex === index || root.liveGroup.includes(index) ? root.liveOffset : Qt.point(0, 0)
            liveScale: root.liveIndex === index ? root.liveScale : 1
            liveBox: root.liveIndex === index ? root.liveBox : Qt.size(0, 0)
        }
    }

    // While there's a curtain down, a click anywhere lifts it rather than landing on whatever is
    // hidden under it. Presses only, so the hover handlers further up still see the pointer
    MouseArea {
        anchors.fill: parent
        enabled: root.hasCurtain && !root.up && !root.editing
        visible: enabled
        onPressed: root.lift()
    }
}
