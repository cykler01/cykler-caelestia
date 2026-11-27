pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n

// NOTE(fork): ready-made lock screens, each a list of elements (Config.lock.elements) laid out the
// way one of the old fixed layouts was, or a new arrangement. The editor starts from one of these
// and everything in it can then be moved, resized, restyled, added to or taken away.
//
// Also where the screen's elements come from before the layout has ever been edited: the list is
// empty then, and the preset named by the old layout setting stands in for it, so a config from
// before the editor opens on the look it had
Singleton {
    id: root

    // Positions are fractions of the screen; these are the 72px margins the layouts used, on 1080p
    readonly property real mx: 0.0375
    readonly property real my: 0.0667

    // The presets in the order the editor shows them, with what they're after
    readonly property var list: [
        {
            id: "classic",
            name: Tr.tr("Classic"),
            note: Tr.tr("The centre card with widgets either side")
        },
        {
            id: "split",
            name: Tr.tr("Split"),
            note: Tr.tr("Clock on one side, login and widgets on the other")
        },
        {
            id: "sidebar",
            name: Tr.tr("Sidebar"),
            note: Tr.tr("Everything in one panel along the edge")
        },
        {
            id: "minimal",
            name: Tr.tr("Minimal"),
            note: Tr.tr("A big clock and the login")
        },
        {
            id: "stage",
            name: Tr.tr("Stage"),
            note: Tr.tr("Clock at the top, login at the bottom, after macOS")
        },
        {
            id: "curtain",
            name: Tr.tr("Curtain"),
            note: Tr.tr("A clock in the corner that lifts on a key, after Windows")
        },
        {
            id: "watch",
            name: Tr.tr("Watch face"),
            note: Tr.tr("An analogue dial with complications")
        },
        {
            id: "band",
            name: Tr.tr("Band"),
            note: Tr.tr("One strip across the middle, after LightDM")
        },
        {
            id: "console",
            name: Tr.tr("Console"),
            note: Tr.tr("A terminal window and a password prompt")
        },
        {
            id: "fuzzy",
            name: Tr.tr("Fuzzy clock"),
            note: Tr.tr("The time in words, after KDE")
        },
        {
            id: "glance",
            name: Tr.tr("Glance"),
            note: Tr.tr("A stacked clock and an at-a-glance corner, after Android")
        },
        {
            id: "shelf",
            name: Tr.tr("Shelf"),
            note: Tr.tr("A user pod and a taskbar, after ChromeOS")
        },
        {
            id: "profile",
            name: Tr.tr("Profile card"),
            note: Tr.tr("A card with a banner, after elementary OS")
        },
        {
            id: "vertical",
            name: Tr.tr("Vertical"),
            note: Tr.tr("The clock on its side up the left edge")
        },
        {
            id: "bento",
            name: Tr.tr("Bento"),
            note: Tr.tr("A grid of tiles, after widget boards")
        },
        {
            id: "flip",
            name: Tr.tr("Flip clock"),
            note: Tr.tr("Split-flap cards, after Fliqlo")
        },
        {
            id: "dotmatrix",
            name: Tr.tr("Dot matrix"),
            note: Tr.tr("LED dots, after Nothing OS")
        },
        {
            id: "agenda",
            name: Tr.tr("Agenda"),
            note: Tr.tr("The clock beside this month's calendar")
        },
        {
            id: "nowplaying",
            name: Tr.tr("Now playing"),
            note: Tr.tr("What's playing, front and centre, over an equalizer")
        },
        {
            id: "poster",
            name: Tr.tr("Poster"),
            note: Tr.tr("The day in huge type")
        },
        {
            id: "compact",
            name: Tr.tr("Compact card"),
            note: Tr.tr("Everything on one small card")
        },
        {
            id: "board",
            name: Tr.tr("Widget board"),
            note: Tr.tr("The clock beside a block of desktop widgets")
        },
        {
            id: "giant",
            name: Tr.tr("Giant"),
            note: Tr.tr("The time as big as it goes, along the bottom")
        },
        {
            id: "aurora",
            name: Tr.tr("Aurora"),
            note: Tr.tr("A gradient strip with the clock, the login beside it")
        },
        {
            id: "studio",
            name: Tr.tr("Studio"),
            note: Tr.tr("An analogue dial beside the day in big type")
        },
        {
            id: "magazine",
            name: Tr.tr("Magazine"),
            note: Tr.tr("The date set like a magazine cover")
        },
        {
            id: "menubar",
            name: Tr.tr("Menu bar"),
            note: Tr.tr("A thin bar across the top over a centred login")
        },
        {
            id: "mission",
            name: Tr.tr("Mission control"),
            note: Tr.tr("A wall of desktop widgets under the clock")
        },
        {
            id: "tty",
            name: Tr.tr("TTY"),
            note: Tr.tr("Plain text on the bare screen, like a text console")
        },
        {
            id: "tilted",
            name: Tr.tr("Tilted"),
            note: Tr.tr("The clock and date set at an angle")
        },
        {
            id: "island",
            name: Tr.tr("Island"),
            note: Tr.tr("Everything you need in one pill along the bottom")
        },
        {
            id: "gauges",
            name: Tr.tr("Gauges"),
            note: Tr.tr("The clock over a row of readings")
        },
        {
            id: "calendarwall",
            name: Tr.tr("Calendar wall"),
            note: Tr.tr("The month, large, beside the clock")
        },
        {
            id: "halves",
            name: Tr.tr("Halves"),
            note: Tr.tr("The screen split in two, the time on one side")
        },
        {
            id: "pulse",
            name: Tr.tr("Pulse"),
            note: Tr.tr("Split-flap clock over a full-width equalizer")
        },
        {
            id: "spectrum",
            name: Tr.tr("Spectrum"),
            note: Tr.tr("Waves of sound from the top and bottom around LED dots")
        },
        {
            id: "skyline",
            name: Tr.tr("Skyline"),
            note: Tr.tr("A huge clock standing on a skyline of bars")
        },
        {
            id: "blank",
            name: Tr.tr("Blank"),
            note: Tr.tr("Only the password field, to build from scratch")
        }
    ]

    // One element, with everything not given left at its default
    function e(id: string, x: real, y: real, anchor: string, extra: var): var {
        return Object.assign({
            id: id,
            enabled: true,
            x: x,
            y: y,
            anchor: anchor,
            w: 0,
            h: 0,
            scale: 1,
            opacity: 1,
            rotation: 0,
            showOn: "always",
            options: {}
        }, extra ?? {});
    }

    // The three things most presets keep in the corners
    function corners(): var {
        return [root.e("weather", root.mx, root.my, "tl", {
                scale: 0.9
            }), root.e("status", 1 - root.mx, root.my, "tr", {
                scale: 0.9
            }), root.e("session", 1 - root.mx, 1 - root.my, "br")];
    }

    // A small avatar with the name over the password field beside it, starting at x
    function inlineLogin(x: real, y: real, width: real): var {
        return [root.e("avatar", x, y, "l", {
                scale: 0.47
            }), root.e("username", x + 0.035, y - 0.008, "bl", {
                options: {
                    size: "title",
                    weight: "medium"
                }
            }), root.e("password", x + 0.035, y + 0.002, "tl", {
                options: {
                    width: width ?? 300
                }
            })];
    }

    function build(id: string): var {
        const e = root.e;
        switch (id) {
        case "classic":
            return [e("panel", 0.5, 0.5, "c", {
                    w: 0.7,
                    h: 0.7,
                    options: {
                        colour: "surface",
                        radius: 42
                    }
                }), e("widgets", 0.1625, 0.172, "tl", {
                    w: 0.2,
                    h: 0.655,
                    options: {
                        widgets: ["weather", "fetch", "media"]
                    }
                }), e("widgets", 0.8375, 0.172, "tr", {
                    w: 0.2,
                    h: 0.655,
                    options: {
                        widgets: ["resources", "battery", "notifs"]
                    }
                }), e("clock", 0.5, 0.2, "t", {
                    options: {
                        face: GlobalConfig.lock.analogueClock ? "analogue" : "classic"
                    },
                    scale: GlobalConfig.lock.analogueClock ? 0.45 : 1
                }), e("date", 0.5, 0.39, "t", {
                    options: {
                        format: "dddd • d MMM",
                        uppercase: true,
                        size: "title",
                        weight: "bold"
                    }
                }), e("avatar", 0.5, 0.45, "t", {
                    scale: 1.3
                }), e("greeting", 0.5, 0.62, "t"), e("password", 0.5, 0.68, "t", {
                    options: {
                        width: 360
                    }
                })];
        case "split":
            return [e("weather", root.mx, root.my, "tl"), e("status", 1 - root.mx, root.my, "tr"), e("session", root.mx, 1 - root.my, "bl"), e("clock", root.mx, 0.47, "bl", {
                    scale: 0.85,
                    options: {
                        face: "stacked",
                        align: "left"
                    }
                }), e("date", root.mx, 0.5, "tl", {
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("greeting", root.mx, 0.56, "tl"), e("panel", 1 - root.mx, 0.15, "tr", {
                    w: 0.208,
                    h: 0.32,
                    options: {
                        colour: "container",
                        radius: 42,
                        shadow: false
                    }
                }), e("avatar", 0.858, 0.18, "t"), e("username", 0.858, 0.33, "t", {
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("password", 0.858, 0.38, "t", {
                    options: {
                        width: 340
                    }
                }), e("widgets", 1 - root.mx, 0.49, "tr", {
                    w: 0.208,
                    h: 0.44,
                    options: {
                        widgets: ["resources", "battery", "notifs"]
                    }
                }), e("widgets", 0.742, 0.15, "tr", {
                    w: 0.208,
                    h: 0.78,
                    options: {
                        widgets: ["weather", "fetch", "media"]
                    }
                })];
        case "sidebar":
            return [e("status", root.mx, root.my, "tl", {
                    options: {
                        direction: "left"
                    }
                }), e("weather", root.mx, 1 - root.my, "bl"), e("panel", 0.985, 0.026, "tr", {
                    w: 0.24,
                    h: 0.948,
                    options: {
                        colour: "surface",
                        radius: 54
                    }
                }), e("clock", 0.762, 0.06, "tl", {
                    scale: 0.4
                }), e("date", 0.762, 0.16, "tl", {
                    options: {
                        size: "title",
                        colour: "variant",
                        weight: "bold"
                    }
                }), e("widgets", 0.762, 0.22, "tl", {
                    w: 0.208,
                    h: 0.5,
                    options: {
                        widgets: ["weather", "fetch", "media", "resources", "battery", "notifs"]
                    }
                }), e("divider", 0.762, 0.76, "tl", {
                    w: 0.208,
                    h: 0.002
                }), ...root.inlineLogin(0.765, 0.82, 290), e("session", 0.865, 0.925, "c", {
                    scale: 0.9
                })];
        case "minimal":
            return [...root.corners(), e("clock", 0.5, 0.46, "b"), e("date", 0.5, 0.48, "t", {
                    scale: 1.2,
                    options: {
                        size: "title",
                        weight: "bold",
                        align: "center"
                    }
                }), e("avatar", 0.5, 0.58, "t", {
                    scale: 0.65
                }), e("greeting", 0.5, 0.67, "t"), e("password", 0.5, 0.73, "t")];
        case "stage":
            return [...root.corners().slice(0, 2), e("date", 0.5, 0.09, "t", {
                    scale: 1.15,
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("clock", 0.5, 0.15, "t", {
                    scale: 0.85
                }), e("avatar", 0.5, 0.66, "t", {
                    scale: 0.58
                }), e("username", 0.5, 0.74, "t", {
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("password", 0.5, 0.79, "t"), e("session", 0.5, 0.88, "t", {
                    scale: 0.85
                })];
        case "curtain":
            return [e("clock", root.mx, 0.7, "bl", {
                    scale: 0.92,
                    showOn: "rest"
                }), e("date", root.mx, 0.72, "tl", {
                    scale: 1.25,
                    showOn: "rest",
                    options: {
                        weight: "bold"
                    }
                }), e("weather", root.mx, 0.79, "tl", {
                    scale: 0.9,
                    showOn: "rest"
                }), e("status", 1 - root.mx, 1 - root.my, "br", {
                    scale: 0.9
                }), e("text", 0.5, 1 - root.my, "b", {
                    showOn: "rest",
                    options: {
                        text: Tr.tr("Press any key or click to unlock"),
                        size: "label",
                        colour: "variant",
                        weight: "regular"
                    }
                }), e("avatar", 0.5, 0.42, "b", {
                    scale: 1.18,
                    showOn: "active"
                }), e("greeting", 0.5, 0.45, "t", {
                    showOn: "active"
                }), e("password", 0.5, 0.52, "t", {
                    showOn: "active",
                    options: {
                        width: 380
                    }
                }), e("session", 0.5, 0.62, "t", {
                    scale: 0.85,
                    showOn: "active"
                })];
        case "watch":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("session", 1 - root.mx, 1 - root.my, "br"), e("clock", 0.5, 0.39, "c", {
                    options: {
                        face: "analogue"
                    }
                }), e("chips", 0.5, 0.62, "t"), ...root.inlineLogin(0.405, 0.72, 300)];
        case "band":
            return [e("status", 1 - root.mx, root.my, "tr"), e("session", 1 - root.mx, 1 - root.my, "br"), e("panel", 0, 0.5, "l", {
                    w: 1,
                    h: 0.26,
                    options: {
                        colour: "surface",
                        radius: 0,
                        edges: true
                    }
                }), e("clock", 0.05, 0.5, "l", {
                    scale: 0.55
                }), e("divider", 0.28, 0.5, "c", {
                    w: 0.0012,
                    h: 0.13
                }), e("date", 0.3, 0.49, "bl", {
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("greeting", 0.3, 0.5, "tl"), e("weather", 0.3, 0.555, "tl", {
                    scale: 0.8
                }), ...root.inlineLogin(0.73, 0.5, 380)];
        case "console":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("panel", 0.5, 0.5, "c", {
                    w: 0.45,
                    h: 0.45,
                    options: {
                        colour: "surface",
                        radius: 20,
                        border: true,
                        titleBar: true
                    }
                }), e("terminal", 0.293, 0.35, "tl"), e("password", 0.293, 0.63, "tl", {
                    options: {
                        width: 560,
                        label: Tr.tr("Password:")
                    }
                }), e("session", 0.5, 0.77, "t", {
                    scale: 0.9
                })];
        case "fuzzy":
            return [...root.corners(), e("clock", 0.05, 0.4, "l", {
                    options: {
                        face: "words",
                        align: "left"
                    }
                }), e("date", 0.05, 0.52, "tl", {
                    scale: 1.2,
                    options: {
                        pattern: "hh:mm  ·  dddd, d MMMM",
                        size: "title",
                        weight: "bold"
                    }
                }), ...root.inlineLogin(0.05, 0.88, 300)];
        case "glance":
            return [e("date", root.mx, root.my, "tl", {
                    options: {
                        format: "dddd, d MMMM",
                        size: "headline",
                        weight: "medium"
                    }
                }), e("weather", root.mx, 0.14, "tl", {
                    options: {
                        style: "compact"
                    }
                }), e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("session", 1 - root.mx, 1 - root.my, "br"), e("clock", 0.5, 0.44, "c", {
                    options: {
                        face: "stacked"
                    }
                }), ...root.inlineLogin(0.41, 0.88, 300)];
        case "shelf":
            return [e("avatar", 0.5, 0.42, "b", {
                    scale: 1.1
                }), e("username", 0.5, 0.44, "t", {
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("password", 0.5, 0.5, "t"), e("panel", 0.5, 1, "b", {
                    w: 1,
                    h: 0.075,
                    options: {
                        colour: "surface",
                        radius: 0,
                        shadow: false
                    }
                }), e("session", 0.008, 0.9625, "l", {
                    scale: 0.8
                }), e("status", 0.86, 0.9625, "r", {
                    scale: 0.85
                }), e("date", 0.92, 0.9625, "r", {
                    options: {
                        format: "ddd d MMM",
                        size: "label",
                        colour: "variant"
                    }
                }), e("date", 0.985, 0.9625, "r", {
                    options: {
                        format: "time",
                        size: "title",
                        weight: "bold"
                    }
                })];
        case "profile":
            return [...root.corners(), e("clock", 0.492, 0.27, "r", {
                    scale: 0.4
                }), e("divider", 0.5, 0.27, "c", {
                    w: 0.0008,
                    h: 0.07
                }), e("date", 0.508, 0.27, "bl", {
                    options: {
                        format: "dddd",
                        size: "title"
                    }
                }), e("date", 0.508, 0.27, "tl", {
                    options: {
                        format: "d MMMM",
                        size: "title"
                    }
                }), e("panel", 0.5, 0.34, "t", {
                    w: 0.22,
                    h: 0.42,
                    options: {
                        colour: "container",
                        radius: 54
                    }
                }), e("panel", 0.5, 0.34, "t", {
                    w: 0.22,
                    h: 0.12,
                    options: {
                        colour: "gradient",
                        radius: 54,
                        shadow: false
                    }
                }), e("avatar", 0.5, 0.46, "c", {
                    scale: 1.02
                }), e("username", 0.5, 0.53, "t", {
                    options: {
                        size: "headline",
                        weight: "bold"
                    }
                }), e("greeting", 0.5, 0.59, "t"), e("password", 0.5, 0.65, "t", {
                    options: {
                        width: 370
                    }
                })];
        case "vertical":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("session", 1 - root.mx, 1 - root.my, "br"), e("clock", root.mx, 0.5, "l", {
                    rotation: -90,
                    scale: 1.3
                }), e("date", 0.235, 0.7, "bl", {
                    scale: 1.3,
                    options: {
                        format: "dddd",
                        size: "headline",
                        colour: "primary",
                        weight: "bold"
                    }
                }), e("date", 0.235, 0.71, "tl", {
                    options: {
                        format: "d MMMM yyyy",
                        size: "title",
                        weight: "bold"
                    }
                }), e("weather", 0.235, 0.77, "tl", {
                    scale: 0.85
                }), ...root.inlineLogin(0.235, 0.87, 300)];
        case "bento":
            {
                const tile = (x, y, w, h, colour) => e("panel", x, y, "tl", {
                        w: w,
                        h: h,
                        options: {
                            colour: colour ?? "container",
                            radius: 28,
                            shadow: false
                        }
                    });
                return [e("status", 1 - root.mx, root.my, "tr", {
                        scale: 0.9
                    }), e("session", 1 - root.mx, 1 - root.my, "br"), tile(0.31, 0.25, 0.185, 0.33, "primary"), e("clock", 0.4025, 0.415, "c", {
                        scale: 0.52,
                        options: {
                            face: "stacked"
                        }
                    }), tile(0.505, 0.25, 0.185, 0.158), e("date", 0.52, 0.329, "l", {
                        options: {
                            format: "d",
                            size: "display",
                            colour: "primary",
                            weight: "bold"
                        }
                    }), e("date", 0.592, 0.329, "bl", {
                        options: {
                            format: "dddd",
                            size: "title"
                        }
                    }), e("date", 0.592, 0.329, "tl", {
                        // NOTE(fork): the month shortened ("Sep 2026"), as the longest full one ran out of
                        // the tile beside a two-digit day
                        options: {
                            format: "MMM yyyy",
                            size: "title",
                            colour: "variant",
                            weight: "regular"
                        }
                    }), tile(0.505, 0.422, 0.0875, 0.158), e("stat", 0.513, 0.437, "tl", {
                        options: {
                            metric: "weather"
                        }
                    }), tile(0.6025, 0.422, 0.0875, 0.158), e("stat", 0.6105, 0.437, "tl", {
                        options: {
                            metric: "battery"
                        }
                    }), tile(0.31, 0.594, 0.38, 0.158), ...root.inlineLogin(0.325, 0.673, 560)];
            }
        case "flip":
            return [...root.corners(), e("clock", 0.5, 0.36, "c", {
                    options: {
                        face: "flip",
                        accent: false
                    }
                }), e("date", 0.5, 0.57, "t", {
                    scale: 1.1,
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), ...root.inlineLogin(0.405, 0.69, 300)];
        case "dotmatrix":
            return [...root.corners(), e("clock", 0.5, 0.38, "c", {
                    options: {
                        face: "dots"
                    }
                }), e("date", 0.5, 0.53, "t", {
                    scale: 1.4,
                    options: {
                        format: "ddd d MMM",
                        mono: true,
                        uppercase: true,
                        weight: "bold",
                        spacing: 6,
                        size: "body"
                    }
                }), ...root.inlineLogin(0.405, 0.65, 300)];
        case "agenda":
            return [...root.corners(), e("clock", 0.46, 0.42, "br", {
                    scale: 0.8
                }), e("date", 0.46, 0.44, "tr", {
                    scale: 1.1,
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("greeting", 0.46, 0.51, "tr"), e("divider", 0.5, 0.43, "c", {
                    w: 0.0012,
                    h: 0.32
                }), e("calendar", 0.54, 0.43, "l", {
                    scale: 1.15
                }), ...root.inlineLogin(0.41, 0.85, 300)];
        case "nowplaying":
            // The equalizer first, so it's drawn behind the corners it runs under
            return [e("equalizer", 0.5, 1, "b", {
                    w: 1,
                    h: 0.1,
                    opacity: 0.8,
                    options: {
                        colour: "gradient"
                    }
                }), ...root.corners(), e("clock", 0.5, 0.1, "t", {
                    scale: 0.5
                }), e("date", 0.5, 0.25, "t", {
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("media", 0.5, 0.48, "c", {
                    scale: 1.6
                }), ...root.inlineLogin(0.41, 0.8, 300)];
        case "poster":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("date", 0.045, 0.06, "tl", {
                    scale: 1.6,
                    options: {
                        format: "dddd",
                        size: "display",
                        colour: "primary",
                        weight: "bold",
                        uppercase: true
                    }
                }), e("date", 0.05, 0.38, "tl", {
                    scale: 1.2,
                    options: {
                        format: "d MMMM",
                        size: "display",
                        weight: "bold"
                    }
                }), e("clock", 0.05, 1 - root.my, "bl", {
                    scale: 0.5,
                    options: {
                        align: "left"
                    }
                }), e("weather", 0.3, 1 - root.my, "bl"), e("password", 1 - root.mx, 1 - root.my, "br", {
                    options: {
                        width: 340
                    }
                }), e("session", 1 - root.mx, 0.86, "br", {
                    scale: 0.85
                })];
        case "compact":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("panel", 0.5, 0.5, "c", {
                    w: 0.2,
                    h: 0.66,
                    options: {
                        colour: "surface",
                        radius: 48
                    }
                }), e("clock", 0.5, 0.25, "t", {
                    scale: 0.55,
                    options: {
                        face: "stacked"
                    }
                }), e("date", 0.5, 0.5, "t", {
                    options: {
                        format: "ddd d MMM",
                        size: "title",
                        colour: "variant"
                    }
                }), e("avatar", 0.5, 0.56, "t", {
                    scale: 0.6
                }), e("password", 0.5, 0.68, "t", {
                    options: {
                        width: 300
                    }
                }), e("session", 0.5, 0.75, "t", {
                    scale: 0.7
                })];
        case "board":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("session", 1 - root.mx, 1 - root.my, "br"), e("clock", 0.08, 0.42, "bl", {
                    scale: 0.8,
                    options: {
                        align: "left"
                    }
                }), e("date", 0.08, 0.44, "tl", {
                    scale: 1.1,
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), e("greeting", 0.08, 0.5, "tl"), e("widget:calendar", 0.515, 0.18, "tl", {
                    options: {
                        style: "month"
                    }
                }), e("widget:weather", 0.69, 0.18, "tl", {
                    options: {
                        style: "default"
                    }
                }), e("widget:media", 0.515, 0.48, "tl", {
                    options: {
                        style: "default"
                    }
                }), e("widget:resources", 0.69, 0.44, "tl", {
                    options: {
                        style: "rings-all"
                    }
                }), ...root.inlineLogin(0.08, 0.66, 300)];
        case "giant":
            return [e("status", root.mx, root.my, "tl", {
                    scale: 0.9,
                    options: {
                        direction: "left"
                    }
                }), e("session", 1 - root.mx, root.my, "tr", {
                    scale: 0.85
                }), e("clock", 0.025, 0.66, "bl", {
                    scale: 2.6,
                    options: {
                        align: "left"
                    }
                }), e("date", 0.035, 0.68, "tl", {
                    scale: 1.3,
                    options: {
                        format: "dddd, d MMMM",
                        size: "headline",
                        colour: "variant",
                        weight: "bold"
                    }
                }), ...root.inlineLogin(0.72, 0.87, 300)];
        case "aurora":
            return [e("panel", 0, 0, "tl", {
                    w: 0.36,
                    h: 1,
                    options: {
                        colour: "gradient",
                        radius: 0,
                        shadow: false
                    }
                }), e("clock", 0.18, 0.4, "c", {
                    scale: 1.15,
                    options: {
                        face: "stacked",
                        accent: false
                    }
                }), e("date", 0.18, 0.69, "t", {
                    options: {
                        format: "dddd • d MMM",
                        size: "title",
                        weight: "bold",
                        uppercase: true,
                        spacing: 4
                    }
                }), e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("avatar", 0.68, 0.42, "c", {
                    scale: 1.1
                }), e("username", 0.68, 0.52, "t", {
                    options: {
                        size: "headline",
                        weight: "bold"
                    }
                }), e("password", 0.68, 0.59, "t", {
                    options: {
                        width: 360
                    }
                }), e("session", 0.68, 0.69, "t", {
                    scale: 0.85
                })];
        case "studio":
            return [...root.corners(), e("clock", 0.33, 0.45, "c", {
                    scale: 0.75,
                    options: {
                        face: "analogue"
                    }
                }), e("divider", 0.5, 0.45, "c", {
                    w: 0.0012,
                    h: 0.36
                }), e("date", 0.54, 0.41, "bl", {
                    options: {
                        format: "dddd",
                        size: "display",
                        colour: "primary",
                        weight: "bold"
                    }
                }), e("date", 0.54, 0.42, "tl", {
                    options: {
                        format: "d MMMM yyyy",
                        size: "headline",
                        weight: "medium"
                    }
                }), ...root.inlineLogin(0.54, 0.57, 320)];
        case "magazine":
            return [e("date", 0.035, 0.5, "l", {
                    scale: 4.2,
                    options: {
                        format: "d",
                        size: "display",
                        colour: "primary",
                        weight: "bold"
                    }
                }), e("date", 0.965, 0.5, "c", {
                    rotation: 90,
                    options: {
                        format: "MMMM",
                        size: "headline",
                        weight: "bold",
                        uppercase: true,
                        spacing: 12
                    }
                }), e("status", 0.42, root.my, "tl", {
                    scale: 0.9,
                    options: {
                        direction: "left"
                    }
                }), e("date", 0.42, 0.3, "bl", {
                    options: {
                        format: "dddd",
                        size: "display",
                        weight: "bold"
                    }
                }), e("clock", 0.42, 0.32, "tl", {
                    scale: 0.6,
                    options: {
                        align: "left"
                    }
                }), e("weather", 0.42, 0.55, "tl", {
                    options: {
                        style: "large"
                    }
                }), ...root.inlineLogin(0.42, 0.84, 320)];
        case "menubar":
            return [e("panel", 0, 0, "tl", {
                    w: 1,
                    h: 0.045,
                    options: {
                        colour: "surface",
                        radius: 0,
                        shadow: false
                    }
                }), e("date", 0.012, 0.0225, "l", {
                    options: {
                        format: "ddd d MMM",
                        size: "body",
                        weight: "bold"
                    }
                }), e("date", 0.5, 0.0225, "c", {
                    options: {
                        format: "time",
                        size: "body",
                        weight: "bold"
                    }
                }), e("status", 0.99, 0.0225, "r", {
                    scale: 0.7
                }), e("avatar", 0.5, 0.42, "c", {
                    scale: 1.4
                }), e("username", 0.5, 0.53, "t", {
                    options: {
                        size: "headline",
                        weight: "bold"
                    }
                }), e("password", 0.5, 0.6, "t", {
                    options: {
                        width: 340
                    }
                }), e("session", 0.5, 1 - root.my, "b", {
                    scale: 0.85
                })];
        case "mission":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("clock", 0.08, 0.24, "bl", {
                    scale: 0.75,
                    options: {
                        align: "left"
                    }
                }), e("widget:clock", 0.08, 0.27, "tl", {
                    options: {
                        style: "world"
                    }
                }), e("widget:weather", 0.22, 0.27, "tl", {
                    options: {
                        style: "hourly"
                    }
                }), e("widget:resources", 0.395, 0.27, "tl", {
                    options: {
                        style: "bars-all"
                    }
                }), e("widget:calendar", 0.08, 0.47, "tl", {
                    options: {
                        style: "week"
                    }
                }), e("widget:day", 0.22, 0.47, "tl", {
                    options: {
                        style: "timeline"
                    }
                }), e("widget:events", 0.395, 0.47, "tl", {
                    options: {
                        style: "upcoming"
                    }
                }), ...root.inlineLogin(0.68, 0.5, 340)];
        case "tty":
            return [e("terminal", 0.04, 0.06, "tl"), e("password", 0.04, 0.6, "tl", {
                    options: {
                        width: 640,
                        label: Tr.tr("Password:")
                    }
                }), e("date", 0.04, 1 - root.my, "bl", {
                    options: {
                        pattern: "ddd MMM d hh:mm:ss yyyy",
                        size: "body",
                        colour: "variant",
                        weight: "regular",
                        mono: true
                    }
                }), e("status", 1 - root.mx, 1 - root.my, "br", {
                    scale: 0.85
                })];
        case "tilted":
            return [...root.corners(), e("clock", 0.5, 0.4, "c", {
                    scale: 1.7,
                    rotation: -8
                }), e("date", 0.53, 0.6, "c", {
                    rotation: -8,
                    options: {
                        format: "dddd • d MMM",
                        size: "headline",
                        colour: "primary",
                        weight: "bold",
                        uppercase: true,
                        spacing: 6
                    }
                }), ...root.inlineLogin(0.405, 0.82, 300)];
        case "island":
            return [e("weather", root.mx, root.my, "tl", {
                    scale: 0.9
                }), e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("clock", 0.5, 0.4, "c", {
                    scale: 1.2,
                    options: {
                        face: "words",
                        align: "center"
                    }
                }), e("panel", 0.5, 0.88, "c", {
                    w: 0.56,
                    h: 0.1,
                    options: {
                        colour: "container",
                        radius: 80
                    }
                }), e("avatar", 0.245, 0.88, "c", {
                    scale: 0.45
                }), e("date", 0.275, 0.88, "l", {
                    options: {
                        format: "time",
                        size: "headline",
                        weight: "bold"
                    }
                }), e("date", 0.36, 0.88, "l", {
                    options: {
                        format: "ddd d MMM",
                        size: "title",
                        colour: "variant"
                    }
                }), e("password", 0.765, 0.88, "r", {
                    options: {
                        width: 340
                    }
                })];
        case "gauges":
            {
                const gauge = (x, metric) => [e("panel", x, 0.5, "tl", {
                            w: 0.11,
                            h: 0.16,
                            options: {
                                colour: "container",
                                radius: 28,
                                shadow: false
                            }
                        }), e("stat", x + 0.008, 0.515, "tl", {
                            options: {
                                metric: metric
                            }
                        })];
                return [e("status", 1 - root.mx, root.my, "tr", {
                        scale: 0.9
                    }), e("session", 1 - root.mx, 1 - root.my, "br"), e("clock", 0.5, 0.17, "t", {
                        scale: 0.8
                    }), e("date", 0.5, 0.39, "t", {
                        options: {
                            format: "dddd, d MMMM",
                            size: "title",
                            weight: "bold"
                        }
                    }), ...gauge(0.325, "battery"), ...gauge(0.445, "weather"), ...gauge(0.565, "day"), ...root.inlineLogin(0.405, 0.8, 300)];
            }
        case "calendarwall":
            return [e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("session", 1 - root.mx, 1 - root.my, "br"), e("calendar", 0.07, 0.5, "l", {
                    scale: 2
                }), e("clock", 0.74, 0.36, "c", {
                    options: {
                        face: "stacked"
                    }
                }), e("date", 0.74, 0.58, "t", {
                    scale: 1.1,
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), ...root.inlineLogin(0.645, 0.74, 300)];
        case "halves":
            return [e("panel", 0.5, 0, "tl", {
                    w: 0.5,
                    h: 1,
                    options: {
                        colour: "surface",
                        radius: 0,
                        shadow: false
                    }
                }), e("clock", 0.25, 0.43, "c", {
                    scale: 1.3,
                    options: {
                        face: "stacked"
                    }
                }), e("date", 0.25, 0.76, "t", {
                    options: {
                        format: "dddd, d MMMM",
                        size: "title",
                        colour: "variant",
                        weight: "bold"
                    }
                }), e("weather", 0.56, root.my, "tl", {
                    scale: 0.9
                }), e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("greeting", 0.75, 0.4, "c", {
                    scale: 1.3
                }), ...root.inlineLogin(0.655, 0.52, 320), e("session", 0.75, 1 - root.my, "b", {
                    scale: 0.85
                })];
        case "pulse":
            // The equalizer first, so it's drawn behind everything else
            return [e("equalizer", 0.5, 1, "b", {
                    w: 1,
                    h: 0.38,
                    opacity: 0.85,
                    options: {
                        colour: "chroma",
                        bars: 64
                    }
                }), ...root.corners().slice(0, 2), e("clock", 0.5, 0.33, "c", {
                    scale: 1.15,
                    options: {
                        face: "flip",
                        accent: false
                    }
                }), e("date", 0.5, 0.52, "t", {
                    scale: 1.1,
                    options: {
                        size: "title",
                        weight: "bold"
                    }
                }), ...root.inlineLogin(0.405, 0.61, 300)];
        case "spectrum":
            return [e("equalizer", 0.5, 0, "t", {
                    w: 1,
                    h: 0.3,
                    opacity: 0.8,
                    options: {
                        style: "wave",
                        colour: "gradient",
                        grow: "down"
                    }
                }), e("equalizer", 0.5, 1, "b", {
                    w: 1,
                    h: 0.3,
                    opacity: 0.8,
                    options: {
                        style: "wave",
                        colour: "gradient"
                    }
                }), e("clock", 0.5, 0.43, "c", {
                    options: {
                        face: "dots"
                    }
                }), e("date", 0.5, 0.56, "t", {
                    scale: 1.3,
                    options: {
                        format: "ddd d MMM",
                        mono: true,
                        uppercase: true,
                        weight: "bold",
                        spacing: 6,
                        size: "body"
                    }
                }), ...root.inlineLogin(0.405, 0.65, 300)];
        case "skyline":
            return [e("equalizer", 0.5, 1, "b", {
                    w: 1,
                    h: 0.55,
                    opacity: 0.55,
                    options: {
                        shape: "square",
                        bars: 96,
                        response: "sqrt"
                    }
                }), e("status", 1 - root.mx, root.my, "tr", {
                    scale: 0.9
                }), e("date", root.mx, root.my, "tl", {
                    options: {
                        format: "dddd, d MMMM",
                        size: "headline",
                        weight: "bold"
                    }
                }), e("clock", 0.5, 0.42, "c", {
                    scale: 2.2
                }), ...root.inlineLogin(0.405, 0.12, 300)];
        case "blank":
            return [e("password", 0.5, 0.5, "c")];
        default:
            return root.build("classic");
        }
    }

    // Left for right: what was pinned by its left edge is pinned by its right, the same distance
    // in, and left/right alignments and pill directions swap with it
    function mirror(elements: var): var {
        const swap = {
            l: "r",
            r: "l",
            left: "right",
            right: "left"
        };
        return elements.map(el => {
            const a = el.anchor ?? "c";
            const anchor = a.length === 2 ? a[0] + (swap[a[1]] ?? a[1]) : (swap[a] ?? a);
            const options = Object.assign({}, el.options ?? {});
            for (const k of ["align", "direction"])
                if (options[k] && swap[options[k]])
                    options[k] = swap[options[k]];
            return Object.assign({}, el, {
                x: 1 - el.x,
                anchor: anchor,
                rotation: -(el.rotation ?? 0),
                options: options
            });
        });
    }

    // The old layout setting's preset, standing in until the layout is first edited. The layouts
    // that had a login side are mirrored for a login on the left; "clock" was the short-lived
    // combined clock layout, which minimal covers; "card" is the classic card
    function legacy(layout: string, panelSide: string): var {
        const id = ({
                card: "classic",
                clock: "minimal"
            })[layout] ?? layout;
        const known = root.list.some(p => p.id === id);
        const elements = root.build(known ? id : "classic");
        const sided = ["split", "sidebar", "band"].includes(id);
        // These were built with the login on the right; split put it there by default too
        return sided && panelSide === "left" ? root.mirror(elements) : elements;
    }

    // A config node from Config.lock.elements as a plain object, each property read so whoever
    // calls this is worked out again when any of them changes
    function plain(node: var): var {
        return {
            id: node.id,
            enabled: node.enabled,
            x: node.x,
            y: node.y,
            anchor: node.anchor,
            w: node.w,
            h: node.h,
            scale: node.scale,
            opacity: node.opacity,
            rotation: node.rotation,
            showOn: node.showOn,
            options: Object.assign({}, node.options ?? {})
        };
    }

    // What the lock screen shows: the saved elements, or the old layout's preset if none are saved
    function effective(lockConfig: var): var {
        const nodes = lockConfig?.elements?.values ?? [];
        if (nodes.length > 0)
            return nodes.map(n => root.plain(n));
        return root.legacy(lockConfig?.layout ?? "card", lockConfig?.panelSide ?? "right");
    }
}
