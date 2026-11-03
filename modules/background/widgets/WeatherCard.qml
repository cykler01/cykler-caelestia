pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Weather ---
WidgetCard {
    id: weather

    // The compact variant is the current conditions on their own, without the week under them
    readonly property bool compact: weather.variant === "compact"

    title: Weather.city || Tr.tr("Weather")
    icon: "location_on"
    // The card is created again each time the desktop is uncovered, so only fetch when there is nothing to show
    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        MaterialIcon {
            text: Weather.icon
            color: Colours.palette.m3secondary
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.4).build()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Weather.temp
                color: Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }

        ColumnLayout {
            spacing: Tokens.spacing.extraSmall

            Stat {
                icon: "humidity_percentage"
                text: `${Weather.humidity}%`
            }

            Stat {
                icon: "air"
                text: `${Math.round(Weather.windSpeed)} km/h`
            }
        }
    }

    StyledRect {
        Layout.fillWidth: true
        visible: !weather.compact
        implicitHeight: forecastRow.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surfaceContainerHigh
        opacity: 0.85

        RowLayout {
            id: forecastRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.small
            spacing: 0
            // Equal-width columns however wide each day's text is
            uniformCellSizes: true

            Repeater {
                model: Weather.forecast.slice(0, 5)

                ColumnLayout {
                    id: fc

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.minimumWidth: 0
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    spacing: 2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: fc.index === 0 ? Tr.tr("Today") : Qt.locale().dayName(new Date(fc.modelData.date).getDay(), Locale.ShortFormat)
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: fc.modelData.icon
                        color: Colours.palette.m3secondary
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.formatTemp(fc.modelData.maxTempC, true)
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.formatTemp(fc.modelData.minTempC, true)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }

component Stat: RowLayout {
    property string icon
    property string text

    spacing: Tokens.spacing.extraSmall

    MaterialIcon {
        text: parent.icon
        color: Colours.palette.m3outline
        fontStyle: Tokens.font.icon.small
    }

    StyledText {
        text: parent.text
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }
}
}
