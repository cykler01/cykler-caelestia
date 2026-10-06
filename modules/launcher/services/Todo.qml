pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.utils

// NOTE(fork): the to-do list. Started as a port of the fuzzel to-do list from the dotfiles (a
// flat list of task strings); now it is the store behind the to-do tab of the notification
// popout, so tasks are objects with a list, a done flag, an optional deadline and any number of
// reminders. The launcher no longer touches it - lists, editing and dates are all in the popout.
Singleton {
    id: root

    readonly property string storePath: `${Paths.data}/todo.json`
    readonly property string legacyPath: `${Paths.home}/.local/share/todo-fuzzel/todo.cache`
    readonly property string defaultListId: "default"

    // { id, name }
    property var lists: [{
            id: root.defaultListId,
            name: Tr.tr("Tasks")
        }]
    // { id, text, listId, done, deadline, reminders }. deadline is an ISO date-time string, or
    // "" when not set. reminders is a list of { at, reminded }, each an independent alarm; there
    // can be any number of them, including none.
    property var tasks: []
    property int revision
    property bool imported: false

    function uid(): string {
        return `${Date.now().toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`;
    }

    function save(): void {
        const data = JSON.stringify({
            version: 2,
            lists: root.lists,
            tasks: root.tasks
        });
        // Deferred so that writing right after a failed load (the file not existing yet)
        // is safe, like the other services that seed a state file
        Qt.callLater(() => storage.setText(data));
        root.revision++;
    }

    function listName(listId: string): string {
        return root.lists.find(l => l.id === listId)?.name ?? Tr.tr("Tasks");
    }

    function addList(name: string): string {
        const trimmed = name.trim();
        if (!trimmed)
            return "";

        const id = root.uid();
        root.lists = [...root.lists, {
                id,
                name: trimmed
            }];
        root.save();
        return id;
    }

    function renameList(id: string, name: string): void {
        const trimmed = name.trim();
        if (!trimmed)
            return;

        root.lists = root.lists.map(l => l.id === id ? Object.assign({}, l, {
                    name: trimmed
                }) : l);
        root.save();
    }

    // The default list can't be removed, so there is always somewhere for a task to live.
    // Its own tasks move to the default list rather than disappearing.
    function removeList(id: string): void {
        if (id === root.defaultListId)
            return;

        root.lists = root.lists.filter(l => l.id !== id);
        root.tasks = root.tasks.map(t => t.listId === id ? Object.assign({}, t, {
                    listId: root.defaultListId
                }) : t);
        root.save();
    }

    function addTask(text: string, listId: string): string {
        const trimmed = text.trim();
        if (!trimmed)
            return "";

        const id = root.uid();
        root.tasks = [...root.tasks, {
                id,
                text: trimmed,
                listId: listId || root.defaultListId,
                done: false,
                deadline: "",
                reminders: []
            }];
        root.save();
        return id;
    }

    // Merges whichever fields are given (text, listId, deadline, done) into the task. Reminders
    // are handled separately below, since they are a list rather than a single value.
    function editTask(id: string, fields: var): void {
        let changed = false;
        root.tasks = root.tasks.map(t => {
            if (t.id !== id)
                return t;

            changed = true;
            return Object.assign({}, t, fields);
        });

        if (changed)
            root.save();
    }

    // Adds a reminder for this exact moment (an ISO string); a task can have any number
    function addReminder(id: string, at: string): void {
        root.editTask(id, {
            reminders: [...(root.tasks.find(t => t.id === id)?.reminders ?? []), {
                    at,
                    reminded: false
                }].sort((a, b) => a.at.localeCompare(b.at))
        });
    }

    function removeReminder(id: string, index: int): void {
        const task = root.tasks.find(t => t.id === id);
        if (!task)
            return;

        root.editTask(id, {
            reminders: task.reminders.filter((_, i) => i !== index)
        });
    }

    function toggleDone(id: string): void {
        root.editTask(id, {
            done: !root.tasks.find(t => t.id === id)?.done
        });
    }

    function removeTask(id: string): void {
        const next = root.tasks.filter(t => t.id !== id);
        if (next.length === root.tasks.length)
            return;

        root.tasks = next;
        root.save();
    }

    // Nothing removes a done task by itself; this is the only way one goes away other than by hand
    function clearCompleted(listId: string): void {
        const next = root.tasks.filter(t => t.listId !== listId || !t.done);
        if (next.length === root.tasks.length)
            return;

        root.tasks = next;
        root.save();
    }

    // A task from disk into one every function above can rely on: reminders as a list, always
    // migrating an older single "reminder"/"reminded" pair into a one-entry list if there is one
    function normaliseTask(t: var): var {
        let reminders;
        if (Array.isArray(t.reminders))
            reminders = t.reminders.filter(r => r && typeof r.at === "string").map(r => ({
                        at: r.at,
                        reminded: !!r.reminded
                    }));
        else if (typeof t.reminder === "string" && t.reminder)
            reminders = [{
                    at: t.reminder,
                    reminded: !!t.reminded
                }];
        else
            reminders = [];

        return {
            id: typeof t.id === "string" && t.id ? t.id : root.uid(),
            text: t.text,
            listId: typeof t.listId === "string" && t.listId ? t.listId : root.defaultListId,
            done: !!t.done,
            deadline: typeof t.deadline === "string" ? t.deadline : "",
            reminders
        };
    }

    function load(text: string): void {
        try {
            const data = JSON.parse(text);

            if (Array.isArray(data)) {
                // Pre-lists format: a flat array of task strings
                root.tasks = data.filter(t => typeof t === "string" && t.length > 0).map(t => root.normaliseTask({
                            text: t
                        }));
            } else if (data && typeof data === "object") {
                if (Array.isArray(data.lists) && data.lists.length > 0)
                    root.lists = data.lists;
                if (Array.isArray(data.tasks))
                    root.tasks = data.tasks.filter(t => t && typeof t.text === "string" && t.text.length > 0).map(root.normaliseTask);
            }
        } catch (e) {
            console.warn(lc, `Unable to parse the to-do list: ${e}`);
        }

        root.revision++;
    }

    function importLegacy(text: string): void {
        if (root.imported)
            return;

        root.imported = true;
        const lines = text.split("\n").map(line => line.trim()).filter((line, index, lines) => line.length > 0 && lines.indexOf(line) === index);
        if (lines.length > 0) {
            root.tasks = lines.map(t => root.normaliseTask({
                        text: t
                    }));
            root.save();
        }
    }

    // A real notification rather than a toast: it lands in the actual notification dock and
    // stays there until dismissed, like any app's, instead of appearing and disappearing on its
    // own. Sent over the same org.freedesktop.Notifications interface the shell itself listens
    // on (that is what "notify-send" is), rather than anything special-cased for the to-do list.
    function notifyReminder(text: string): void {
        Quickshell.execDetached(["notify-send", "--app-name=To-do", "--icon=notifications-active", "--urgency=normal", Tr.tr("Task reminder"), text]);
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

    // Checks for due reminders. A shell that isn't running can't remind you, same as any other
    // in-shell timer (idle timeouts, battery warnings); there is no separate daemon for this.
    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            let changed = false;

            for (const t of root.tasks) {
                if (t.done)
                    continue;

                for (const r of t.reminders) {
                    if (r.reminded)
                        continue;

                    const at = Date.parse(r.at);
                    if (!Number.isNaN(at) && at <= now) {
                        root.notifyReminder(t.text);
                        changed = true;
                        r.reminded = true;
                    }
                }
            }

            if (changed) {
                root.tasks = [...root.tasks];
                root.save();
            }
        }
    }
}
