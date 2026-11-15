pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config

// NOTE(fork): the line of text shown at random along the bottom of the screen (modules/bottomtext).
//
// The texts live in a plain file so adding more is just adding a line: assets/bottom-texts.txt, one
// per line, with # starting a note that is skipped. That file is watched, so a new line shows up
// without restarting the shell.
Singleton {
    id: root

    readonly property string path: Quickshell.shellPath("assets/bottom-texts.txt")
    // Shown when the file is missing or has been emptied, so the overlay is never blank by accident
    readonly property var fallback: [
        "You are exactly where you need to be.",
        "One thing at a time.",
        "Small steps still count."
    ]
    property var texts: root.fallback
    property string current: ""

    // One per line; blank lines and notes are dropped
    function parse(text: string): var {
        const out = text.split("\n").map(line => line.trim()).filter(line => line !== "" && !line.startsWith("#"));
        return out.length > 0 ? out : root.fallback;
    }

    // Never the same text twice in a row, so a rotation is visible even from a short list
    function pick(): void {
        if (root.texts.length === 0)
            return;

        const others = root.texts.filter(text => text !== root.current);
        root.current = others.length > 0 ? others[Math.floor(Math.random() * others.length)] : root.texts[0];
    }

    onTextsChanged: root.pick()

    Component.onCompleted: root.pick()

    FileView {
        path: root.path
        // Small enough to read on the spot rather than after the first frame, so the overlay never
        // flashes a fallback line before the real list arrives
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.texts = root.parse(text())
        onLoadFailed: root.texts = root.fallback
    }

    // Rotates while the overlay is on, so a long session is not one frozen line
    Timer {
        interval: 60000
        running: GlobalConfig.utilities.bottomText.enabled && root.texts.length > 1
        repeat: true
        onTriggered: root.pick()
    }
}
