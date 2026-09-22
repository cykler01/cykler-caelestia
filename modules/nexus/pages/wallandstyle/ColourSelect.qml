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
            text: Tr.tr("Dark theme")
            checked: !Colours.light
            onToggled: Colours.setMode(checked ? "dark" : "light")
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
