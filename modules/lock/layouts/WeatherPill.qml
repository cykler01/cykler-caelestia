pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// A compact current-conditions readout for the corner of the free-standing layouts: icon and
// temperature, then the description over today's high/low and the feels-like. No card behind
// it, it sits straight on the blurred background like the clock does
RowLayout {
    id: root

    property real uiScale: 1

    // Nothing to show until the first fetch lands (or with no location at all)
    visible: !!Weather.cc
    spacing: Tokens.spacing.medium * root.uiScale

    MaterialIcon {
        animate: true
        text: Weather.icon
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.builders.extraLarge.scale(root.uiScale).build()
    }

    StyledText {
        animate: true
        text: Weather.temp
        color: Colours.palette.m3onSurface
        font: Tokens.font.headline.builders.medium.scale(root.uiScale).weight(Font.DemiBold).build()
    }

    StyledRect {
        Layout.fillHeight: true
        Layout.topMargin: Tokens.padding.small * root.uiScale
        Layout.bottomMargin: Tokens.padding.small * root.uiScale
        implicitWidth: 1
        color: Qt.alpha(Colours.palette.m3onSurface, 0.3)
    }

    ColumnLayout {
        spacing: 0

        StyledText {
            animate: true
            text: Weather.description
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.builders.large.scale(root.uiScale).weight(Font.DemiBold).build()
        }

        StyledText {
            animate: true
            text: {
                const today = Weather.forecast[0];
                // TRANSLATORS: %1/%2 = today's high and low, %3 = apparent temperature, units included
                return Tr.tr("H %1  L %2 · feels %3").arg(Weather.formatTemp(today?.maxTempC)).arg(Weather.formatTemp(today?.minTempC)).arg(Weather.feelsLike);
            }
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.builders.medium.scale(root.uiScale).build()
        }
    }
}
