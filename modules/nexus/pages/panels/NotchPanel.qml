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

        NavRow {
            first: true
            last: true
            icon: "dashboard_customize"
            text: Tr.tr("Alignment")
            subtext: Tr.tr("Currently %1 — change it, and everything else's position, in Layout").arg(root.alignNames[Config.notch.align] ?? root.alignNames[0])
            onClicked: root.nState.currentPageIdx = PageRegistry.indexOfKey("layout")
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
            text: Tr.tr("Show music")
            subtext: Tr.tr("Show the playing track in the notch alongside the clock")
            checked: Config.notch.showMusic
            onToggled: GlobalConfig.notch.showMusic = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show timer")
            subtext: Tr.tr("Show a running countdown in the notch alongside the clock")
            checked: Config.notch.showTimer
            onToggled: GlobalConfig.notch.showTimer = checked
        }

        // Dynamic island
        SectionHeader {
            text: Tr.tr("Dynamic island")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Show lock keys")
            subtext: Tr.tr("Drop the notch down to say when caps lock or num lock changes, in place of a toast")
            checked: Config.notch.showKeyLocks
            onToggled: GlobalConfig.notch.showKeyLocks = checked
        }

        StepperRow {
            label: Tr.tr("Lock key duration")
            // TRANSLATORS: ms is the millisecond unit, leave it untranslated
            subtext: Tr.tr("How long the notch says a lock key changed for (ms)")
            value: Config.notch.keyLockDuration
            from: 500
            to: 5000
            stepSize: 100
            onMoved: v => GlobalConfig.notch.keyLockDuration = Math.round(v)
        }

        ToggleRow {
            text: Tr.tr("Show notifications")
            subtext: Tr.tr("Show notifications as they arrive in the notch")
            checked: Config.notch.showNotifs
            onToggled: GlobalConfig.notch.showNotifs = checked
        }

        ToggleRow {
            text: Tr.tr("Replace popups")
            subtext: Tr.tr("Skip the corner popup for what the notch has shown; notifications still wait in the notification centre")
            checked: Config.notch.notifsTakeOver
            enabled: Config.notch.showNotifs
            onToggled: GlobalConfig.notch.notifsTakeOver = checked
        }

        StepperRow {
            label: Tr.tr("Notification duration")
            // TRANSLATORS: ms is the millisecond unit, leave it untranslated
            subtext: Tr.tr("How long a notification stays in the notch (ms)")
            value: Config.notch.notifDuration
            from: 1000
            to: 15000
            stepSize: 500
            onMoved: v => GlobalConfig.notch.notifDuration = Math.round(v)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Authentication prompt")
            subtext: Tr.tr("Ask for a password in a panel dropping out of the notch instead of a card in the middle of the screen")
            checked: Config.notch.showPolkit
            onToggled: GlobalConfig.notch.showPolkit = checked
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

        ToggleRow {
            text: Tr.tr("Artist first")
            subtext: Tr.tr("\"Artist - Title\" instead of \"Title - Artist\"")
            checked: Config.notch.artistFirst
            enabled: Config.notch.showArtist
            onToggled: GlobalConfig.notch.artistFirst = checked
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
