pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// NOTE(fork): the notepad. A note is a plain file in a directory of the user's
// choosing (Documents by default), browsed and edited by the notepad tab of the
// notification popout (see modules/notepadpopout/Content.qml). This holds only that
// directory and the file last opened, so both survive the shell reloading; the file
// contents are read and written by the tab itself.
Singleton {
    id: root

    readonly property string storePath: `${Paths.data}/notepad.json`
    readonly property string defaultDir: Paths.documents

    property string dir: root.defaultDir
    property string lastFile: ""
    property bool loaded

    function save(): void {
        const data = JSON.stringify({
            version: 1,
            dir: root.dir,
            lastFile: root.lastFile
        });
        // Deferred so writing right after the file turns out not to exist yet is
        // safe, like the other services that seed a state file
        Qt.callLater(() => storage.setText(data));
    }

    function setDir(path: string): void {
        if (!path || path === root.dir)
            return;

        root.dir = path;
        // The open file belonged to the old directory, so it is not carried over
        root.lastFile = "";
        root.save();
    }

    function setLastFile(path: string): void {
        if ((path ?? "") === root.lastFile)
            return;

        root.lastFile = path ?? "";
        root.save();
    }

    function load(text: string): void {
        try {
            const data = JSON.parse(text);
            if (data && typeof data === "object") {
                if (typeof data.dir === "string" && data.dir)
                    root.dir = data.dir;
                if (typeof data.lastFile === "string")
                    root.lastFile = data.lastFile;
            }
        } catch (e) {
            console.warn(lc, `Unable to parse the notepad state: ${e}`);
        }

        root.loaded = true;
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.notepad"
        defaultLogLevel: LoggingCategory.Warning
    }

    FileView {
        id: storage

        printErrors: false
        path: root.storePath
        onLoaded: root.load(text())
        onLoadFailed: err => {
            // No state file yet is the normal first run: Documents and no open file
            if (err !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load the notepad state: ${err}`);
            root.loaded = true;
        }
    }
}
