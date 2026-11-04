pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

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
