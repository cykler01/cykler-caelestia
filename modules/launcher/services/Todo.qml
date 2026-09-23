pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// NOTE(fork): port of the fuzzel to-do list from the dotfiles. Tasks are a flat list kept
// under the shell's data directory; the launcher shows them with a leading "New task" row,
// picking a task marks it done (removes it) and picking "New task" hands over to the
// ">todo add " prompt. The old fuzzel cache is imported once so nothing is lost moving over.
Singleton {
    id: root

    readonly property string storePath: `${Paths.data}/todo.json`
    readonly property string legacyPath: `${Paths.home}/.local/share/todo-fuzzel/todo.cache`
    readonly property string prefix: `${GlobalConfig.launcher.actionPrefix}todo`
    readonly property string addPrefix: `${root.prefix} add `

    property var tasks: []
    property int revision
    property bool imported: false

    function save(): void {
        const data = JSON.stringify(root.tasks);
        // Deferred so that writing right after a failed load (the file not existing yet)
        // is safe, like the other services that seed a state file
        Qt.callLater(() => storage.setText(data));
        root.revision++;
    }

    function add(task: string): void {
        const trimmed = task.trim();
        if (!trimmed || root.tasks.includes(trimmed))
            return;

        root.tasks = [...root.tasks, trimmed];
        root.save();
    }

    function complete(task: string): void {
        const next = root.tasks.filter(t => t !== task);
        if (next.length === root.tasks.length)
            return;

        root.tasks = next;
        root.save();
    }

    function load(text: string): void {
        try {
            const data = JSON.parse(text);
            if (Array.isArray(data))
                root.tasks = data.filter(t => typeof t === "string" && t.length > 0);
        } catch (e) {
            console.warn(lc, `Unable to parse the to-do list: ${e}`);
        }

        root.revision++;
    }

    function importLegacy(text: string): void {
        if (root.imported)
            return;

        root.imported = true;
        root.tasks = text.split("\n").map(line => line.trim()).filter((line, index, lines) => line.length > 0 && lines.indexOf(line) === index);
        root.save();
    }

    // The text after ">todo ", which is empty for a bare ">todo"
    function queryFor(search: string): string {
        return search === root.prefix ? "" : search.slice(root.prefix.length + 1);
    }

    function items(search: string): var {
        const query = root.queryFor(search);
        if (query === "add" || query.startsWith("add "))
            return [root.addEntry(query.slice("add ".length))];

        const matches = query ? root.tasks.filter(task => task.toLowerCase().includes(query.toLowerCase())) : root.tasks;
        return [root.newTaskEntry()].concat(matches.map(root.taskEntry));
    }

    function newTaskEntry(): var {
        return {
            name: Tr.tr("New task"),
            desc: Tr.tr("Create a new task"),
            icon: "add",
            onClicked: list => list.search.text = root.addPrefix
        };
    }

    function addEntry(task: string): var {
        const trimmed = task.trim();
        return {
            name: trimmed ? Tr.tr("Add \"%1\"").arg(trimmed) : Tr.tr("Type a task to add"),
            desc: trimmed ? Tr.tr("Press enter to add it") : Tr.tr("Type a name and press enter"),
            icon: "add_task",
            onClicked: list => {
                if (!trimmed)
                    return;

                root.add(trimmed);
                list.search.text = `${root.prefix} `;
            }
        };
    }

    function taskEntry(task: string): var {
        return {
            name: task,
            desc: Tr.tr("Mark as done"),
            icon: "radio_button_unchecked",
            onClicked: () => root.complete(task)
        };
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.modules.launcher.todo"
        defaultLogLevel: LoggingCategory.Warning
    }

    FileView {
        id: storage

        printErrors: false
        path: root.storePath
        onLoaded: root.load(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                legacyImport.running = true;
            else
                console.warn(lc, `Unable to load the to-do list: ${err}`);
        }
    }

    Process {
        id: legacyImport

        command: ["cat", root.legacyPath]
        stdout: StdioCollector {
            id: legacyOutput

            onStreamFinished: root.importLegacy(text)
        }
        // Covered by the collector, but a missing cache file must still seed the list
        onExited: root.importLegacy(legacyOutput.text)
    }
}
