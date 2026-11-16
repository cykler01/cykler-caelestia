pragma Singleton

import QtQuick
import Quickshell
import Caelestia.I18n

// What can be put on the desktop and the variants each kind comes in. The heights are in grid cells
// (utils/widgetgrid.js): a card's footprint, and what its variant is laid out for. A variant may also give
// a `width` in cells for a card that is not the usual 8 wide (a wide strip, a small square). Adding a kind here plus a
// delegate in DesktopWidgets.qml is all it takes for it to appear in the picker.
Singleton {
    id: root

    readonly property list<var> kinds: [
        {
            id: "calendar",
            name: Tr.tr("Calendar"),
            icon: "calendar_month",
            types: [
                {
                    id: "month",
                    name: Tr.tr("Month"),
                    height: 8
                },
                {
                    id: "week",
                    name: Tr.tr("Week strip"),
                    height: 5
                },
                {
                    id: "today",
                    name: Tr.tr("Today · large date"),
                    height: 5,
                    width: 5
                },
                {
                    id: "agenda",
                    name: Tr.tr("Agenda · coming up"),
                    height: 6
                }
            ]
        },
        {
            id: "clock",
            name: Tr.tr("Clock"),
            icon: "schedule",
            types: [
                {
                    id: "digital",
                    name: Tr.tr("Digital"),
                    height: 4
                },
                {
                    id: "minimal",
                    name: Tr.tr("Time only"),
                    height: 4
                },
                {
                    id: "analogue",
                    name: Tr.tr("Analogue"),
                    height: 5
                },
                {
                    id: "stacked",
                    name: Tr.tr("Stacked figures"),
                    height: 6,
                    width: 5
                },
                {
                    id: "world",
                    name: Tr.tr("World clocks"),
                    height: 5
                },
                {
                    id: "large",
                    name: Tr.tr("Large figures"),
                    height: 7,
                    width: 6
                },
                {
                    id: "face",
                    name: Tr.tr("Shaped face"),
                    height: 6,
                    width: 6
                }
            ]
        },
        {
            id: "weather",
            name: Tr.tr("Weather"),
            icon: "partly_cloudy_day",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Forecast"),
                    height: 7
                },
                {
                    id: "compact",
                    name: Tr.tr("Current conditions"),
                    height: 4
                },
                {
                    id: "hourly",
                    name: Tr.tr("Hourly forecast"),
                    height: 5,
                    width: 10
                },
                {
                    id: "details",
                    name: Tr.tr("Conditions in detail"),
                    height: 6
                },
                {
                    id: "mini",
                    name: Tr.tr("Mini"),
                    height: 2,
                    width: 5
                }
            ]
        },
        {
            id: "pomodoro",
            name: Tr.tr("Focus timer"),
            icon: "timer",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Timer"),
                    height: 5
                }
            ]
        },
        {
            id: "resources",
            name: Tr.tr("System resources"),
            icon: "monitoring",
            types: [
                {
                    id: "rings-all",
                    name: Tr.tr("Rings · three readings"),
                    height: 5
                },
                {
                    id: "rings-basic",
                    name: Tr.tr("Rings · two readings"),
                    height: 4
                },
                {
                    id: "bars-all",
                    name: Tr.tr("Bars · three readings"),
                    height: 5
                },
                {
                    id: "bars-basic",
                    name: Tr.tr("Bars · two readings"),
                    height: 4
                },
                {
                    id: "line-all",
                    name: Tr.tr("Line graph · three readings"),
                    height: 6
                },
                {
                    id: "line-basic",
                    name: Tr.tr("Line graph · two readings"),
                    height: 5
                },
                {
                    id: "tiles",
                    name: Tr.tr("Tiles"),
                    height: 6
                },
                {
                    id: "compact",
                    name: Tr.tr("Compact strip"),
                    height: 2
                }
            ]
        },
        {
            id: "network",
            name: Tr.tr("Network"),
            icon: "swap_vert",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Speeds"),
                    height: 4
                },
                {
                    id: "graph",
                    name: Tr.tr("Graph"),
                    height: 5
                },
                {
                    id: "details",
                    name: Tr.tr("Connection details"),
                    height: 5
                },
                {
                    id: "compact",
                    name: Tr.tr("Compact"),
                    height: 2,
                    width: 6
                }
            ]
        },
        {
            id: "media",
            name: Tr.tr("Now playing"),
            icon: "music_note",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Player"),
                    height: 6
                },
                {
                    id: "cover",
                    name: Tr.tr("Cover"),
                    height: 9
                },
                {
                    id: "strip",
                    name: Tr.tr("Strip"),
                    height: 3,
                    width: 10
                },
                {
                    id: "pill",
                    name: Tr.tr("Pill"),
                    height: 2,
                    width: 9
                },
                {
                    id: "disc",
                    name: Tr.tr("Spinning disc"),
                    height: 6,
                    width: 6
                },
                {
                    id: "art",
                    name: Tr.tr("Cover art"),
                    height: 6,
                    width: 6
                }
            ]
        },
        {
            id: "lyrics",
            name: Tr.tr("Lyrics"),
            icon: "lyrics",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Synced lyrics"),
                    height: 8
                },
                {
                    id: "line",
                    name: Tr.tr("Single line"),
                    height: 2,
                    width: 14
                },
                {
                    id: "highlight",
                    name: Tr.tr("Highlighted lines"),
                    height: 4,
                    width: 14
                }
            ]
        },
        {
            id: "battery",
            name: Tr.tr("Battery"),
            icon: "battery_full",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Charge and rate"),
                    height: 4
                },
                {
                    id: "ring",
                    name: Tr.tr("Ring"),
                    height: 6
                },
                {
                    id: "bar",
                    name: Tr.tr("Bar"),
                    height: 3,
                    width: 7
                },
                {
                    id: "devices",
                    name: Tr.tr("All devices"),
                    height: 6
                }
            ]
        },
        {
            id: "bluetooth",
            name: Tr.tr("Bluetooth"),
            icon: "bluetooth",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Device batteries"),
                    height: 5
                }
            ]
        },
        {
            id: "fetch",
            name: Tr.tr("Caelestia fetch"),
            icon: "terminal",
            types: [
                {
                    id: "compact",
                    name: Tr.tr("Compact"),
                    height: 4
                },
                {
                    id: "large",
                    name: Tr.tr("Large"),
                    height: 8
                },
                {
                    id: "terminal",
                    name: Tr.tr("Terminal"),
                    height: 8,
                    width: 10
                }
            ]
        },
        {
            id: "visualiser",
            name: Tr.tr("Visualiser"),
            icon: "graphic_eq",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Spectrum"),
                    height: 5
                },
                {
                    id: "mirror",
                    name: Tr.tr("Mirrored"),
                    height: 5
                },
                {
                    id: "wide",
                    name: Tr.tr("Wide bars"),
                    height: 4,
                    width: 18
                },
                {
                    id: "wave",
                    name: Tr.tr("Wave"),
                    height: 4,
                    width: 14
                }
            ]
        },
        {
            id: "sticky",
            name: Tr.tr("Sticky note"),
            icon: "sticky_note_2",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Note"),
                    height: 6
                },
                {
                    id: "lined",
                    name: Tr.tr("Lined paper"),
                    height: 7
                },
                {
                    id: "headline",
                    name: Tr.tr("Headline"),
                    height: 4
                }
            ]
        },
        {
            id: "photo",
            name: Tr.tr("Pictures"),
            icon: "photo",
            types: [
                {
                    id: "default",
                    name: Tr.tr("Single picture"),
                    height: 7
                },
                {
                    id: "framed",
                    name: Tr.tr("Framed print"),
                    height: 8,
                    width: 6
                },
                {
                    id: "shaped",
                    name: Tr.tr("Shaped"),
                    height: 6,
                    width: 6
                }
            ]
        },
        {
            id: "github",
            name: Tr.tr("GitHub"),
            icon: "calendar_view_week",
            types: [
                {
                    id: "week",
                    name: Tr.tr("Squares · last 7 days"),
                    height: 4
                },
                {
                    id: "month",
                    name: Tr.tr("Squares · last 30 days"),
                    height: 5
                },
                {
                    id: "week-stats",
                    name: Tr.tr("Squares · last 7 days and stats"),
                    height: 4
                },
                {
                    id: "month-stats",
                    name: Tr.tr("Squares · last 30 days and stats"),
                    height: 5
                },
                {
                    id: "week-line",
                    name: Tr.tr("Line graph · last 7 days"),
                    height: 5
                },
                {
                    id: "month-line",
                    name: Tr.tr("Line graph · last 30 days"),
                    height: 6
                },
                {
                    id: "year",
                    name: Tr.tr("Squares · last year"),
                    height: 5,
                    width: 14
                },
                {
                    id: "streak",
                    name: Tr.tr("Streak"),
                    height: 4
                }
            ]
        },
        {
            id: "stocks",
            name: Tr.tr("Stocks"),
            icon: "trending_up",
            types: [
                {
                    id: "watchlist",
                    name: Tr.tr("Watchlist · price and daily change"),
                    height: 7
                },
                {
                    id: "spotlight",
                    name: Tr.tr("Spotlight · chart and quotes"),
                    height: 7
                },
                {
                    id: "compact",
                    name: Tr.tr("Compact · 2 × 2 quotes"),
                    height: 4
                },
                {
                    id: "portfolio",
                    name: Tr.tr("Portfolio · total value and combined chart"),
                    height: 8
                }
            ]
        },
        {
            id: "progress",
            name: Tr.tr("Progress"),
            icon: "hourglass_top",
            types: [
                {
                    id: "bars",
                    name: Tr.tr("Bars · milestones and time left"),
                    height: 7
                },
                {
                    id: "rings",
                    name: Tr.tr("Rings · milestones and time left"),
                    height: 7
                },
                {
                    id: "compact",
                    name: Tr.tr("Compact · mini rings"),
                    height: 5
                },
                {
                    id: "dots",
                    name: Tr.tr("Dots"),
                    height: 6
                }
            ]
        },
        {
            id: "todo",
            name: Tr.tr("To-do list"),
            icon: "checklist",
            types: [
                {
                    id: "upcoming",
                    name: Tr.tr("Upcoming tasks"),
                    height: 5
                },
                {
                    id: "today",
                    name: Tr.tr("Due today"),
                    height: 5
                },
                {
                    id: "focus",
                    name: Tr.tr("Focus · one task"),
                    height: 5
                }
            ]
        },
        {
            id: "glance",
            name: Tr.tr("At a glance"),
            icon: "today",
            types: [
                {
                    id: "line",
                    name: Tr.tr("One line"),
                    height: 2,
                    width: 12
                },
                {
                    id: "card",
                    name: Tr.tr("Card"),
                    height: 3,
                    width: 10
                }
            ]
        },
        {
            id: "search",
            name: Tr.tr("Web search"),
            icon: "search",
            types: [
                {
                    id: "field",
                    name: Tr.tr("Search field"),
                    height: 2,
                    width: 10
                },
                {
                    id: "shortcuts",
                    name: Tr.tr("Search and sites"),
                    height: 4,
                    width: 10
                }
            ]
        },
        {
            id: "sun",
            name: Tr.tr("Daylight"),
            icon: "wb_sunny",
            types: [
                {
                    id: "arc",
                    name: Tr.tr("Sun path"),
                    height: 5
                },
                {
                    id: "times",
                    name: Tr.tr("Sunrise and sunset"),
                    height: 4,
                    width: 7
                },
                {
                    id: "strip",
                    name: Tr.tr("Strip"),
                    height: 2,
                    width: 7
                }
            ]
        },
        {
            id: "palette",
            name: Tr.tr("Colour scheme"),
            icon: "palette",
            types: [
                {
                    id: "swatches",
                    name: Tr.tr("Swatches"),
                    height: 5
                },
                {
                    id: "tones",
                    name: Tr.tr("Tonal ramps"),
                    height: 4
                }
            ]
        },
        {
            id: "shortcuts",
            name: Tr.tr("Quick launch"),
            icon: "apps",
            types: [
                {
                    id: "grid",
                    name: Tr.tr("Grid"),
                    height: 6,
                    width: 6
                },
                {
                    id: "row",
                    name: Tr.tr("Row"),
                    height: 2
                }
            ]
        },
        {
            id: "toggles",
            name: Tr.tr("Quick toggles"),
            icon: "toggle_on",
            types: [
                {
                    id: "grid",
                    name: Tr.tr("Grid"),
                    height: 6,
                    width: 6
                },
                {
                    id: "row",
                    name: Tr.tr("Row"),
                    height: 2
                },
                {
                    id: "tiles",
                    name: Tr.tr("Tiles"),
                    height: 7,
                    width: 10
                }
            ]
        },
        {
            id: "timer",
            name: Tr.tr("Timers & alarms"),
            icon: "hourglass_empty",
            types: [
                {
                    id: "countdown",
                    name: Tr.tr("Countdown"),
                    height: 6,
                    width: 6
                },
                {
                    id: "stopwatch",
                    name: Tr.tr("Stopwatch"),
                    height: 4
                },
                {
                    id: "alarm",
                    name: Tr.tr("Next alarm"),
                    height: 3
                }
            ]
        },
        {
            id: "games",
            name: Tr.tr("Game library"),
            icon: "sports_esports",
            types: [
                {
                    id: "shelf",
                    name: Tr.tr("Shelf"),
                    height: 6,
                    width: 12
                },
                {
                    id: "list",
                    name: Tr.tr("List"),
                    height: 7
                },
                {
                    id: "featured",
                    name: Tr.tr("Featured"),
                    height: 4,
                    width: 12
                }
            ]
        },
        {
            id: "thermal",
            name: Tr.tr("Temperatures"),
            icon: "thermostat",
            types: [
                {
                    id: "gauges",
                    name: Tr.tr("Gauges"),
                    height: 4
                },
                {
                    id: "detail",
                    name: Tr.tr("Sensors in detail"),
                    height: 6
                },
                {
                    id: "compact",
                    name: Tr.tr("Compact"),
                    height: 2,
                    width: 6
                }
            ]
        },
        {
            id: "phone",
            name: Tr.tr("Phone"),
            icon: "smartphone",
            types: [
                {
                    id: "card",
                    name: Tr.tr("Card"),
                    height: 4
                },
                {
                    id: "compact",
                    name: Tr.tr("Compact"),
                    height: 2,
                    width: 6
                }
            ]
        }
    ]

    function kindFor(id: string): var {
        return kinds.find(k => k.id === id) ?? null;
    }

    function typesFor(id: string): var {
        return kindFor(id)?.types ?? [];
    }

    // The variant an entry actually shows: the one asked for, or the kind's first
    function typeFor(id: string, type: string): var {
        const types = typesFor(id);
        return types.find(t => t.id === (type ?? "")) ?? types[0] ?? null;
    }

    function heightFor(id: string, type: string): int {
        return typeFor(id, type)?.height ?? 5;
    }

    // NOTE(fork): 8 is the usual card width (WidgetGrid.cardCells), kept as a literal here since
    // a singleton cannot import the grid's .pragma library without a circular include
    function widthFor(id: string, type: string): int {
        return typeFor(id, type)?.width ?? 8;
    }

    function nameFor(id: string): string {
        return kindFor(id)?.name ?? id;
    }

    function iconFor(id: string): string {
        return kindFor(id)?.icon ?? "widgets";
    }

    // The variant's own name; empty for kinds that only come one way, so lists can show just the kind
    function typeNameFor(id: string, type: string): string {
        if (typesFor(id).length < 2)
            return "";
        return typeFor(id, type)?.name ?? "";
    }
}
