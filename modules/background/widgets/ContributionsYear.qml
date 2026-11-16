pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.I18n
import qs.services
import qs.utils

// A whole year of one GitHub calendar, for the card's year and streak variants.
//
// services/WidgetData.qml keeps only the last thirty days, which is all the other variants draw, so the
// variants that need the year ask the same API for it here. The card is unloaded whenever windows cover
// the desktop, so the reply is kept in a file under the cache directory and a card coming back draws from
// that straight away, only going back to the network once what it has is older than WidgetData's own limit.
Item {
    id: root

    property string user
    // Only a valid name is ever put into the URL
    readonly property bool userValid: WidgetData.validGithubUser(root.user)

    readonly property string cachePath: `${Paths.cache}/github-year.json`
    readonly property int ttl: WidgetData.githubTtl

    // { date, count, level } for every day of the last year, oldest first and ending today
    property var days: []
    property string error
    property double fetched: 0

    function refresh(force: bool): void {
        if (!root.userValid)
            return;
        if (!force && root.days.length > 0 && Date.now() - root.fetched < root.ttl)
            return;
        if (fetch.running && fetch.user === root.user)
            return;

        fetch.running = false;
        fetch.user = root.user;
        fetch.command = ["sh", "-c", `curl -fsSL --max-time 20 "https://github-contributions-api.jogruber.de/v4/${root.user}?y=last"`];
        fetch.running = true;
    }

    // The API's days into the card's, dropping anything after today: the reply can run on to the end of the
    // current week, and a square for a day that hasn't happened would only ever read as an empty one
    function adopt(list: var): void {
        const now = new Date();
        const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
        root.days = list.filter(d => d && typeof d.date === "string" && d.date <= today).sort((a, b) => a.date < b.date ? -1 : a.date > b.date ? 1 : 0).map(d => ({
                    date: d.date,
                    count: Number(d.count) || 0,
                    level: Number(d.level) || 0
                }));
    }

    function parse(name: string, json: string): void {
        if (json.trim() === "")
            return;

        let data;
        try {
            data = JSON.parse(json);
        } catch (e) {
            root.error = Tr.tr("Could not read the contributions data");
            return;
        }

        const list = Array.isArray(data?.contributions) ? data.contributions : [];
        if (list.length === 0) {
            root.error = Tr.tr("No contributions came back for this name");
            return;
        }

        // A reply for a name that has since been changed is not this card's any more
        if (name !== root.user)
            return;

        root.error = "";
        root.fetched = Date.now();
        root.adopt(list);
        store.setText(JSON.stringify({
            user: name,
            fetched: root.fetched,
            contributions: root.days
        }));
    }

    onUserChanged: {
        root.days = [];
        root.error = "";
        store.reload();
    }

    FileView {
        id: store

        path: root.cachePath
        printErrors: false

        onLoaded: {
            let saved = null;
            try {
                saved = JSON.parse(text());
            } catch (e) {}

            if (saved?.user === root.user && Array.isArray(saved.contributions)) {
                root.fetched = Number(saved.fetched) || 0;
                root.adopt(saved.contributions);
            }
            root.refresh(false);
        }
        // Nothing cached yet is the normal first run
        onLoadFailed: root.refresh(false)
    }

    Process {
        id: fetch

        property string user

        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: root.parse(fetch.user, text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const complaint = text.trim();
                if (complaint !== "")
                    root.error = complaint;
            }
        }
    }
}
