pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config

// Backs the ">b " launcher state. Whatever is typed ends up in the browser: as a link when it
// looks like one, and as a web search otherwise. The browser is the one picked in Nexus → Apps
// (general.apps.browser), or with none picked whatever the desktop has as its default, through
// xdg-open. Either way one that is already running takes the address as a new tab.
//
// NOTE(fork): it is also where the rest of the shell opens web links, so a link in a
// notification lands in the same browser the launcher uses.
Singleton {
    id: root

    readonly property string defaultScheme: "https://"
    readonly property string searchUrl: "https://www.google.com/search?q="

    // An http(s) link, or a bare host such as example.com/path, 192.168.1.1 or
    // localhost:8080. Anything with a space in it is words rather than an address.
    function isAddress(text: string): bool {
        const trimmed = text.trim();
        if (!trimmed || /\s/.test(trimmed))
            return false;

        return /^https?:\/\//i.test(trimmed) || /^([a-z0-9-]+\.)+[a-z]{2,}(:\d+)?([/?#].*)?$/i.test(trimmed) || /^\d{1,3}(\.\d{1,3}){3}(:\d+)?([/?#].*)?$/.test(trimmed) || /^localhost(:\d+)?([/?#].*)?$/i.test(trimmed);
    }

    // The address to end up at: links are left as they are, a bare host gets https:// in
    // front of it, and everything else becomes a web search so plain words still land
    // somewhere useful instead of failing as a malformed address
    function urlFor(text: string): string {
        const trimmed = text.trim();
        if (!trimmed)
            return "";

        if (!root.isAddress(trimmed))
            return `${root.searchUrl}${encodeURIComponent(trimmed)}`;

        return /^https?:\/\//i.test(trimmed) ? trimmed : `${root.defaultScheme}${trimmed}`;
    }

    // Web links go to the picked browser; anything else (mailto:, file:, ...) and every link
    // when no browser is picked goes to the desktop's own handler
    function open(url: string): void {
        if (!url)
            return;

        const browser = GlobalConfig.general.apps.browser;
        if (browser.length > 0 && /^https?:\/\//i.test(url))
            Quickshell.execDetached([...browser, url]);
        else
            Quickshell.execDetached(["xdg-open", url]);
    }
}
