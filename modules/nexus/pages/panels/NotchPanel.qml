import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<string> alignNames: [
        Tr.trCtx("Left", "panel alignment"),
        Tr.trCtx("Centre", "panel alignment"),
        Tr.trCtx("Right", "panel alignment")
    ]

    // NOTE(fork): the apps the island is for. A plain string list rather than a rule set: the
    // question here is only which apps, and an empty list leaves every popup in the corner.
    function addNotifApp(): void {
        const name = notifAppInput.text.trim();
        if (!name)
            return;

        const apps = Config.notch.notifApps;
        if (apps.some(a => a.toLowerCase() === name.toLowerCase())) {
            notifAppInput.clear();
            return;
        }

        GlobalConfig.notch.notifApps = [...apps, name];
        notifAppInput.clear();
    }

    function removeNotifApp(index: int): void {
        GlobalConfig.notch.notifApps = Config.notch.notifApps.filter((_, i) => i !== index);
    }

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
            text: Tr.tr("Show timer")
            subtext: Tr.tr("Show a running countdown in the notch alongside the clock")
            checked: Config.notch.showTimer
            onToggled: GlobalConfig.notch.showTimer = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show downloads")
            subtext: Tr.tr("Show browser and Steam downloads in the notch while any are running")
            checked: Config.notch.showDownloads
            onToggled: GlobalConfig.notch.showDownloads = checked
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

        // Which apps the island is for
        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: notifAppsRow.implicitHeight + Tokens.padding.medium * 2
            enabled: Config.notch.showNotifs

            RowLayout {
                id: notifAppsRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                StyledTextField {
                    id: notifAppInput

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("App to show in the notch, e.g. discord; none listed means none")
                    leadingIcon: "apps"
                    verticalPadding: Tokens.padding.small

                    onAccepted: root.addNotifApp()
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Filled
                    disabled: !notifAppInput.text.trim()
                    onClicked: root.addNotifApp()
                }
            }
        }

        Repeater {
            model: Config.notch.notifApps

            ConnectedRect {
                id: appRow

                required property string modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: appLayout.implicitHeight + Tokens.padding.medium * 2
                enabled: Config.notch.showNotifs

                RowLayout {
                    id: appLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: appRow.modelData
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        onClicked: root.removeNotifApp(appRow.index)
                    }
                }
            }
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
