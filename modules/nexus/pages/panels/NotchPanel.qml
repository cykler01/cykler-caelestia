import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> alignItems: [
        MenuItem {
            text: Tr.trCtx("Left", "panel alignment")
            icon: "align_horizontal_left"
        },
        MenuItem {
            text: Tr.trCtx("Centre", "panel alignment")
            icon: "align_horizontal_center"
        },
        MenuItem {
            text: Tr.trCtx("Right", "panel alignment")
            icon: "align_horizontal_right"
        }
    ]

    title: Tr.tr("Notch")
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
            last: true
            text: Tr.trCtx("Enabled", "toggle label")
            subtext: Tr.tr("Show a pill when the playing track changes")
            checked: Config.notch.enabled
            onToggled: GlobalConfig.notch.enabled = checked
        }

        // Position
        SectionHeader {
            text: Tr.tr("Position")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Alignment")
            subtext: Tr.tr("Where along that edge the panel sits")
            menuItems: root.alignItems
            active: root.alignItems[Config.notch.align] ?? root.alignItems[0]
            onSelected: item => GlobalConfig.notch.align = root.alignItems.indexOf(item)
        }

        // Standing notch
        SectionHeader {
            text: Tr.tr("Standing notch")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Show on empty workspace")
            subtext: Tr.tr("Keep the notch up while no tiled windows are open")
            checked: Config.notch.showOnEmptyWorkspace
            onToggled: GlobalConfig.notch.showOnEmptyWorkspace = checked
        }

        ToggleRow {
            text: Tr.tr("Show on workspaces with windows")
            subtext: Tr.tr("Keep the notch up on workspaces that have windows too, not just empty ones")
            checked: Config.notch.showWithWindows
            onToggled: GlobalConfig.notch.showWithWindows = checked
        }

        ToggleRow {
            text: Tr.tr("Show clock")
            subtext: Tr.tr("Show the time and date in the notch")
            checked: Config.notch.showClock
            onToggled: GlobalConfig.notch.showClock = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show music")
            subtext: Tr.tr("Show the playing track in the notch alongside the clock")
            checked: Config.notch.showMusic
            onToggled: GlobalConfig.notch.showMusic = checked
        }

        // Behaviour
        SectionHeader {
            text: Tr.tr("Behaviour")
        }

        StepperRow {
            first: true
            label: Tr.tr("Show duration")
            // TRANSLATORS: ms is the millisecond unit, leave it untranslated
            subtext: Tr.tr("How long the pill stays up after a track change (ms)")
            value: Config.notch.showDuration
            from: 1000
            to: 10000
            stepSize: 500
            onMoved: v => GlobalConfig.notch.showDuration = Math.round(v)
        }

        // Content
        SectionHeader {
            text: Tr.tr("Content")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Show artist")
            subtext: Tr.tr("Include the artist name alongside the title")
            checked: Config.notch.showArtist
            onToggled: GlobalConfig.notch.showArtist = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Max title width")
            // TRANSLATORS: px is the pixel unit, leave it untranslated
            subtext: Tr.tr("How wide the title can grow before eliding (px)")
            value: Config.notch.maxTitleWidth
            from: 100
            to: 600
            stepSize: 20
            onMoved: v => GlobalConfig.notch.maxTitleWidth = Math.round(v)
        }

    }
}
