import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    //
    // Apps are picked off the installed ones rather than typed (see the picker below), and what is
    // stored is the name the app shows under, which is what a notification carries and what the
    // island matches against. Typing one by hand is still there for what has no desktop entry at
    // all - a script, anything else that only ever speaks through notify-send.
    readonly property var installedApps: [...DesktopEntries.applications.values].filter(a => !a.noDisplay).map(a => ({
                id: a.name,
                label: a.name,
                icon: a.icon
            })).filter((a, i, all) => all.findIndex(o => o.id === a.id) === i).sort((a, b) => a.label.localeCompare(b.label))

    function appEntryFor(name: string): var {
        return DesktopEntries.heuristicLookup(name);
    }

    function addNotifApp(name: string): void {
        const trimmed = (name ?? "").trim();
        if (!trimmed)
            return;

        const apps = Config.notch.notifApps;
        if (apps.some(a => a.toLowerCase() === trimmed.toLowerCase()))
            return;

        GlobalConfig.notch.notifApps = [...apps, trimmed];
    }

    function addTypedNotifApp(): void {
        root.addNotifApp(notifAppInput.text);
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
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Only the apps listed here come to the notch; with none listed every notification stays in the corner. Names are matched against what an app puts on its notifications, ignoring case.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            id: notifAppList

            model: Config.notch.notifApps

            ConnectedRect {
                id: appRow

                required property string modelData
                required property int index

                readonly property var entry: root.appEntryFor(appRow.modelData)

                Layout.fillWidth: true
                first: appRow.index === 0
                last: false
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

                    // Nothing is installed under that name when it was typed in for a script or
                    // some other notify-send caller, which simply leaves the row without a picture
                    IconImage {
                        visible: (appRow.entry?.icon ?? "") !== ""
                        asynchronous: true
                        implicitSize: Math.round(Tokens.font.icon.large.pointSize * 1.8)
                        source: visible ? Quickshell.iconPath(appRow.entry.icon, "image-missing") : ""
                    }

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

        // Picked off the installed apps rather than typed
        DialogSelectButton {
            rootParent: root.flickable
            first: notifAppList.count === 0
            icon: "add"
            label: Tr.tr("Add application")
            header: Tr.tr("Show notifications from")
            acceptLabel: Tr.trCtx("Add", "button")

            model: root.installedApps

            onAccepted: root.addNotifApp(selectedItem)
        }

        // For anything with no desktop entry to pick: a script, or an app whose notifications come
        // under a different name than the one it is installed as
        ConnectedRect {
            last: true

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
                    placeholderText: Tr.tr("Or a name to match, for an app that is not installed")
                    leadingIcon: "apps"
                    verticalPadding: Tokens.padding.small

                    onAccepted: root.addTypedNotifApp()
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Filled
                    disabled: !notifAppInput.text.trim()
                    onClicked: root.addTypedNotifApp()
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
