pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<string> alignNames: [
        Tr.trCtx("Left", "panel alignment"),
        Tr.trCtx("Centre", "panel alignment"),
        Tr.trCtx("Right", "panel alignment")
    ]

    readonly property list<string> edgeNames: [
        Tr.trCtx("Top", "panel edge"),
        Tr.trCtx("Bottom", "panel edge")
    ]

    // Ordered to match config::PerfGraphColours (Scheme, Vibrant, Monochrome, Custom)
    readonly property list<MenuItem> graphColourItems: [
        MenuItem {
            text: Tr.trCtx("Scheme", "performance graph colours")
            icon: "palette"
        },
        MenuItem {
            text: Tr.trCtx("Vibrant", "performance graph colours")
            icon: "looks"
        },
        MenuItem {
            text: Tr.trCtx("Monochrome", "performance graph colours")
            icon: "contrast"
        },
        MenuItem {
            text: Tr.trCtx("Custom", "performance graph colours")
            icon: "colorize"
        }
    ]

    title: Tr.tr("Dashboard")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.dashboard.enabled
            onToggled: GlobalConfig.dashboard.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge")
            checked: Config.dashboard.showOnHover
            onToggled: GlobalConfig.dashboard.showOnHover = checked
        }

        ToggleRow {
            text: Tr.tr("Analogue clock")
            subtext: Tr.tr("Show an analogue dial instead of the digital readout")
            checked: Config.dashboard.analogueClock
            onToggled: GlobalConfig.dashboard.analogueClock = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show clock seconds")
            subtext: Tr.tr("Display seconds for the clock in the main panel")
            checked: Config.dashboard.showClockSeconds
            onToggled: GlobalConfig.dashboard.showClockSeconds = checked
        }

        // Profile picture
        SectionHeader {
            text: Tr.tr("Profile picture")
        }

        ProfileShapePicker {
            first: true
            rootParent: root.flickable
            profileConfig: GlobalConfig.dashboard
        }

        // Position
        SectionHeader {
            text: Tr.tr("Position")
        }

        NavRow {
            first: true
            last: true
            icon: "dashboard_customize"
            text: Tr.tr("Screen position")
            subtext: Tr.tr("Currently %1 — change it, and everything else's position, in Layout").arg(`${root.edgeNames[Config.dashboard.edge] ?? root.edgeNames[0]} · ${root.alignNames[Config.dashboard.align] ?? root.alignNames[0]}`)
            onClicked: root.nState.currentPageIdx = PageRegistry.indexOfKey("layout")
        }

        // Tabs
        SectionHeader {
            text: Tr.tr("Tabs")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Dashboard")
            checked: Config.dashboard.showDashboard
            onToggled: GlobalConfig.dashboard.showDashboard = checked
        }

        ToggleRow {
            text: Tr.tr("Media")
            checked: Config.dashboard.showMedia
            onToggled: GlobalConfig.dashboard.showMedia = checked
        }

        ToggleRow {
            text: Tr.tr("Performance")
            checked: Config.dashboard.showPerformance
            onToggled: GlobalConfig.dashboard.showPerformance = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Weather")
            checked: Config.dashboard.showWeather
            onToggled: GlobalConfig.dashboard.showWeather = checked
        }

        // Performance widgets
        SectionHeader {
            text: Tr.tr("Performance widgets")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Graph view")
            subtext: Tr.tr("One graph with 2 minutes of history. Off uses the original cards")
            checked: Config.dashboard.performance.graphView
            onToggled: GlobalConfig.dashboard.performance.graphView = checked
        }

        SelectRow {
            label: Tr.tr("Graph colours")
            subtext: Tr.tr("Scheme uses the current colour scheme; Vibrant uses its terminal colours")
            menuItems: root.graphColourItems
            active: root.graphColourItems[GlobalConfig.dashboard.performance.graphColours] ?? root.graphColourItems[0]
            onSelected: item => GlobalConfig.dashboard.performance.graphColours = root.graphColourItems.indexOf(item)
        }

        GraphColourRow {
            visible: GlobalConfig.dashboard.performance.graphColours === PerfGraphColours.Custom
            label: Tr.tr("CPU colour")
            value: GlobalConfig.dashboard.performance.cpuColour
            onPicked: v => GlobalConfig.dashboard.performance.cpuColour = v
        }

        GraphColourRow {
            visible: GlobalConfig.dashboard.performance.graphColours === PerfGraphColours.Custom
            label: Tr.tr("GPU colour")
            value: GlobalConfig.dashboard.performance.gpuColour
            onPicked: v => GlobalConfig.dashboard.performance.gpuColour = v
        }

        GraphColourRow {
            visible: GlobalConfig.dashboard.performance.graphColours === PerfGraphColours.Custom
            label: Tr.tr("Memory colour")
            value: GlobalConfig.dashboard.performance.memoryColour
            onPicked: v => GlobalConfig.dashboard.performance.memoryColour = v
        }

        GraphColourRow {
            visible: GlobalConfig.dashboard.performance.graphColours === PerfGraphColours.Custom
            label: Tr.tr("Network colour")
            value: GlobalConfig.dashboard.performance.networkColour
            onPicked: v => GlobalConfig.dashboard.performance.networkColour = v
        }

        GraphColourRow {
            visible: GlobalConfig.dashboard.performance.graphColours === PerfGraphColours.Custom
            label: Tr.tr("Storage colour")
            value: GlobalConfig.dashboard.performance.storageColour
            onPicked: v => GlobalConfig.dashboard.performance.storageColour = v
        }

        ToggleRow {
            text: Tr.tr("Battery")
            checked: Config.dashboard.performance.showBattery
            onToggled: GlobalConfig.dashboard.performance.showBattery = checked
        }

        ToggleRow {
            text: Tr.tr("GPU")
            checked: Config.dashboard.performance.showGpu
            onToggled: GlobalConfig.dashboard.performance.showGpu = checked
        }

        ToggleRow {
            text: Tr.tr("CPU")
            checked: Config.dashboard.performance.showCpu
            onToggled: GlobalConfig.dashboard.performance.showCpu = checked
        }

        ToggleRow {
            text: Tr.tr("Memory")
            checked: Config.dashboard.performance.showMemory
            onToggled: GlobalConfig.dashboard.performance.showMemory = checked
        }

        ToggleRow {
            text: Tr.tr("Storage")
            subtext: Tr.tr("Disk usage on the Dashboard and Performance tabs")
            checked: Config.dashboard.performance.showStorage
            onToggled: GlobalConfig.dashboard.performance.showStorage = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Network")
            checked: Config.dashboard.performance.showNetwork
            onToggled: GlobalConfig.dashboard.performance.showNetwork = checked
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        StepperRow {
            first: true
            last: true
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the dashboard opens")
            value: Config.dashboard.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.dashboard.dragThreshold = v
        }
    }
}
