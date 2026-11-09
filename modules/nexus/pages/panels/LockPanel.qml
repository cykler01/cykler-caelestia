pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var builtinEntries: ({
            logout: Tr.tr("Log out"),
            shutdown: Tr.tr("Shut down"),
            sleep: Tr.tr("Sleep"),
            reboot: Tr.tr("Reboot")
        })

    title: Tr.tr("Lock screen")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Clock
        SectionHeader {
            first: true
            text: Tr.tr("Clock")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Analogue clock")
            subtext: Tr.tr("Show an analogue dial instead of the digital readout")
            checked: GlobalConfig.lock.analogueClock
            onToggled: GlobalConfig.lock.analogueClock = checked
        }

        // Background
        SectionHeader {
            text: Tr.tr("Background")
        }

        // NOTE(fork): the setting already existed but had no way to reach it short of editing
        // the config by hand, which matters more now that the UI above it can fade away and
        // leave the background filling the screen on its own
        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Use the wallpaper")
            subtext: Tr.tr("Show the wallpaper rather than a capture of the session behind it")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        // Idle
        SectionHeader {
            text: Tr.tr("Idle")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Hide when idle")
            subtext: Tr.tr("Fade everything but the background away until the screen is touched again")
            checked: Config.lock.hideIdle
            onToggled: GlobalConfig.lock.hideIdle = checked
        }

        StepperRow {
            last: true
            visible: Config.lock.hideIdle
            label: Tr.tr("Hide after")
            subtext: Tr.tr("Seconds without input before it hides")
            value: Config.lock.hideIdleDelay
            from: 5
            to: 300
            stepSize: 5
            onMoved: v => GlobalConfig.lock.hideIdleDelay = v
        }

        // Profile picture
        SectionHeader {
            text: Tr.tr("Profile picture")
        }

        // Opens a grid dialog with a rendered preview of every shape, instead of the bare text
        // dropdown this used to be (the list was unreadably long and gave no visual cues)
        ProfileShapePicker {
            first: true
            rootParent: root.flickable
        }

        SectionHeader {
            text: Tr.tr("Greeting")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Shown above the password field. Available pieces: {icon} (time-of-day icon), {weather_icon} (current weather icon), {greeting} (the wording below) and {user}. Anything else you type stays exactly where you put it, spaces included, so this is what controls the order and spacing too.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        TextFieldRow {
            first: true
            last: true
            label: Tr.tr("Layout")
            value: LockGreeting.format
            placeholderText: LockGreeting.defaultFormat
            onEditingFinished: value => LockGreeting.setFormat(value)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("Wording for {greeting} by time of day. Leave one blank to use its default - the username is never part of these, only the format above.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Morning")
            subtext: Tr.tr("05:00–11:59")
            value: LockGreeting.morning
            placeholderText: Tr.tr("Good morning")
            onEditingFinished: value => LockGreeting.set("morning", value)
        }

        TextFieldRow {
            label: Tr.tr("Afternoon")
            subtext: Tr.tr("12:00–16:59")
            value: LockGreeting.afternoon
            placeholderText: Tr.tr("Good afternoon")
            onEditingFinished: value => LockGreeting.set("afternoon", value)
        }

        TextFieldRow {
            label: Tr.tr("Evening")
            subtext: Tr.tr("17:00–20:59")
            value: LockGreeting.evening
            placeholderText: Tr.tr("Good evening")
            onEditingFinished: value => LockGreeting.set("evening", value)
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Night")
            subtext: Tr.tr("21:00–04:59")
            value: LockGreeting.night
            placeholderText: Tr.tr("Good night")
            onEditingFinished: value => LockGreeting.set("night", value)
        }

        // Session controls
        SectionHeader {
            text: Tr.tr("Session controls")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Reveal on the lock screen")
            subtext: Tr.tr("Show the buttons below when hovering the lock screen")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("What the revealed controls offer, left to right, and in what order. Switch one off to keep it from showing.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.builtinEntries[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: GlobalConfig.lock.entries.values
            onItemMoved: (from, to) => GlobalConfig.lock.entries.move(from, to)
            onItemRemoved: index => GlobalConfig.lock.entries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.lock.entries.at(index).enabled = checked
        }

        DialogSelectButton {
            id: addItemContainer

            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add entry")
            header: Tr.tr("Add new entry")
            acceptLabel: Tr.trCtx("Add", "button")

            model: Object.keys(root.builtinEntries).map(k => ({
                        id: k,
                        label: root.builtinEntries[k]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;

                GlobalConfig.lock.entries.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
        }

        // Side widgets
        SectionHeader {
            text: Tr.tr("Widgets")
        }

        NavRow {
            first: true
            last: true
            icon: "widgets"
            text: Tr.tr("Widgets")
            subtext: Tr.tr("Reorder, resize and show or hide what's on the side columns")
            onClicked: root.nState.openSubPage(17)
        }

        // Dino game
        SectionHeader {
            text: Tr.tr("Notifications")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Dino game")
            subtext: Tr.tr("Play the Chrome dino game by clicking the empty notifications dock")
            checked: Config.lock.dinoGame
            onToggled: GlobalConfig.lock.dinoGame = checked
        }
    }
}
