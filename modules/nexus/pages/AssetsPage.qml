import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus.common
import qs.modules.nexus.pages.assets

// NOTE(fork): lets the shell's own images be changed from the settings instead of by
// editing the files (or the config) by hand.
PageBase {
    id: root

    title: Tr.tr("Shell assets")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Profile picture
        SectionHeader {
            first: true
            text: Tr.tr("Profile")
        }

        // The one asset that lives in the home directory rather than the shell's assets
        AssetRow {
            first: true
            last: true
            label: Tr.tr("Profile picture")
            subtext: Tr.tr("Shown on the dashboard and the lock screen")
            targetPath: `${Paths.home}/.face`
            fallbackIcon: "person"
        }

        // Logo
        SectionHeader {
            text: Tr.tr("Logo")
        }

        AssetRow {
            first: true
            last: true
            label: Tr.tr("System logo")
            subtext: Tr.tr("Shown in the bar, dashboard and on the lock screen")
            option: "logo"
            value: GlobalConfig.general.logo
            defaultValue: GlobalConfig.general.descriptorFor("logo").defaultValue
            previewSource: SysInfo.osLogo
            write: v => GlobalConfig.general.logo = v
            reset: () => GlobalConfig.general.resetOption("logo")
        }

        // Animated images
        SectionHeader {
            text: Tr.tr("Animated images")
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Gifs played by the shell")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        AssetRow {
            first: true
            previewAnimated: true
            filters: Images.validImageExtensions.concat(["gif"])
            label: Tr.tr("Session screen gif")
            subtext: Tr.tr("Played on the power menu")
            option: "sessionGif"
            value: GlobalConfig.paths.sessionGif
            defaultValue: GlobalConfig.paths.descriptorFor("sessionGif").defaultValue
            previewSource: Paths.absolutePath(GlobalConfig.paths.sessionGif)
            write: v => GlobalConfig.paths.sessionGif = v
            reset: () => GlobalConfig.paths.resetOption("sessionGif")
        }

        AssetRow {
            last: true
            previewAnimated: true
            filters: Images.validImageExtensions.concat(["gif"])
            label: Tr.tr("Media gif")
            subtext: Tr.tr("Played on the dashboard's media tab")
            option: "mediaGif"
            value: GlobalConfig.paths.mediaGif
            defaultValue: GlobalConfig.paths.descriptorFor("mediaGif").defaultValue
            previewSource: Paths.absolutePath(GlobalConfig.paths.mediaGif)
            write: v => GlobalConfig.paths.mediaGif = v
            reset: () => GlobalConfig.paths.resetOption("mediaGif")
        }

        // Placeholder images
        SectionHeader {
            text: Tr.tr("Placeholder images")
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Images shown where a list is empty")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        AssetRow {
            first: true
            label: Tr.tr("Sidebar image")
            subtext: Tr.tr("Shown when there are no notifications")
            option: "noNotifsPic"
            value: GlobalConfig.paths.noNotifsPic
            defaultValue: GlobalConfig.paths.descriptorFor("noNotifsPic").defaultValue
            previewSource: Paths.absolutePath(GlobalConfig.paths.noNotifsPic)
            write: v => GlobalConfig.paths.noNotifsPic = v
            reset: () => GlobalConfig.paths.resetOption("noNotifsPic")
        }

        AssetRow {
            last: true
            label: Tr.tr("Lock screen image")
            subtext: Tr.tr("Shown on the lock screen when there are no notifications")
            option: "lockNoNotifsPic"
            value: GlobalConfig.paths.lockNoNotifsPic
            defaultValue: GlobalConfig.paths.descriptorFor("lockNoNotifsPic").defaultValue
            previewSource: Paths.absolutePath(GlobalConfig.paths.lockNoNotifsPic)
            write: v => GlobalConfig.paths.lockNoNotifsPic = v
            reset: () => GlobalConfig.paths.resetOption("lockNoNotifsPic")
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
