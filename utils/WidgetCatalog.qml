pragma Singleton

import QtQuick
import Quickshell
import Caelestia.I18n

// What can be put on the desktop and the variants each kind comes in. The heights are in grid cells
// (utils/widgetgrid.js): a card's footprint, and what its variant is laid out for. Adding a kind here plus a
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
                    name: Tr.tr("Rings · CPU, RAM and temperature"),
                    height: 5
                },
                {
                    id: "rings-basic",
                    name: Tr.tr("Rings · CPU and RAM"),
                    height: 4
                },
                {
                    id: "bars-all",
                    name: Tr.tr("Bars · CPU, RAM and disk"),
                    height: 5
                },
                {
                    id: "bars-basic",
                    name: Tr.tr("Bars · CPU and RAM"),
                    height: 4
                },
                {
                    id: "line-all",
                    name: Tr.tr("Line graph · CPU, RAM and disk"),
                    height: 6
                },
                {
                    id: "line-basic",
                    name: Tr.tr("Line graph · CPU and RAM"),
                    height: 5
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
