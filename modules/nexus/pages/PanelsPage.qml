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

        // A plain ambient clock, not a lock - see modules/standby
        SectionHeader {
            text: Tr.tr("Standby")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Show date")
            subtext: Tr.tr("Toggle with the standby keybind (Settings > Keybinds), on whichever screen has focus")
            checked: GlobalConfig.general.standby.showDate
            onToggled: GlobalConfig.general.standby.showDate = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show currently playing")
            subtext: Tr.tr("Cover, title and artist, if something is playing")
            checked: GlobalConfig.general.standby.showMusic
            onToggled: GlobalConfig.general.standby.showMusic = checked
        }

        // What sits on the wallpaper
        SectionHeader {
            text: Tr.tr("Wallpaper")
        }

        NavRow {
            first: true
            last: true
            icon: "widgets"
            text: Tr.tr("Desktop")
            subtext: Tr.tr("App shortcuts and widgets on the wallpaper")
            onClicked: root.nState.openSubPage(13)
        }
    }
}
