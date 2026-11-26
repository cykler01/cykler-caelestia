pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.services

// NOTE(fork): every kind of thing that can go on the lock screen (Config.lock.elements), what it's
// called, what it looks like by default, and which options it takes. The lock canvas draws from
// this, and the editor builds its "Add" sheet and its options panel from it, so a new kind is one
// entry here plus its delegate in ElementHost.qml
Singleton {
    id: root

    // Shared option lists, reused across the kinds below
    readonly property var colourItems: [
        {
            value: "onSurface",
            label: Tr.tr("Text")
        },
        {
            value: "variant",
            label: Tr.tr("Muted")
        },
        {
            value: "primary",
            label: Tr.tr("Accent")
        },
        {
            value: "secondary",
            label: Tr.tr("Secondary")
        },
        {
            value: "tertiary",
            label: Tr.tr("Tertiary")
        }
    ]
    readonly property var sizeItems: [
        {
            value: "label",
            label: Tr.tr("Small")
        },
        {
            value: "body",
            label: Tr.tr("Body")
        },
        {
            value: "title",
            label: Tr.tr("Title")
        },
        {
            value: "headline",
            label: Tr.tr("Headline")
        },
        {
            value: "display",
            label: Tr.tr("Huge")
        }
    ]
    readonly property var weightItems: [
        {
            value: "regular",
            label: Tr.tr("Regular")
        },
        {
            value: "medium",
            label: Tr.tr("Medium")
        },
        {
            value: "bold",
            label: Tr.tr("Bold")
        }
    ]
    readonly property var alignItems: [
        {
            value: "left",
            label: Tr.tr("Left")
        },
        {
            value: "center",
            label: Tr.tr("Centre")
        },
        {
            value: "right",
            label: Tr.tr("Right")
        }
    ]
    // The options every text-like kind shares
    readonly property var textOptions: [
        {
            key: "size",
            label: Tr.tr("Text size"),
            type: "select",
            items: root.sizeItems
        },
        {
            key: "weight",
            label: Tr.tr("Weight"),
            type: "select",
            items: root.weightItems
        },
        {
            key: "colour",
            label: Tr.tr("Colour"),
            type: "select",
            items: root.colourItems
        },
        {
            key: "align",
            label: Tr.tr("Alignment"),
            type: "select",
            items: root.alignItems
        },
        {
            key: "uppercase",
            label: Tr.tr("Capitals"),
            type: "toggle"
        },
        {
            key: "mono",
            label: Tr.tr("Monospace"),
            type: "toggle"
        },
        {
            key: "spacing",
            label: Tr.tr("Letter spacing"),
            type: "slider",
            from: 0,
            to: 12,
            step: 1
        }
    ]
    readonly property var textDefaults: ({
            size: "title",
            weight: "medium",
            colour: "onSurface",
            align: "left",
            uppercase: false,
            mono: false,
            spacing: 0
        })

    // id: the kind. sized: fills a box (w, h) rather than its natural size. box: the box a new one
    // gets, as fractions of the screen. options: [{ key, label, type: select | toggle | slider |
    // text, items, from, to, step }], with defaults in `defaults`
    readonly property var kinds: [
        {
            id: "password",
            name: Tr.tr("Password field"),
            icon: "password",
            group: "signin",
            description: Tr.tr("Where the password is typed. Every lock screen needs one"),
            options: [
                {
                    key: "width",
                    label: Tr.tr("Width"),
                    type: "slider",
                    from: 220,
                    to: 700,
                    step: 10
                },
                {
                    key: "label",
                    label: Tr.tr("Prompt before it"),
                    type: "text"
                },
                {
                    key: "messages",
                    label: Tr.tr("Show messages under it"),
                    type: "toggle"
                }
            ],
            defaults: {
                width: 340,
                label: "",
                messages: true
            }
        },
        {
            id: "avatar",
            name: Tr.tr("Profile picture"),
            icon: "account_circle",
            group: "signin",
            description: Tr.tr("Your picture, in the shape picked under Profile picture"),
            options: [],
            defaults: {}
        },
        {
            id: "username",
            name: Tr.tr("Username"),
            icon: "badge",
            group: "signin",
            description: Tr.tr("Your name"),
            options: root.textOptions,
            defaults: root.textDefaults
        },
        {
            id: "greeting",
            name: Tr.tr("Greeting"),
            icon: "waving_hand",
            group: "signin",
            description: Tr.tr("Good morning and the like, as set under Greeting"),
            options: [],
            defaults: {}
        },
        {
            id: "clock",
            name: Tr.tr("Clock"),
            icon: "schedule",
            group: "time",
            description: Tr.tr("The time, drawn one of several ways"),
            options: [
                {
                    key: "face",
                    label: Tr.tr("Face"),
                    type: "select",
                    items: [
                        {
                            value: "line",
                            label: Tr.tr("One line")
                        },
                        {
                            value: "stacked",
                            label: Tr.tr("Stacked")
                        },
                        {
                            value: "classic",
                            label: Tr.tr("Classic")
                        },
                        {
                            value: "analogue",
                            label: Tr.tr("Analogue")
                        },
                        {
                            value: "words",
                            label: Tr.tr("Words")
                        },
                        {
                            value: "flip",
                            label: Tr.tr("Flip cards")
                        },
                        {
                            value: "dots",
                            label: Tr.tr("LED dots")
                        }
                    ]
                },
                {
                    key: "accent",
                    label: Tr.tr("Accent colour"),
                    type: "toggle"
                },
                {
                    key: "align",
                    label: Tr.tr("Alignment"),
                    type: "select",
                    items: root.alignItems
                }
            ],
            defaults: {
                face: "line",
                accent: true,
                align: "center"
            }
        },
        {
            id: "date",
            name: Tr.tr("Date or time"),
            icon: "calendar_today",
            group: "time",
            description: Tr.tr("The date or time as text, in the format you choose"),
            options: [
                {
                    key: "format",
                    label: Tr.tr("Format"),
                    type: "select",
                    items: [
                        {
                            value: "dddd, d MMMM",
                            label: Tr.tr("Thursday, 26 November")
                        },
                        {
                            value: "ddd d MMM",
                            label: Tr.tr("Thu 26 Nov")
                        },
                        {
                            value: "dddd",
                            label: Tr.tr("Thursday")
                        },
                        {
                            value: "d MMMM yyyy",
                            label: Tr.tr("26 November 2026")
                        },
                        {
                            value: "MMMM yyyy",
                            label: Tr.tr("November 2026")
                        },
                        {
                            value: "d",
                            label: Tr.tr("26")
                        },
                        {
                            value: "time",
                            label: Tr.tr("Time (18:30)")
                        },
                        {
                            value: "dddd • d MMM",
                            label: Tr.tr("Thursday • 26 Nov")
                        }
                    ]
                },
                {
                    key: "pattern",
                    label: Tr.tr("Custom format"),
                    type: "text"
                },
                ...root.textOptions
            ],
            defaults: Object.assign({}, root.textDefaults, {
                format: "dddd, d MMMM",
                pattern: ""
            })
        },
        {
            id: "text",
            name: Tr.tr("Text"),
            icon: "text_fields",
            group: "decoration",
            description: Tr.tr("Any words you like"),
            options: [
                {
                    key: "text",
                    label: Tr.tr("Text"),
                    type: "text"
                },
                ...root.textOptions
            ],
            defaults: Object.assign({}, root.textDefaults, {
                text: Tr.tr("Welcome back"),
                colour: "variant"
            })
        },
        {
            id: "weather",
            name: Tr.tr("Weather"),
            icon: "partly_cloudy_day",
            group: "info",
            description: Tr.tr("The current conditions"),
            options: [
                {
                    key: "style",
                    label: Tr.tr("Style"),
                    type: "select",
                    items: [
                        {
                            value: "pill",
                            label: Tr.tr("Detailed")
                        },
                        {
                            value: "compact",
                            label: Tr.tr("Compact")
                        },
                        {
                            value: "large",
                            label: Tr.tr("Large")
                        }
                    ]
                }
            ],
            defaults: {
                style: "pill"
            }
        },
        {
            id: "status",
            name: Tr.tr("Status pills"),
            icon: "battery_horiz_075",
            group: "info",
            description: Tr.tr("Battery, network and the rest, picked under Status pills"),
            options: [
                {
                    key: "direction",
                    label: Tr.tr("First pill on the"),
                    type: "select",
                    items: [
                        {
                            value: "right",
                            label: Tr.tr("Right")
                        },
                        {
                            value: "left",
                            label: Tr.tr("Left")
                        }
                    ]
                }
            ],
            defaults: {
                direction: "right"
            }
        },
        {
            id: "chips",
            name: Tr.tr("Info chips"),
            icon: "view_agenda",
            group: "info",
            description: Tr.tr("The date, weather and battery as small chips, like a watch face"),
            options: [
                {
                    key: "date",
                    label: Tr.tr("Date"),
                    type: "toggle"
                },
                {
                    key: "weather",
                    label: Tr.tr("Weather"),
                    type: "toggle"
                },
                {
                    key: "battery",
                    label: Tr.tr("Battery"),
                    type: "toggle"
                }
            ],
            defaults: {
                date: true,
                weather: true,
                battery: true
            }
        },
        {
            id: "stat",
            name: Tr.tr("Reading"),
            icon: "monitoring",
            group: "info",
            description: Tr.tr("One reading with an icon over it, for a tile"),
            options: [
                {
                    key: "metric",
                    label: Tr.tr("Shows"),
                    type: "select",
                    items: [
                        {
                            value: "battery",
                            label: Tr.tr("Battery")
                        },
                        {
                            value: "weather",
                            label: Tr.tr("Weather")
                        },
                        {
                            value: "uptime",
                            label: Tr.tr("Uptime")
                        },
                        {
                            value: "day",
                            label: Tr.tr("Day of the year")
                        }
                    ]
                }
            ],
            defaults: {
                metric: "battery"
            }
        },
        {
            id: "media",
            name: Tr.tr("Now playing"),
            icon: "music_note",
            group: "info",
            description: Tr.tr("What's playing, with its cover"),
            options: [
                {
                    key: "art",
                    label: Tr.tr("Cover art"),
                    type: "toggle"
                },
                {
                    key: "controls",
                    label: Tr.tr("Play controls"),
                    type: "toggle"
                }
            ],
            defaults: {
                art: true,
                controls: true
            }
        },
        {
            id: "calendar",
            name: Tr.tr("Calendar"),
            icon: "calendar_month",
            group: "time",
            description: Tr.tr("This month, with today picked out"),
            options: [],
            defaults: {}
        },
        {
            id: "terminal",
            name: Tr.tr("System info"),
            icon: "terminal",
            group: "info",
            description: Tr.tr("A console-style readout of the system"),
            options: [
                {
                    key: "banner",
                    label: Tr.tr("Login banner"),
                    type: "toggle"
                },
                {
                    key: "facts",
                    label: Tr.tr("System details"),
                    type: "toggle"
                },
                {
                    key: "date",
                    label: Tr.tr("Date at a prompt"),
                    type: "toggle"
                }
            ],
            defaults: {
                banner: true,
                facts: true,
                date: true
            }
        },
        {
            id: "widgets",
            name: Tr.tr("Widget column"),
            icon: "widgets",
            group: "info",
            sized: true,
            box: [0.2, 0.6],
            description: Tr.tr("The lock screen widgets, as set under Widgets"),
            options: [
                {
                    key: "column",
                    label: Tr.tr("Which widgets"),
                    type: "select",
                    items: [
                        {
                            value: "left",
                            label: Tr.tr("Left column")
                        },
                        {
                            value: "right",
                            label: Tr.tr("Right column")
                        },
                        {
                            value: "all",
                            label: Tr.tr("All of them")
                        }
                    ]
                }
            ],
            defaults: {
                column: "left"
            }
        },
        {
            id: "session",
            name: Tr.tr("Session buttons"),
            icon: "power_settings_new",
            group: "signin",
            description: Tr.tr("Log out, shut down, sleep and restart. Shown when Session controls is on"),
            options: [],
            defaults: {}
        },
        {
            id: "panel",
            name: Tr.tr("Panel"),
            icon: "rectangle",
            group: "decoration",
            sized: true,
            box: [0.3, 0.4],
            description: Tr.tr("A card behind other elements"),
            options: [
                {
                    key: "colour",
                    label: Tr.tr("Fill"),
                    type: "select",
                    items: [
                        {
                            value: "surface",
                            label: Tr.tr("Surface")
                        },
                        {
                            value: "container",
                            label: Tr.tr("Container")
                        },
                        {
                            value: "high",
                            label: Tr.tr("Raised")
                        },
                        {
                            value: "primary",
                            label: Tr.tr("Accent")
                        },
                        {
                            value: "gradient",
                            label: Tr.tr("Gradient")
                        },
                        {
                            value: "none",
                            label: Tr.tr("None")
                        }
                    ]
                },
                {
                    key: "radius",
                    label: Tr.tr("Corner rounding"),
                    type: "slider",
                    from: 0,
                    to: 80,
                    step: 2
                },
                {
                    key: "shadow",
                    label: Tr.tr("Shadow"),
                    type: "toggle"
                },
                {
                    key: "border",
                    label: Tr.tr("Outline"),
                    type: "toggle"
                },
                {
                    key: "edges",
                    label: Tr.tr("Accent lines top and bottom"),
                    type: "toggle"
                },
                {
                    key: "titleBar",
                    label: Tr.tr("Window title bar"),
                    type: "toggle"
                }
            ],
            defaults: {
                colour: "surface",
                radius: 36,
                shadow: true,
                border: false,
                edges: false,
                titleBar: false
            }
        },
        {
            id: "divider",
            name: Tr.tr("Divider"),
            icon: "horizontal_rule",
            group: "decoration",
            sized: true,
            box: [0.2, 0.003],
            description: Tr.tr("A thin line. Make it taller than wide to stand it upright"),
            options: [
                {
                    key: "colour",
                    label: Tr.tr("Colour"),
                    type: "select",
                    items: root.colourItems
                }
            ],
            defaults: {
                colour: "variant"
            }
        }
    ]

    readonly property var groups: [
        {
            id: "signin",
            name: Tr.tr("Signing in")
        },
        {
            id: "time",
            name: Tr.tr("Time and date")
        },
        {
            id: "info",
            name: Tr.tr("Information")
        },
        {
            id: "decoration",
            name: Tr.tr("Decoration")
        }
    ]

    function kind(id: string): var {
        return root.kinds.find(k => k.id === id) ?? null;
    }

    function isSized(id: string): bool {
        return root.kind(id)?.sized ?? false;
    }

    // An element's options with its kind's defaults under them, so every option reads a value
    function optionsFor(id: string, saved: var): var {
        return Object.assign({}, root.kind(id)?.defaults ?? {}, saved ?? {});
    }

    // A fresh element of a kind, placed in the middle of the screen
    function create(id: string): var {
        const k = root.kind(id);
        return {
            id: id,
            enabled: true,
            x: 0.5,
            y: 0.5,
            anchor: "c",
            w: k?.box?.[0] ?? 0,
            h: k?.box?.[1] ?? 0,
            scale: 1,
            opacity: 1,
            rotation: 0,
            showOn: "always",
            options: {}
        };
    }

    function colour(name: string): color {
        switch (name) {
        case "variant":
            return Colours.palette.m3onSurfaceVariant;
        case "primary":
            return Colours.palette.m3primary;
        case "secondary":
            return Colours.palette.m3secondary;
        case "tertiary":
            return Colours.palette.m3tertiary;
        default:
            return Colours.palette.m3onSurface;
        }
    }
}
