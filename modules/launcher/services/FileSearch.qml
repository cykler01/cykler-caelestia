pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.utils

// The launcher's ">find" mode. The walking is done by assets/find-files.sh (fd, then one stat over
// the hits), which keeps a search of the whole home directory to a few tens of milliseconds; this
// only debounces the typing and turns the lines it prints into rows.
//
// Results come back newest first rather than best-matching first. Over a whole home directory the
// same name turns up in a dozen places, and the one being looked for is nearly always the one
// touched recently - which is also what makes ">find" with nothing typed useful on its own.
Singleton {
    id: root

    // What the last search was for, so the same text typed twice does not run it again
    property string query: "\u0000"
    property list<var> results: []
    property bool searching
    property bool unavailable

    readonly property int limit: Config.launcher.maxShown
    // Where to look. Empty means the home directory, which is the useful default: fd skips
    // ignored and hidden paths, and the script excludes caches and build output
    readonly property var roots: {
        const configured = GlobalConfig.launcher.fileSearchPaths;
        return configured.length > 0 ? configured.map(p => Paths.absolutePath(p)) : [Paths.home];
    }

    // The prefixes that reach this mode, both meaning the same thing. Not "search", which reads as
    // the launcher's own search rather than as a search of your files
    readonly property var prefixes: ["find", "files"]

    // The part after the prefix, or null when the text is not a file search at all
    function queryFor(text: string): var {
        const prefix = GlobalConfig.launcher.actionPrefix;
        for (const word of root.prefixes) {
            if (text === `${prefix}${word}`)
                return "";
            if (text.startsWith(`${prefix}${word} `))
                return text.slice(`${prefix}${word} `.length).trim();
        }
        return null;
    }

    // Called on every keystroke; does nothing unless this is a file search
    function prime(text: string): void {
        const wanted = root.queryFor(text);
        if (wanted === null || wanted === root.query)
            return;

        root.query = wanted;
        root.searching = true;
        debounce.restart();
    }

    function run(): void {
        proc.running = false;
        proc.command = ["bash", `${Quickshell.shellDir}/assets/find-files.sh`, String(root.limit), root.query, ...root.roots];
        proc.running = true;
    }

    // One row per file, or a single row explaining why there are none
    function rows(): var {
        if (root.unavailable)
            return [
                {
                    category: "files",
                    title: Tr.tr("fd is not installed"),
                    subtitle: Tr.tr("File search needs the fd package"),
                    icon: "error",
                    kind: "none",
                    firstOfGroup: true
                }
            ];

        return root.results.map((file, i) => ({
                    category: "files",
                    title: file.name,
                    subtitle: `${Paths.shortenHome(file.dir)} · ${root.ago(file.mtime)}`,
                    icon: Icons.getFileIcon(file.name),
                    kind: "file",
                    payload: file.path,
                    firstOfGroup: i === 0
                }));
    }

    // Rough is fine here: the point is "recently" against "a while ago", not an exact age
    function ago(mtime: int): string {
        const mins = Math.max(0, Math.round((Date.now() / 1000 - mtime) / 60));
        if (mins < 1)
            return Tr.tr("just now");
        if (mins < 60)
            return Tr.trN("%1 minute ago", "%1 minutes ago", mins).arg(mins);

        const hours = Math.round(mins / 60);
        if (hours < 24)
            return Tr.trN("%1 hour ago", "%1 hours ago", hours).arg(hours);

        const days = Math.round(hours / 24);
        if (days < 30)
            return Tr.trN("%1 day ago", "%1 days ago", days).arg(days);

        const months = Math.round(days / 30);
        return Tr.trN("%1 month ago", "%1 months ago", months).arg(months);
    }

    Timer {
        id: debounce

        // Long enough that typing a word does not start a search per letter, short enough that the
        // results are there by the time the eye gets to them
        interval: 140
        onTriggered: root.run()
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                root.results = text.split("\n").filter(line => line).map(line => {
                    const tab = line.indexOf("\t");
                    const path = line.slice(tab + 1);
                    const slash = path.lastIndexOf("/");
                    return {
                        path,
                        name: path.slice(slash + 1),
                        dir: slash > 0 ? path.slice(0, slash) : "/",
                        mtime: parseInt(line.slice(0, tab), 10)
                    };
                });
            }
        }

        onExited: code => {
            root.searching = false;
            // 127 is the script's own "fd is missing"
            root.unavailable = code === 127;
        }
    }
}
