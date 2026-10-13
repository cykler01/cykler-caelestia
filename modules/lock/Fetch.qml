pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.effects
import qs.services
import qs.utils

StyledRect {
    id: root

    required property real rootHeight
    readonly property int cBoxSize: Tokens.font.body.medium.pointSize * 2

    implicitHeight: layout.implicitHeight + content.anchors.margins * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Item {
        id: content

        anchors.fill: parent
        anchors.margins: Tokens.padding.large

        // Everything (OS/WM/USER lines, the colour swatches) is always shown now - rather than
        // dropping lines one by one as the share shrinks, the whole block is scaled down
        // uniformly so it still fits, same idea as a browser's page zoom. Never scaled up past 1
        // though - a generous share just means more empty margin, not an oversized card
        readonly property real fitScale: Math.min(1, content.width / Math.max(1, layout.implicitWidth), content.height / Math.max(1, layout.implicitHeight))

        ColumnLayout {
            id: layout

            width: layout.implicitWidth
            height: layout.implicitHeight
            scale: content.fitScale
            transformOrigin: Item.TopLeft

            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                spacing: Tokens.spacing.medium

                StyledRect {
                    implicitWidth: prompt.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: prompt.implicitHeight + Tokens.padding.small * 2

                    color: Colours.palette.m3primary
                    radius: Tokens.rounding.medium

                    MonoText {
                        id: prompt

                        anchors.centerIn: parent
                        text: ">"
                        color: Colours.palette.m3onPrimary
                    }
                }

                MonoText {
                    Layout.fillWidth: true
                    text: "caelestiafetch.sh"
                    elide: Text.ElideRight
                }

                WrappedLoader {
                    Layout.fillHeight: true
                    Layout.preferredWidth: height
                    Layout.preferredHeight: 0
                    active: !iconLoader.active

                    sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.extraLarge

                WrappedLoader {
                    id: iconLoader

                    Layout.fillHeight: true
                    active: root.width > Tokens.sizes.lock.largeLogoWidth

                    sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : distroIcon
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.padding.medium
                    Layout.bottomMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    Repeater {
                        model: [
                            // TRANSLATORS: keep the label padded to 4 chars so the column stays aligned
                            Tr.tr("OS  : %1").arg(SysInfo.osPrettyName || SysInfo.osName),
                            // TRANSLATORS: keep the label padded to 4 chars so the column stays aligned
                            Tr.tr("WM  : %1").arg(SysInfo.wm),
                            // TRANSLATORS: keep the label padded to 4 chars so the column stays aligned
                            Tr.tr("USER: %1").arg(SysInfo.user),
                        ]

                        MonoText {
                            required property string modelData

                            Layout.fillWidth: true
                            text: modelData
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            RowLayout {
                id: coloursRow

                Layout.alignment: Qt.AlignHCenter

                spacing: Tokens.spacing.largeIncreased

                Repeater {
                    // Based on the card's real (pre-scale) width, not layout.width - layout's
                    // own width is derived from its children's implicit sizes, including this
                    // row, so sizing it off layout.width here would be circular
                    model: CUtils.clamp(Math.floor((content.width + coloursRow.spacing) / (root.cBoxSize + coloursRow.spacing)), 0, 8)

                    StyledRect {
                        required property int index

                        implicitWidth: implicitHeight
                        implicitHeight: root.cBoxSize
                        color: Colours.palette[`term${index}`]
                        radius: Tokens.rounding.medium
                    }
                }
            }
        }
    }

    Component {
        id: caelestiaLogo

        Logo {
            width: height
        }
    }

    Component {
        id: distroIcon

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: height
            colour: Colours.palette.m3primary
            layer.enabled: Config.lock.recolourLogo
        }
    }

    component WrappedLoader: Loader {
        asynchronous: true
        visible: active
    }

    component MonoText: StyledText {
        font: root.width > Tokens.sizes.lock.largeFontWidth ? Tokens.font.mono.medium : Tokens.font.mono.small
    }
}
