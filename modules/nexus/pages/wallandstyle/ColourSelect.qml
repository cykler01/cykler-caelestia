import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Colours")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Theme
        SectionHeader {
            first: true
            text: Tr.tr("Theme")
        }

        ToggleRow {
            first: true
            last: true
            // SEARCH: night mode light appearance
            text: Tr.tr("Dark theme")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
        }

        // Dynamic colours
        SectionHeader {
            text: Tr.tr("Dynamic colours")
        }

        ToggleRow {
            first: true
            last: true
            // SEARCH: material you dynamic accent colour scheme
            text: Tr.tr("Use colours from wallpaper")
            subtext: Tr.tr("Derive the colour scheme from the current wallpaper")
            checked: Colours.scheme === "dynamic"
            onToggled: Schemes.setDynamic(checked)
        }

        // Colour scheme
        SectionHeader {
            text: Tr.tr("Colour scheme")
        }

        Repeater {
            model: Schemes.schemes

            SchemeRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Schemes.schemes.length - 1
                scheme: modelData
            }
        }

        // Scheme variant
        SectionHeader {
            text: Tr.tr("Scheme variant")
        }

        Repeater {
            model: Schemes.variants

            VariantRow {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Schemes.variants.length - 1
                variant: modelData
            }
        }
    }
}
