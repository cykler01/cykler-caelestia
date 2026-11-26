pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock.layouts

// The current conditions: detailed (icon, temperature, then the description over today's high,
// low and feels-like), compact (icon and temperature) or large (a big icon over the temperature
// and description). Hidden until the first fetch lands
Item {
    id: root

    property real s: 1

    property var lock: null
    property var opts: ({})

    visible: !!Weather.cc
    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight

    Loader {
        id: loader

        sourceComponent: root.opts.style === "compact" ? compact : root.opts.style === "large" ? large : pill
    }

    Component {
        id: pill

        WeatherPill {
            uiScale: root.s
        }
    }

    Component {
        id: compact

        RowLayout {
            spacing: Tokens.spacing.small * root.s

            MaterialIcon {
                text: Weather.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.large.scale(root.s).build()
            }

            StyledText {
                text: Weather.temp
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.large.scale(root.s).weight(Font.DemiBold).build()
            }
        }
    }

    Component {
        id: large

        ColumnLayout {
            spacing: 0

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: Weather.icon
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(root.s * 2.4).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Weather.temp
                color: Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.large.scale(root.s * 1.6).weight(Font.Bold).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.builders.medium.scale(root.s).build()
            }
        }
    }
}
