pragma Singleton

import QtQuick
import Quickshell

// Backs the ">b " launcher state. Whatever is typed ends up in the default browser: as a
// link when it looks like one, and as a web search otherwise. Going through xdg-open means
// the browser is whatever the desktop has as its default, and one that is already running
// takes the address as a new tab.
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

    function open(url: string): void {
        if (!url)
            return;

        Quickshell.execDetached(["xdg-open", url]);
    }
}
