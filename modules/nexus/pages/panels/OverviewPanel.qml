import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Overview")
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
            subtext: Tr.tr("A full-screen view of every workspace and its windows")
            checked: Config.overview.enabled
            onToggled: GlobalConfig.overview.enabled = checked
        }

        // Opening
        SectionHeader {
            text: Tr.tr("Opening")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Trackpad swipe")
            subtext: Tr.tr("Swipe up with four fingers to open it and down to close it")
            checked: GlobalConfig.overview.gestures
            onToggled: GlobalConfig.overview.gestures = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Hot corner")
            subtext: Tr.tr("Hold the pointer in the top-left corner of the screen")
            checked: Config.overview.hotCorner
            onToggled: GlobalConfig.overview.hotCorner = checked
        }

        // Workspaces
        SectionHeader {
            text: Tr.tr("Workspaces")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Only workspaces in use")
            subtext: Tr.tr("List just the workspaces with windows, the focused one and the next free one, instead of every workspace in groups of ten")
            checked: GlobalConfig.overview.onlyInUse
            onToggled: GlobalConfig.overview.onlyInUse = checked
        }
    }
}
