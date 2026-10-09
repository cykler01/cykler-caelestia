pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// NOTE(fork): the notepad. One free-form text buffer, autosaved to
// `${Paths.data}/notepad.txt` as it is typed, so it survives the shell reloading.
// It is the store behind the notepad tab of the notification popout (see
// modules/notepadpopout/Content.qml). There is no list of notes and no formatting,
// just the one buffer.
Singleton {
    id: root

    readonly property string storePath: `${Paths.data}/notepad.txt`

    // The whole buffer, and whether it has been written to yet. `edited` keeps a
    // slow first load from overwriting something typed in the meantime.
    property string text
    property bool edited

    function save(value: string): void {
        if (root.text === value)
            return;

        root.text = value;
        root.edited = true;
        // Deferred so writing right after the file turns out not to exist yet is
        // safe, like the other services that seed a state file
        Qt.callLater(() => storage.setText(root.text));
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
        onLoaded: {
            if (!root.edited)
                root.text = text();
        }
        onLoadFailed: err => {
            // A missing file is the normal first run: an empty notepad, and the file
            // itself is created on the first keystroke
            if (err !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load the notepad: ${err}`);
        }
    }
}
