pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    // Auto-clear times, ordered to match config::TodoClearAfter (Never, FiveMinutes, OneDay,
    // SevenDays, EndOfWeek)
    readonly property list<MenuItem> clearCompletedItems: [
        MenuItem {
            text: Tr.trCtx("Never", "auto-clear completed tasks")
        },
        MenuItem {
            text: Tr.tr("5 minutes")
        },
        MenuItem {
            text: Tr.tr("1 day")
        },
        MenuItem {
            text: Tr.tr("7 days")
        },
        MenuItem {
            text: Tr.tr("End of week")
        }
    ]

    title: Tr.tr("Sidebar")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("General")
        }

        ToggleRow {
            first: true
            text: Tr.trCtx("Enabled", "toggle label")
            checked: Config.sidebar.enabled
            onToggled: GlobalConfig.sidebar.enabled = checked
        }

        ToggleRow {
            text: Tr.tr("Full height")
            subtext: Tr.tr("Keep the utilities panel closed with the sidebar, so it spans the whole screen height")
            checked: Config.sidebar.fullHeight
            onToggled: GlobalConfig.sidebar.fullHeight = checked
        }

        ToggleRow {
            text: Tr.tr("Show on hover")
            subtext: Tr.tr("Reveal when the cursor reaches the screen edge, near the top")
            checked: Config.sidebar.showOnHover
            onToggled: GlobalConfig.sidebar.showOnHover = checked
        }

        StepperRow {
            visible: Config.sidebar.showOnHover
            label: Tr.tr("Hover trigger height")
            subtext: Tr.tr("How far down the edge triggers it, in pixels")
            value: Config.sidebar.minHoverThreshold
            from: 50
            to: 600
            stepSize: 25
            onMoved: v => GlobalConfig.sidebar.minHoverThreshold = v
        }

        StepperRow {
            label: Tr.tr("Drag threshold")
            subtext: Tr.tr("Pixels dragged before the sidebar opens")
            value: Config.sidebar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.sidebar.dragThreshold = v
        }

        SectionHeader {
            text: Tr.tr("Tabs")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Music")
            subtext: Tr.tr("Show the local music library as a tab")
            checked: Config.sidebar.music ?? true
            onToggled: GlobalConfig.sidebar.music = checked
        }

        ToggleRow {
            text: Tr.tr("Checklist")
            subtext: Tr.tr("Show the to-do list as a tab")
            checked: Config.sidebar.todo ?? true
            onToggled: GlobalConfig.sidebar.todo = checked
        }

        SelectRow {
            visible: Config.sidebar.todo
            label: Tr.tr("Clear completed after")
            subtext: Tr.tr("Remove checked-off tasks once they have been done for this long")
            menuItems: root.clearCompletedItems
            active: root.clearCompletedItems[Config.sidebar.clearCompletedAfter]
            onSelected: item => GlobalConfig.sidebar.clearCompletedAfter = root.clearCompletedItems.indexOf(item)
        }

        ToggleRow {
            text: Tr.tr("Notes")
            subtext: Tr.tr("Show the notepad as a tab")
            checked: Config.sidebar.notes ?? true
            onToggled: GlobalConfig.sidebar.notes = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("AI chat")
            subtext: Tr.tr("Show a chat tab that saves conversations; it uses the provider and key set in the Launcher settings")
            checked: Config.sidebar.aiChat ?? false
            onToggled: GlobalConfig.sidebar.aiChat = checked
        }

        // Dino game
        SectionHeader {
            text: Tr.tr("Notifications")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Dino game")
            subtext: Tr.tr("Play the Chrome dino game with space while the notifications tab is empty")
            checked: Config.sidebar.dinoGame
            onToggled: GlobalConfig.sidebar.dinoGame = checked
        }
    }
}
