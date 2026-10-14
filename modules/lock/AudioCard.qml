pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Default output volume and mute state - a compact sibling of the bar's own volume icon and
// the media card's transport, so it's obvious before unlocking whether sound would come out
StyledRect {
    id: root

    readonly property int percent: Math.round(Audio.volume * 100)
    // Same icon set as the bar's (modules/bar/components/StatusIcons.qml)
    readonly property string icon: Icons.getVolumeIcon(Audio.volume, Audio.muted)

    implicitHeight: row.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: root.icon
            color: Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                Layout.fillWidth: true
                text: Audio.muted ? Tr.tr("Muted") : Tr.tr("%1% volume").arg(root.percent)
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                elide: Text.ElideRight
            }

            // Same volume-bar treatment as Battery's charge bar: container track, rounded fill
            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: parent.width * Math.max(0, Math.min(1, Audio.volume))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: Audio.muted ? Colours.palette.m3error : Colours.palette.m3primary
                }
            }
        }

        StyledText {
            visible: Pipewire.ready
            text: Tr.tr("Output")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
