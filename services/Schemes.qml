pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n

// NOTE(fork): colour scheme and M3 variant data, moved out of the launcher so the same
// options can be driven from the settings panel. The current scheme, flavour and variant
// are tracked by Colours, which watches the generated scheme file.
Singleton {
    id: root

    property list<var> schemes: []

    readonly property list<var> variants: [
        {
            variant: "vibrant",
            icon: "sentiment_very_dissatisfied",
            name: Tr.trCtx("Vibrant", "M3 scheme variant name"),
            description: Tr.tr("A high chroma palette. The primary palette's chroma is at maximum.")
        },
        {
            variant: "tonalspot",
            icon: "android",
            name: Tr.trCtx("Tonal Spot", "M3 scheme variant name"),
            description: Tr.tr("Default for Material theme colours. A pastel palette with a low chroma.")
        },
        {
            variant: "expressive",
            icon: "compare_arrows",
            name: Tr.trCtx("Expressive", "M3 scheme variant name"),
            description: Tr.tr("A medium chroma palette. The primary palette's hue is different from the seed colour, for variety.")
        },
        {
            variant: "fidelity",
            icon: "compare",
            name: Tr.trCtx("Fidelity", "M3 scheme variant name"),
            description: Tr.tr("Matches the seed colour, even if the seed colour is very bright (high chroma).")
        },
        {
            variant: "content",
            icon: "sentiment_calm",
            name: Tr.trCtx("Content", "M3 scheme variant name"),
            description: Tr.tr("Almost identical to fidelity.")
        },
        {
            variant: "fruitsalad",
            icon: "nutrition",
            name: Tr.trCtx("Fruit Salad", "M3 scheme variant name"),
            description: Tr.tr("A playful theme - the seed colour's hue does not appear in the theme.")
        },
        {
            variant: "rainbow",
            icon: "looks",
            name: Tr.trCtx("Rainbow", "M3 scheme variant name"),
            description: Tr.tr("A playful theme - the seed colour's hue does not appear in the theme.")
        },
        {
            variant: "neutral",
            icon: "contrast",
            name: Tr.trCtx("Neutral", "M3 scheme variant name"),
            description: Tr.tr("Close to greyscale, a hint of chroma.")
        },
        {
            variant: "monochrome",
            icon: "filter_b_and_w",
            name: Tr.trCtx("Monochrome", "M3 scheme variant name"),
            description: Tr.tr("All colours are greyscale, no chroma.")
        }
    ]

    function setScheme(name: string, flavour: string): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "-n", name, "-f", flavour]);
    }

    function setVariant(variant: string): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "-v", variant]);
    }

    Process {
        id: getSchemes

        running: true
        command: ["caelestia", "scheme", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const schemeData = JSON.parse(text);
                const list = Object.entries(schemeData).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
                                name,
                                flavour,
                                colours
                            })));

                const flat = [];
                for (const s of list)
                    for (const f of s)
                        flat.push(f);

                root.schemes = flat.sort((a, b) => String(a.name + a.flavour).localeCompare(String(b.name + b.flavour)));
            }
        }
    }
}
