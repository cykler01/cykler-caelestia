pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

// The games installed through Steam, for the game library card.
//
// Read from Steam's own files rather than asked of Steam, so it works whether or not the client is
// running: each library folder listed in libraryfolders.vdf holds an appmanifest per installed app, with
// its name and when it was last played, and the client keeps the art it shows in its library cache.
// Nothing here runs unless a card holds a reference (components/misc/Ref.qml): the scan is a single
// short shell pipeline, run when the first card appears and again every so often while one is up.
Singleton {
    id: root

    property int refCount: 0

    // Whether a Steam install was found at all, as opposed to one with nothing installed
    property bool steamFound
    // Set once the first scan is back, so a card can tell "nothing yet" from "nothing there"
    property bool scanned
    // Most recently played first, then by name: { appid, name, lastPlayed (ms, 0 if never),
    // cover (portrait art, or ""), hero (wide art, or "") }
    property list<var> games: []

    // Steam's tools also install as apps with manifests of their own. They are never what someone means
    // by their games, so they are left out by name
    readonly property var toolPattern: /^(Proton\b|Steam Linux Runtime|Steamworks Common|SteamVR Performance Test)|Redistributable/i

    // The scan. Prints FOUND or NONE, for whether Steam is there at all, then one tab-separated line per
    // installed app: appid, name, last played (seconds), portrait art, wide art.
    //
    // Libraries are found from every place Steam may live (native, the ~/.steam links, Flatpak) and
    // resolved, since the same library is usually reachable through more than one of them. The art is
    // looked for both where current clients keep it (librarycache/<appid>/..., sometimes a folder further
    // down) and where older ones did (librarycache/<appid>_library_600x900.jpg)
    readonly property string script: `
            roots=$(for r in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/root" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
                [ -d "$r/steamapps" ] && readlink -f "$r"
            done | sort -u)
            [ -z "$roots" ] && { echo NONE; exit 0; }
            echo FOUND
            IFS=$(printf '\\n\\t')
            libs=$(for r in $roots; do
                printf '%s\\n' "$r"
                sed -n 's/^[[:space:]]*"path"[[:space:]]*"\\(.*\\)"[[:space:]]*$/\\1/p' "$r/steamapps/libraryfolders.vdf" 2>/dev/null
            done | while IFS= read -r l; do
                [ -d "$l/steamapps" ] && readlink -f "$l"
            done | sort -u)
            seen=' '
            for l in $libs; do
                for m in "$l"/steamapps/appmanifest_*.acf; do
                    [ -f "$m" ] || continue
                    id=$(awk -F'"' '$2 == "appid" { print $4; exit }' "$m")
                    case "$seen" in *" $id "*) continue ;; esac
                    seen="$seen$id "
                    name=$(awk -F'"' '$2 == "name" { print $4; exit }' "$m")
                    played=$(awk -F'"' '$2 == "LastPlayed" { print $4; exit }' "$m")
                    cover=''
                    hero=''
                    for r in $roots; do
                        c="$r/appcache/librarycache"
                        [ -z "$cover" ] && [ -f "$c/$id"_library_600x900.jpg ] && cover="$c/$id"_library_600x900.jpg
                        [ -z "$hero" ] && [ -f "$c/$id"_library_hero.jpg ] && hero="$c/$id"_library_hero.jpg
                        [ -d "$c/$id" ] || continue
                        [ -z "$cover" ] && cover=$(find "$c/$id" -maxdepth 2 -name library_600x900.jpg | head -n1)
                        [ -z "$cover" ] && cover=$(find "$c/$id" -maxdepth 2 -name library_capsule.jpg | head -n1)
                        [ -z "$hero" ] && hero=$(find "$c/$id" -maxdepth 2 -name library_hero.jpg | head -n1)
                        [ -z "$hero" ] && hero=$(find "$c/$id" -maxdepth 2 \\( -name header.jpg -o -name library_header.jpg \\) | head -n1)
                    done
                    printf '%s\\t%s\\t%s\\t%s\\t%s\\n' "$id" "$name" "$played" "$cover" "$hero"
                done
            done
    `

    function launch(appid: string): void {
        Quickshell.execDetached(["steam", `steam://rungameid/${appid}`]);
    }

    function rescan(): void {
        scan.running = true;
    }

    // "Today", "Yesterday", "3 days ago" and so on, falling back to the date for anything older than a
    // couple of months
    function lastPlayedText(ms: real): string {
        if (!(ms > 0))
            return Tr.tr("Never played");

        const startOfToday = new Date();
        startOfToday.setHours(0, 0, 0, 0);
        const days = Math.ceil((startOfToday.getTime() - ms) / 86400000);
        if (days <= 0)
            return Tr.tr("Played today");
        if (days === 1)
            return Tr.tr("Played yesterday");
        if (days < 14)
            return Tr.tr("Played %1 days ago").arg(days);
        if (days < 60)
            return Tr.tr("Played %1 weeks ago").arg(Math.floor(days / 7));
        return Tr.tr("Played %1").arg(Qt.formatDate(new Date(ms), "d MMM yyyy"));
    }

    onRefCountChanged: {
        if (refCount > 0 && !scanned && !scan.running)
            rescan();
    }

    // Often enough to pick up a game installed or played since; a scan is a few dozen small files
    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: root.refCount > 0
        onTriggered: root.rescan()
    }

    Process {
        id: scan

        command: ["sh", "-c", root.script]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.steamFound = lines[0]?.trim() === "FOUND";

                const games = [];
                for (const line of lines.slice(1)) {
                    const [appid, name, played, cover, hero] = line.split("\t");
                    if (!appid || !name || root.toolPattern.test(name))
                        continue;
                    games.push({
                        appid: appid,
                        name: name,
                        lastPlayed: (parseInt(played) || 0) * 1000,
                        cover: cover ? `file://${cover}` : "",
                        hero: hero ? `file://${hero}` : ""
                    });
                }
                games.sort((a, b) => b.lastPlayed - a.lastPlayed || a.name.localeCompare(b.name));

                // Reassigning an identical list still rebuilds every delegate on the cards, so only a real
                // change is published
                if (JSON.stringify(games) !== JSON.stringify(root.games))
                    root.games = games;
                root.scanned = true;
            }
        }
    }
}
