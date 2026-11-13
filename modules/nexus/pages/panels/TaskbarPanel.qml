pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    // Ordered to match config::BarPosition (Left, Right, Top, Bottom)
    readonly property list<string> positionNames: [
        Tr.trCtx("Left", "bar position"),
        Tr.trCtx("Right", "bar position"),
        Tr.trCtx("Top", "bar position"),
        Tr.trCtx("Bottom", "bar position")
    ]

    title: Tr.tr("Taskbar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Placement
        SectionHeader {
            first: true
            text: Tr.tr("Placement")
        }

        NavRow {
            first: true
            icon: "dashboard_customize"
            // SEARCH: position side left right top bottom move
            text: Tr.tr("Screen edge")
            subtext: Tr.tr("Currently %1 — change it, and everything else's position, in Layout").arg(root.positionNames[Config.bar.position] ?? root.positionNames[0])
            onClicked: root.nState.currentPageIdx = PageRegistry.indexOfKey("layout")
        }

        ToggleRow {
            last: true
            text: Tr.tr("Mirror panels with a right-hand bar")
            subtext: Tr.tr("When the bar is on the right, open the volume/brightness bars, notifications, sidebar and session menu on the left")
            checked: Config.bar.mirrorPanels
            onToggled: GlobalConfig.bar.mirrorPanels = checked
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Persistent")
            subtext: Tr.tr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: Tr.tr("Hide middle on desktop")
            subtext: Tr.tr("On an empty workspace, remove the stretch of the bar between its two ends so the wallpaper shows through")
            checked: Config.bar.hideMiddleOnDesktop
            onToggled: GlobalConfig.bar.hideMiddleOnDesktop = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Components
        SectionHeader {
            text: Tr.tr("Components")
        }

        NavRow {
            first: true
            icon: "reorder"
            text: Tr.tr("Layout")
            subtext: Tr.tr("What's shown, and in what order")
            onClicked: root.nState.openSubPage(15)
        }

        NavRow {
            icon: "workspaces"
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            text: Tr.tr("Active window")
            subtext: Tr.tr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            text: Tr.tr("Tray")
            subtext: Tr.tr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            text: Tr.tr("Status icons")
            subtext: Tr.tr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            last: true
            icon: "schedule"
            text: Tr.tr("Clock")
            subtext: Tr.tr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        // Scroll actions
        SectionHeader {
            text: Tr.tr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Workspaces")
            subtext: Tr.tr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: Tr.tr("Volume")
            subtext: Tr.tr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            text: Tr.tr("Brightness")
            subtext: Tr.tr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }

        NavRow {
            last: true
            icon: "tune"
            text: Tr.tr("Step size")
            subtext: Tr.tr("How much each scroll changes - shared with the volume/brightness keys and OSD, in Services")
            onClicked: root.nState.currentPageIdx = PageRegistry.indexOfKey("services")
        }
    }
}
