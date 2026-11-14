pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The installer's own theme. The shell's Colours service is not available here:
// it lives in Caelestia.Config, a C++ module that only exists once the build has
// run, and the installer's whole job is to run that build. So the tokens are read
// straight off a scheme file instead -- the one the desktop is wearing when there
// is one, and caelestia's own default when there is not.
Singleton {
    id: root

    // "dark" or "light" from the button; "" follows whatever was loaded
    property string mode: ""
    readonly property bool isLight: root.mode !== "" ? root.mode === "light" : root._loadedLight
    property bool _loadedLight: false

    // the live scheme, so a reinstall opens in the colours you already have
    readonly property string livePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/caelestia/scheme.json"
    readonly property string shippedPath: Qt.resolvedUrl("scheme-" + (root.isLight ? "light" : "dark") + ".json").toString().replace("file://", "")

    property var m: ({})

    // -- M3 tokens, named the way the installer reads them ------------------

    readonly property color bg: root.hex("surface", root.isLight ? "fdfbfb" : "0a0f0f")
    readonly property color bgSunken: root.hex("surfaceContainerLowest", root.isLight ? "ffffff" : "000000")
    readonly property color bgTile: root.hex("surfaceContainer", root.isLight ? "f1eeee" : "131b1a")
    readonly property color bgHigh: root.hex("surfaceContainerHigh", root.isLight ? "ebe8e8" : "192120")
    readonly property color text: root.hex("onSurface", root.isLight ? "1a1c1c" : "dce8e6")
    readonly property color subtext: root.hex("onSurfaceVariant", root.isLight ? "4a5553" : "a2adac")
    readonly property color subtextDim: root.hex("outline", root.isLight ? "6d7876" : "6d7876")
    readonly property color outline: root.hex("outlineVariant", root.isLight ? "cbd6d4" : "3f4a49")
    readonly property color accent: root.hex("primary", root.isLight ? "1a6764" : "9bd0cc")
    readonly property color onAccent: root.hex("onPrimary", root.isLight ? "ffffff" : "0d4845")
    readonly property color error: root.hex("error", root.isLight ? "ba1a1a" : "ffb4ab")
    readonly property color success: root.hex("tertiary", root.isLight ? "3c6472" : "d5efff")

    // -- type and metrics ---------------------------------------------------

    readonly property string fontFamily: "Google Sans Flex"
    readonly property string fontMono: "CaskaydiaCove NF"
    readonly property real scale: 1
    readonly property int fontBodySm: root.dp(12)
    readonly property int fontBodyMd: root.dp(14)
    readonly property int fontBodyLg: root.dp(16)
    readonly property int fontTitleLg: root.dp(20)
    readonly property int fontHeadlineLg: root.dp(28)
    readonly property int shapeXl: root.dp(28)

    readonly property int durShort: 150
    readonly property int durLong: 400
    readonly property int easeStandard: Easing.OutCubic

    function dp(v: real): int {
        return Math.round(v * root.scale);
    }

    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Google Sans Flex is variable: weight and roundness per size, the way the
    // shell sets them, so the installer is not visibly a different typeface
    function axes(size: int, weight: int, round: int): var {
        return {
            "wght": weight,
            "ROND": round
        };
    }

    function hex(key: string, fallback: string): color {
        const v = root.m[key];
        return "#" + (v && v.length >= 6 ? v : fallback);
    }

    function load(text: string): bool {
        try {
            const j = JSON.parse(text);
            if (!j.colours || !j.colours.surface)
                return false;
            root.m = j.colours;
            root._loadedLight = j.mode === "light";
            return true;
        } catch (e) {
            return false;
        }
    }

    // the live scheme first; its absence is ordinary, so failure is quiet
    FileView {
        id: live

        path: root.mode === "" ? root.livePath : ""
        onLoaded: {
            if (!root.load(this.text()))
                shipped.reload();
        }
        onLoadFailed: shipped.reload()
    }

    FileView {
        id: shipped

        path: root.shippedPath
        onLoaded: root.load(this.text())
    }

    // switching mode by hand leaves the live scheme behind for the shipped one,
    // which has both halves
    onModeChanged: {
        if (root.mode !== "")
            shipped.reload();
    }
}
