pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common
import qs.modules.nexus.pages.assets

PageBase {
    id: root

    readonly property var builtinEntries: ({
            logout: Tr.tr("Log out"),
            shutdown: Tr.tr("Shut down"),
            sleep: Tr.tr("Sleep"),
            reboot: Tr.tr("Reboot")
        })

    // The status pills the free-standing layouts can show (modules/lock/layouts/StatusChips.qml)
    readonly property var statusNames: ({
            battery: Tr.tr("Battery"),
            network: Tr.tr("Network"),
            bluetooth: Tr.tr("Bluetooth"),
            volume: Tr.tr("Volume"),
            mic: Tr.tr("Microphone"),
            vpn: Tr.tr("VPN"),
            keyboard: Tr.tr("Keyboard layout"),
            notifs: Tr.tr("Notifications"),
            media: Tr.tr("Now playing"),
            power: Tr.tr("Power profile"),
            uptime: Tr.tr("Uptime")
        })

    title: Tr.tr("Lock screen")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // NOTE(fork): what's on the lock screen and where (Config.lock.elements), arranged in the
        // full-screen editor (modules/lockeditor) rather than here
        SectionHeader {
            first: true
            text: Tr.tr("Layout")
        }

        ConnectedRect {
            first: true
            // SEARCH: layout arrange move elements editor preset clock position widgets
            searchLabel: Tr.tr("Edit layout")
            Layout.fillWidth: true
            implicitHeight: layoutColumn.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: layoutColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                LockScreenPreview {
                    Layout.fillWidth: true
                    screenHeight: root.nState.screen?.height ?? 1080
                    screenWidth: root.nState.screen?.width ?? 1920
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Everything on the lock screen is an element you can move, resize, restyle or remove, apart from the password field. Start from one of the presets or build your own.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                    wrapMode: Text.WordWrap
                }
            }
        }

        NavRow {
            last: true
            icon: "edit"
            text: Tr.tr("Edit layout")
            subtext: Tr.tr("Opens the lock screen full size over this screen to arrange it")
            onClicked: ShellState.lockEditorOpen = true
        }

        // The pills the status element shows
        SectionHeader {
            text: Tr.tr("Status pills")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            text: Tr.tr("What the Status pills element shows, in order from its outer end inwards. Switch one off to hide it, or add more below. A pill with nothing to report (no battery, nothing playing) hides itself.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        ListEditor {
            function labelFor(item: var): string {
                return root.statusNames[item.id] ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            z: 1
            first: true
            values: GlobalConfig.lock.statusEntries.values
            onItemMoved: (from, to) => GlobalConfig.lock.statusEntries.move(from, to)
            onItemRemoved: index => GlobalConfig.lock.statusEntries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.lock.statusEntries.at(index).enabled = checked
        }

        DialogSelectButton {
            rootParent: root.flickable
            icon: "add"
            label: Tr.tr("Add pill")
            header: Tr.tr("Add a status pill")
            acceptLabel: Tr.trCtx("Add", "button")

            // Only the pills that aren't in the list already
            model: Object.keys(root.statusNames).filter(id => !GlobalConfig.lock.statusEntries.values.some(e => e.id === id)).map(id => ({
                        id: id,
                        label: root.statusNames[id]
                    }))

            onAccepted: {
                if (!selectedItem)
                    return;

                GlobalConfig.lock.statusEntries.insert({
                    id: selectedItem,
                    enabled: true
                });
            }
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
            text: Tr.tr("Use the wallpaper")
            subtext: (Config.lock.wallpaper ?? "") !== "" ? Tr.tr("Not used while a lock screen wallpaper is set below") : Tr.tr("Show the wallpaper rather than a capture of the session behind it")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        // NOTE(fork): a wallpaper for the lock screen alone, chosen through the same row the
        // asset images use (pages/assets/AssetRow.qml), which copies the file into the shell's
        // data directory and offers the reset
        AssetRow {
            // SEARCH: wallpaper background image picture lock screen separate different
            label: Tr.tr("Lock screen wallpaper")
            subtext: Tr.tr("Shown only on the lock screen, in place of the desktop wallpaper")
            option: "lockWallpaper"
            value: GlobalConfig.lock.wallpaper ?? ""
            defaultValue: ""
            defaultLabel: Tr.tr("None, using the setting above")
            previewSource: Paths.absolutePath(GlobalConfig.lock.wallpaper ?? "")
            startFolder: Paths.wallsdir
            fallbackIcon: "wallpaper"
            write: v => GlobalConfig.lock.wallpaper = v
            reset: () => GlobalConfig.lock.wallpaper = ""
        }

        SliderRow {
            last: true
            icon: "blur_on"
            // SEARCH: blur blurry sharp frosted background strength
            label: Tr.tr("Blur")
            valueLabel: `${Math.round((Config.lock.blur ?? 1) * 100)}%`
            value: Config.lock.blur ?? 1
            from: 0
            to: 1
            stepSize: 0.05
            onMoved: v => GlobalConfig.lock.blur = Math.round(v * 100) / 100
        }

        // Idle
        SectionHeader {
            text: Tr.tr("Idle")
        }

        ToggleRow {
            first: true
            // SEARCH: timeout dim away afk
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
            subtext: root.cardLayout ? Tr.tr("Show the buttons below when hovering the lock screen") : Tr.tr("Show the buttons below in a bar in the corner of the lock screen")
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
