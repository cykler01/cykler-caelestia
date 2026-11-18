import QtQuick
import QtQuick.Shapes
import "SymbolPaths.js" as Symbols

// the shell's lock glyphs for a greeter: the same names for the same material
// symbols, drawn from the table build-icons.py writes beside this file
Item {
    id: glyph

    readonly property var symbols: ({
        "lock": "lock",
        "lockOpen": "lock_open",
        "key": "key",
        "arrow": "arrow_forward",
        "finger": "fingerprint",
        "check": "check",
        "eye": "visibility",
        "eyeOff": "visibility_off",
        "caps": "keyboard_capslock",
        "power": "power_settings_new",
        "restart": "restart_alt",
        "suspend": "bedtime",
        "hibernate": "ac_unit",
        "back": "arrow_back",
        "expand": "expand_more",
        "person": "person",
        "personAdd": "person_add",
        "session": "desktop_windows",
        "host": "computer",
        "keyboard": "keyboard",
        "wifi": "signal_wifi_4_bar",
        // the arcs rather than the wedge: they fill from the dot up, so a
        // clipped copy of them reads as the strength of the link
        "signal": "wifi",
        "wifiOff": "signal_wifi_off",
        "ethernet": "lan",
        "batteryCharge": "battery_charging_full"
    })
    property string name: "lock"
    property color color: Theme.text
    property real size: Theme.dp(20)
    readonly property real drawn: Math.round(glyph.size * 1.1)

    implicitWidth: Math.round(glyph.size)
    implicitHeight: Math.round(glyph.size)

    Shape {
        x: (glyph.width - glyph.drawn) / 2
        y: (glyph.height - glyph.drawn) / 2
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            fillColor: glyph.color

            PathSvg {
                path: Symbols.p[glyph.symbols[glyph.name] || glyph.name] || ""
            }

        }

        transform: Scale {
            xScale: glyph.drawn / 24
            yScale: glyph.drawn / 24
        }

    }

}
