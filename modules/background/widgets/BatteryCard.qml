pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.services
import qs.modules.background

// --- Battery: charge, state, rate and time remaining on a laptop; the GPU's power draw on a desktop ---
WidgetCard {
    id: bat

    readonly property var dev: UPower.displayDevice
    readonly property bool laptop: dev.isLaptopBattery
    readonly property real pct: dev.percentage
    readonly property bool full: dev.state === UPowerDeviceState.FullyCharged
    readonly property bool charging: dev.state === UPowerDeviceState.Charging || full
    readonly property real rate: Math.abs(dev.changeRate)
    readonly property real seconds: charging ? dev.timeToFull : dev.timeToEmpty
    readonly property bool low: pct < 0.2 && !charging

    function duration(secs: real): string {
        if (secs <= 0)
            return "";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return h > 0 ? Tr.tr("%1 h %2 min").arg(h).arg(m) : Tr.tr("%1 min").arg(m);
    }

    visible: laptop || Gpu.power > 0
    title: laptop ? Tr.tr("Battery") : Tr.tr("Power draw")
    icon: !laptop ? "bolt" : charging ? "battery_charging_full" : "battery_full"

    ServiceRef {
        service: Gpu
    }

    RowLayout {
        Layout.fillWidth: true
        visible: !bat.laptop
        spacing: Tokens.spacing.medium

        StyledText {
            text: `${Math.round(Gpu.power)} W`
            color: Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Tr.tr("Graphics card")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Gpu.name
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: bat.laptop
        spacing: Tokens.spacing.medium

        StyledText {
            text: `${Math.round(bat.pct * 100)}%`
            color: bat.low ? Colours.palette.m3error : Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: bat.full ? Tr.tr("Fully charged") : bat.charging ? Tr.tr("Charging") : Tr.tr("On battery")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: parent.width * Math.max(0, Math.min(1, bat.pct))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: bat.low ? Colours.palette.m3error : bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
                }
            }
        }
    }

    // Rate and time to empty/full. The row is always there on a laptop and its contents fade out
    // instead of collapsing, so a battery that is full (no rate, no time left to report) keeps the
    // same height and the card does not shrink out from under the widgets below it.
    RowLayout {
        Layout.fillWidth: true
        visible: bat.laptop
        spacing: Tokens.spacing.small

        MaterialIcon {
            opacity: bat.rate > 0 && !bat.full ? 1 : 0
            text: bat.charging ? "bolt" : "trending_down"
            color: bat.charging ? Colours.palette.m3tertiary : Colours.palette.m3primary
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            opacity: bat.rate > 0 && !bat.full ? 1 : 0
            text: `${bat.charging ? "+" : "−"}${bat.rate.toFixed(1)} W`
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.medium
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            opacity: bat.seconds >= 60 && !bat.full ? 1 : 0
            text: bat.charging ? Tr.tr("Full in %1").arg(bat.duration(bat.seconds)) : Tr.tr("%1 left").arg(bat.duration(bat.seconds))
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }
    }
}
