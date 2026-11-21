import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

// Sub-page numbers (openSubPage) refer to the order of the components in PageCompRegistry's Panels stack, so the
// rows below can be arranged freely without renumbering anything.
PageBase {
    id: root

    // What a hot corner can be set to open, ordered to match config::HotCornerAction (None, Overview,
    // Sidebar). A corner opens one panel at most, so this is a choice rather than a set of toggles
    readonly property list<MenuItem> cornerItems: [
        MenuItem {
            text: Tr.trCtx("Nothing", "hot corner action")
            icon: "block"
        },
        MenuItem {
            text: Tr.trCtx("Overview", "hot corner action")
            icon: "grid_view"
        },
        MenuItem {
            text: Tr.trCtx("Sidebar", "hot corner action")
            icon: "dock_to_right"
        }
    ]

    // NOTE(fork): the floor equalizer's placement and look (modules/background/FloorEqualizer.qml),
    // in the order of the config values they map to
    readonly property list<string> eqPositions: ["floor", "ceiling"]
    readonly property list<MenuItem> eqPositionItems: [
        MenuItem {
            text: Tr.trCtx("Floor", "equalizer position")
            icon: "vertical_align_bottom"
        },
        MenuItem {
            text: Tr.trCtx("Ceiling", "equalizer position")
            icon: "vertical_align_top"
        }
    ]
    readonly property list<string> eqStyles: ["bars", "wave", "line"]
    readonly property list<MenuItem> eqStyleItems: [
        MenuItem {
            text: Tr.trCtx("Bars", "equalizer style")
            icon: "equalizer"
        },
        MenuItem {
            text: Tr.trCtx("Wave", "equalizer style")
            icon: "waves"
        },
        MenuItem {
            text: Tr.trCtx("Line", "equalizer style")
            icon: "show_chart"
        }
    ]

    title: Tr.tr("Panels")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // The bar and the panels that open from the screen edges
        SectionHeader {
            first: true
            text: Tr.tr("Bar & panels")
        }

        NavRow {
            first: true
            icon: "dock_to_bottom"
            text: Tr.tr("Taskbar")
            subtext: Config.bar.persistent ? Tr.tr("Always visible") : Config.bar.showOnHover ? Tr.tr("Reveal on hover") : Tr.tr("Reveal on drag")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "dashboard"
            text: Tr.tr("Dashboard")
            subtext: Config.dashboard.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(1)
        }

        NavRow {
            icon: "apps"
            text: Tr.tr("Launcher")
            subtext: Config.launcher.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(3)
        }

        NavRow {
            icon: "queue_music"
            text: Tr.tr("Notch")
            subtext: Config.notch.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(11)
        }

        NavRow {
            icon: "dock_to_right"
            text: Tr.tr("Sidebar")
            subtext: Config.sidebar.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(4)
        }

        NavRow {
            icon: "construction"
            text: Tr.tr("Utilities")
            subtext: Config.utilities.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(5)
        }

        NavRow {
            icon: "grid_view"
            text: Tr.tr("Overview")
            subtext: Config.overview.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(12)
        }

        NavRow {
            icon: "logout"
            text: Tr.tr("Session menu")
            subtext: Config.session.enabled ? Tr.trCtx("Enabled", "panel status") : Tr.trCtx("Disabled", "panel status")
            onClicked: root.nState.openSubPage(16)
        }

        NavRow {
            last: true
            icon: "lock"
            text: Tr.tr("Lock screen")
            onClicked: root.nState.openSubPage(14)
        }

        // Screen corners
        SectionHeader {
            text: Tr.tr("Hot corners")
        }

        // The section sits well down a long page, and with the menus preferring the side with no room
        // they flip back and forth chasing their own height, so above is pinned as the preference here
        // the way the last row of the services page does
        SelectRow {
            first: true
            label: Tr.tr("Top left")
            subtext: Tr.tr("Hold the pointer in the top-left corner of the screen")
            menuOnTop: true
            fallbackIcon: "north_west"
            menuItems: root.cornerItems
            active: root.cornerItems[Config.hotCorners.topLeft]
            onSelected: item => GlobalConfig.hotCorners.topLeft = root.cornerItems.indexOf(item)
        }

        SelectRow {
            label: Tr.tr("Top right")
            subtext: Tr.tr("Hold the pointer in the top-right corner of the screen")
            menuOnTop: true
            fallbackIcon: "north_east"
            menuItems: root.cornerItems
            active: root.cornerItems[Config.hotCorners.topRight]
            onSelected: item => GlobalConfig.hotCorners.topRight = root.cornerItems.indexOf(item)
        }

        SelectRow {
            label: Tr.tr("Bottom left")
            subtext: Tr.tr("Hold the pointer in the bottom-left corner of the screen")
            menuOnTop: true
            fallbackIcon: "south_west"
            menuItems: root.cornerItems
            active: root.cornerItems[Config.hotCorners.bottomLeft]
            onSelected: item => GlobalConfig.hotCorners.bottomLeft = root.cornerItems.indexOf(item)
        }

        SelectRow {
            label: Tr.tr("Bottom right")
            subtext: Tr.tr("Hold the pointer in the bottom-right corner of the screen")
            menuOnTop: true
            fallbackIcon: "south_east"
            menuItems: root.cornerItems
            active: root.cornerItems[Config.hotCorners.bottomRight]
            onSelected: item => GlobalConfig.hotCorners.bottomRight = root.cornerItems.indexOf(item)
        }

        StepperRow {
            last: true
            label: Tr.tr("Corner size")
            subtext: Tr.tr("How far into the corner the pointer has to be, in pixels")
            value: GlobalConfig.hotCorners.size
            from: 2
            to: 40
            stepSize: 2
            onMoved: v => GlobalConfig.hotCorners.size = v
        }

        // What sits on the wallpaper
        SectionHeader {
            text: Tr.tr("Wallpaper")
        }

        NavRow {
            first: true
            icon: "apps"
            text: Tr.tr("Desktop")
            subtext: Tr.tr("App shortcuts on the wallpaper")
            onClicked: root.nState.openSubPage(13)
        }

        NavRow {
            icon: "widgets"
            text: Tr.tr("Widgets")
            subtext: Tr.tr("The widget cards shown on the wallpaper")
            onClicked: root.nState.openSubPage(18)
        }

        ToggleRow {
            last: !GlobalConfig.background.floorEqualizer.enabled
            // SEARCH: visualiser visualizer audio spectrum analyser wallpaper eq equaliser
            text: Tr.tr("Floor equalizer")
            subtext: Tr.tr("A large audio spectrum along the bottom or top of the screen")
            checked: GlobalConfig.background.floorEqualizer.enabled
            onToggled: GlobalConfig.background.floorEqualizer.enabled = checked
        }

        SelectRow {
            visible: GlobalConfig.background.floorEqualizer.enabled
            // SEARCH: ceiling top bottom floor equalizer equaliser position
            label: Tr.tr("Equalizer position")
            subtext: Tr.tr("Along the bottom of the screen, or hanging from the top")
            menuOnTop: true
            fallbackIcon: "vertical_align_bottom"
            menuItems: root.eqPositionItems
            active: root.eqPositionItems[Math.max(0, root.eqPositions.indexOf(Config.background.floorEqualizer.position ?? "floor"))]
            onSelected: item => GlobalConfig.background.floorEqualizer.position = root.eqPositions[root.eqPositionItems.indexOf(item)]
        }

        SelectRow {
            visible: GlobalConfig.background.floorEqualizer.enabled
            // SEARCH: wave line bars equalizer equaliser style mode
            label: Tr.tr("Equalizer style")
            subtext: Tr.tr("Bars, a filled wave, or just the wave's outline")
            menuOnTop: true
            fallbackIcon: "equalizer"
            menuItems: root.eqStyleItems
            active: root.eqStyleItems[Math.max(0, root.eqStyles.indexOf(Config.background.floorEqualizer.style ?? "bars"))]
            onSelected: item => GlobalConfig.background.floorEqualizer.style = root.eqStyles[root.eqStyleItems.indexOf(item)]
        }

        SliderRow {
            visible: GlobalConfig.background.floorEqualizer.enabled
            icon: "height"
            // SEARCH: amplitude height size tall equalizer equaliser
            label: Tr.tr("Equalizer amplitude")
            valueLabel: `${Math.round((Config.background.floorEqualizer.amplitude ?? 1) * 100)}%`
            value: Config.background.floorEqualizer.amplitude ?? 1
            from: 0.5
            to: 3
            stepSize: 0.1
            onMoved: v => GlobalConfig.background.floorEqualizer.amplitude = Math.round(v * 10) / 10
        }

        SliderRow {
            visible: GlobalConfig.background.floorEqualizer.enabled
            icon: "airwave"
            // SEARCH: smoothness smooth smoothing responsive snappy speed equalizer equaliser
            label: Tr.tr("Equalizer smoothness")
            valueLabel: `${Math.round((Config.background.floorEqualizer.smoothness ?? 1) * 100)}%`
            value: Config.background.floorEqualizer.smoothness ?? 1
            from: 0
            to: 2
            stepSize: 0.1
            onMoved: v => GlobalConfig.background.floorEqualizer.smoothness = Math.round(v * 10) / 10
        }

        ToggleRow {
            visible: GlobalConfig.background.floorEqualizer.enabled
            last: true
            // SEARCH: hide silent silence quiet idle equalizer equaliser auto
            text: Tr.tr("Hide when silent")
            subtext: Tr.tr("Fade the equalizer out while no audio is playing")
            checked: Config.background.floorEqualizer.autoHide ?? true
            onToggled: GlobalConfig.background.floorEqualizer.autoHide = checked
        }
    }
}
