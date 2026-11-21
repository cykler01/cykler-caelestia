pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
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

    readonly property list<MenuItem> sideItems: [
        MenuItem {
            text: Tr.tr("Left")
        },
        MenuItem {
            text: Tr.tr("Right")
        }
    ]
    readonly property string layoutId: Config.lock.layout ?? "card"
    readonly property bool sidedLayout: layoutId === "split" || layoutId === "sidebar"
    readonly property bool cardLayout: !sidedLayout && layoutId !== "minimal"

    title: Tr.tr("Lock screen")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // NOTE(fork): which arrangement the lock screen uses (modules/lock/LockSurface.qml)
        SectionHeader {
            first: true
            text: Tr.tr("Layout")
        }

        LockLayoutPicker {
            first: true
            last: root.cardLayout
        }

        SelectRow {
            visible: root.sidedLayout
            // SEARCH: left right edge mirror flip
            label: Tr.tr("Login side")
            subtext: root.layoutId === "sidebar" ? Tr.tr("Which edge the panel sits against") : Tr.tr("Which side the login card sits on, with the clock opposite")
            menuItems: root.sideItems
            active: root.sideItems[(Config.lock.panelSide ?? "right") === "left" ? 0 : 1]
            onSelected: item => GlobalConfig.lock.panelSide = root.sideItems.indexOf(item) === 0 ? "left" : "right"
        }

        ToggleRow {
            visible: !root.cardLayout
            last: true
            // SEARCH: battery wifi bluetooth chips pills status
            text: Tr.tr("Status pills")
            subtext: Tr.tr("Small pills along the top of the screen, picked below")
            checked: Config.lock.statusChips ?? true
            onToggled: GlobalConfig.lock.statusChips = checked
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.small
            visible: !root.cardLayout && (Config.lock.statusChips ?? true)
            text: Tr.tr("Which pills show, in order from the screen's edge inwards. Switch one off to hide it, or add more below. A pill with nothing to report (no battery, nothing playing) hides itself.")
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
            visible: !root.cardLayout && (Config.lock.statusChips ?? true)
            values: GlobalConfig.lock.statusEntries.values
            onItemMoved: (from, to) => GlobalConfig.lock.statusEntries.move(from, to)
            onItemRemoved: index => GlobalConfig.lock.statusEntries.remove(index)
            onItemToggled: (index, checked) => GlobalConfig.lock.statusEntries.at(index).enabled = checked
        }

        DialogSelectButton {
            visible: !root.cardLayout && (Config.lock.statusChips ?? true)
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

        // Clock
        SectionHeader {
            visible: root.cardLayout
            text: Tr.tr("Clock")
        }

        ToggleRow {
            visible: root.cardLayout
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
            text: Tr.tr("Use the wallpaper")
            subtext: Tr.tr("Show the wallpaper rather than a capture of the session behind it")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
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

        // Side widgets
        SectionHeader {
            text: Tr.tr("Widgets")
        }

        NavRow {
            first: true
            last: true
            icon: "widgets"
            text: Tr.tr("Widgets")
            subtext: root.layoutId === "minimal" ? Tr.tr("The minimal layout shows no widgets") : Tr.tr("Reorder, resize and show or hide what's on the side columns")
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
