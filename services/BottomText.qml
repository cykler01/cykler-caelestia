pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.utils

// NOTE(fork): the line of text shown at random along the bottom of the screen (modules/bottomtext).
//
// The texts live in a plain file, one per line, with # starting a note that is skipped, so adding
// more is just adding a line. Editing them in Nexus (Shell assets -> Desktop text) writes the
// user's own copy under the data directory, which wins over the shell's file: the shipped list is
// never written to (it can be read only, e.g. under /etc/xdg), and it can be brought back from
// there. Both files are watched, so a change shows up without restarting the shell.
Singleton {
    id: root

    readonly property string defaultPath: Quickshell.shellPath("assets/bottom-texts.txt")
    readonly property string userPath: `${Paths.assetsdir}/bottom-texts.txt`
    // The file in use: the user's copy once there is one, the shell's own until then
    readonly property string path: root.customized ? root.userPath : root.defaultPath
    property bool customized: false

    // Shown when the file is missing or has been emptied, so the overlay is never blank by accident
    readonly property var fallback: [
        "You are exactly where you need to be.",
        "One thing at a time.",
        "Small steps still count."
    ]
    property var texts: root.fallback
    property string current: ""
    // The whole list as it is being written out, cleared once the writer has taken it
    property string pendingWrite: ""

    // One per line; blank lines and notes are dropped, so an empty file reads as an empty list
    function parse(text: string): var {
        return text.split("\n").map(line => line.trim()).filter(line => line !== "" && !line.startsWith("#"));
    }

    // The shell's own list, or the built-in lines when its file cannot be read or has none
    function shippedLines(): var {
        const lines = root.parse(shippedFile.text());
        return lines.length > 0 ? lines : root.fallback;
    }

    // Never the same text twice in a row, so a rotation is visible even from a short list
    function pick(): void {
        if (root.texts.length === 0) {
            root.current = "";
            return;
        }

        const others = root.texts.filter(text => text !== root.current);
        root.current = others.length > 0 ? others[Math.floor(Math.random() * others.length)] : root.texts[0];
    }

    // Writes the given list as the user's copy, creating the folder it lives in if needed
    function save(lines: var): void {
        root.texts = lines;
        root.customized = true;
        root.pendingWrite = lines.length > 0 ? lines.join("\n") + "\n" : "";
        if (!writer.running)
            writer.running = true;
    }

    function setLine(index: int, text: string): void {
        if (index < 0 || index >= root.texts.length)
            return;

        if (text.trim() === "") {
            root.removeLine(index);
            return;
        }

        const lines = root.texts.slice();
        lines[index] = text.trim();
        root.save(lines);
    }

    function addLine(text: string): void {
        const line = text.trim();
        if (line === "")
            return;

        root.save([...root.texts, line]);
    }

    function removeLine(index: int): void {
        if (index < 0 || index >= root.texts.length)
            return;

        root.save(root.texts.filter((_, i) => i !== index));
    }

    // Empties the list, so nothing is shown at the bottom until a line is added again
    function removeAll(): void {
        if (root.texts.length === 0)
            return;

        root.save([]);
    }

    // Drops the user's copy, so the shell's own list is used again
    function restoreDefaults(): void {
        if (!root.customized)
            return;

        if (!CUtils.deleteFile(Qt.resolvedUrl(root.userPath)))
            return;

        root.customized = false;
        root.texts = root.shippedLines();
        root.pick();
    }

    onTextsChanged: root.pick()

    Component.onCompleted: root.pick()

    FileView {
        id: userFile

        path: root.userPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            root.customized = true;
            root.texts = root.parse(text());
        }
        onLoadFailed: {
            root.customized = false;
            root.texts = root.shippedLines();
        }
    }

    FileView {
        id: shippedFile

        path: root.defaultPath
        // Small enough to read on the spot rather than after the first frame, so the overlay never
        // flashes a fallback line before the real list arrives
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (!root.customized)
                root.texts = root.shippedLines();
        }
        onLoadFailed: {
            if (!root.customized)
                root.texts = root.fallback;
        }
    }

    Process {
        id: writer

        command: ["sh", "-c", "mkdir -p \"$1\" && cat > \"$2\"", "sh", Paths.assetsdir, root.userPath]
        stdinEnabled: true

        onStarted: {
            write(root.pendingWrite);
            root.pendingWrite = "";
        }

        onExited: {
            if (root.pendingWrite !== "")
                writer.running = true;
        }
    }

    // Rotates while the overlay is on, so a long session is not one frozen line
    Timer {
        interval: Math.max(1000, GlobalConfig.utilities.bottomText.cycleInterval)
        running: GlobalConfig.utilities.bottomText.enabled && root.texts.length > 1
        repeat: true
        onTriggered: root.pick()
    }
}
