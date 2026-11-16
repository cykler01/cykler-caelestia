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
    readonly property bool hourly: weather.variant === "hourly"
    readonly property bool details: weather.variant === "details"
    readonly property bool mini: weather.variant === "mini"
    // The forecast and compact layouts, which share the current-conditions row
    readonly property bool classic: !weather.hourly && !weather.details && !weather.mini

    // The next eight hours. Dropped again here as well as when fetched, since the list is only
    // refreshed hourly and would otherwise start an hour or so in the past
    readonly property var nextHours: {
        const hourStart = new Date(Time.date.getFullYear(), Time.date.getMonth(), Time.date.getDate(), Time.date.getHours()).getTime();
        return Weather.hourlyForecast.filter(h => new Date(h.timestamp.replace("T", " ")).getTime() >= hourStart).slice(0, 8);
    }

    function hourLabel(entry: var, index: int): string {
        if (index === 0)
            return Tr.trCtx("Now", "forecast column");
        return Tr.formatDateTime(new Date(entry.timestamp.replace("T", " ")), Units.twelveHourClock ? "ha" : "hh:00");
    }

    // "9 h 41 min" of daylight between the day's sunrise and sunset
    function dayLength(): string {
        if (!Weather.cc)
            return "--";
        const mins = Math.round((new Date(Weather.cc.sunset) - new Date(Weather.cc.sunrise)) / 60000);
        if (isNaN(mins) || mins <= 0)
            return "--";
        return Tr.tr("%1 h %2 min").arg(Math.floor(mins / 60)).arg(mins % 60);
    }

    title: weather.mini ? "" : Weather.city || Tr.tr("Weather")
    icon: "location_on"
    // The mini one is a pill: round ends, and a tighter inset so the icon and figure have room
    radius: weather.mini ? height / 2 : Tokens.rounding.extraLarge
    padding: weather.mini ? Tokens.padding.medium : Tokens.padding.largeIncreased
    // The card is created again each time the desktop is uncovered, so only fetch when there is nothing to show
    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
    }

    RowLayout {
        Layout.fillWidth: true
        visible: weather.classic
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
        visible: weather.classic && !weather.compact
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

    // Hourly: eight columns of time, sky and temperature, with the temperatures strung on a line
    // along the bottom that rises and falls with them
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: weather.hourly
        visible: active

        sourceComponent: Item {
            id: hours

            readonly property var temps: weather.nextHours.map(h => h.tempC)
            readonly property real lo: Math.min(...hours.temps)
            readonly property real hi: Math.max(...hours.temps)
            readonly property real colWidth: hours.width / Math.max(1, weather.nextHours.length)
            // Where the columns' labels end, which the first column reports; the line moves within
            // the band between there and the bottom
            property real labelsBottom: hours.height * 0.6
            readonly property real bandTop: hours.labelsBottom + Tokens.spacing.medium
            readonly property real bandBottom: hours.height - Tokens.spacing.small

            function dotY(temp: real): real {
                const span = hours.hi - hours.lo;
                const t = span > 0 ? (temp - hours.lo) / span : 0.5;
                return hours.bandBottom - t * (hours.bandBottom - hours.bandTop);
            }

            StyledText {
                anchors.centerIn: parent
                visible: weather.nextHours.length === 0
                text: Tr.tr("No forecast yet")
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
            }

            Repeater {
                model: weather.nextHours

                Item {
                    id: hourCol

                    required property var modelData
                    required property int index

                    x: hourCol.index * hours.colWidth
                    width: hours.colWidth
                    height: hours.height

                    // The current hour picked out with a faint column behind it
                    StyledRect {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.spacing.extraSmall / 2
                        anchors.rightMargin: Tokens.spacing.extraSmall / 2
                        visible: hourCol.index === 0
                        radius: Tokens.rounding.medium
                        color: Qt.alpha(Colours.palette.m3primary, 0.1)
                    }

                    Binding {
                        when: hourCol.index === 0
                        target: hours
                        property: "labelsBottom"
                        value: labels.y + labels.height
                    }

                    ColumnLayout {
                        id: labels

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Tokens.spacing.extraSmall
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: weather.hourLabel(hourCol.modelData, hourCol.index)
                            color: hourCol.index === 0 ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                            font: hourCol.index === 0 ? Tokens.font.label.builders.small.weight(Font.Bold).build() : Tokens.font.label.small
                        }

                        MaterialIcon {
                            Layout.alignment: Qt.AlignHCenter
                            text: hourCol.modelData.icon
                            color: Colours.palette.m3secondary
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Weather.formatTemp(hourCol.modelData.tempC, true)
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
                        }
                    }
                }
            }

            Canvas {
                id: line

                anchors.fill: parent
                visible: weather.nextHours.length > 1

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    const n = hours.temps.length;
                    if (n < 2)
                        return;

                    const pts = hours.temps.map((t, i) => [(i + 0.5) * hours.colWidth, hours.dotY(t)]);
                    const trace = () => {
                        ctx.moveTo(pts[0][0], pts[0][1]);
                        for (let i = 1; i < n; i++) {
                            const mx = (pts[i - 1][0] + pts[i][0]) / 2;
                            ctx.bezierCurveTo(mx, pts[i - 1][1], mx, pts[i][1], pts[i][0], pts[i][1]);
                        }
                    };

                    ctx.beginPath();
                    trace();
                    ctx.strokeStyle = Colours.palette.m3primary;
                    ctx.lineWidth = 2;
                    ctx.stroke();

                    ctx.fillStyle = Colours.palette.m3primary;
                    for (const [x, y] of pts) {
                        ctx.beginPath();
                        ctx.arc(x, y, 3, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                Connections {
                    function onTempsChanged(): void {
                        line.requestPaint();
                    }

                    target: hours
                }

                Connections {
                    function onM3primaryChanged(): void {
                        line.requestPaint();
                    }

                    target: Colours.palette
                }
            }
        }
    }

    // Details: a line of what it's like out, then the readings as a grid of tiles
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: weather.details
        visible: active

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: Weather.icon
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    text: Weather.temp
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.large.weight(Font.DemiBold).build()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.leftMargin: Tokens.spacing.extraSmall
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Weather.description
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: Weather.forecast.length > 0
                        elide: Text.ElideRight
                        // TRANSLATORS: today's high and low, e.g. "High 13° · Low 9°"
                        text: Weather.forecast.length > 0 ? Tr.tr("High %1 \u00b7 Low %2").arg(Weather.formatTemp(Weather.forecast[0].maxTempC, true)).arg(Weather.formatTemp(Weather.forecast[0].minTempC, true)) : ""
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 3
                rowSpacing: Tokens.spacing.small
                columnSpacing: Tokens.spacing.small
                uniformCellWidths: true
                uniformCellHeights: true

                DetailTile {
                    icon: "thermostat"
                    label: Tr.tr("Feels like")
                    value: Weather.feelsLike
                }

                DetailTile {
                    icon: "humidity_percentage"
                    label: Tr.tr("Humidity")
                    value: Weather.cc ? `${Weather.humidity}%` : "--"
                }

                DetailTile {
                    icon: "air"
                    label: Tr.tr("Wind")
                    value: Weather.cc ? `${Math.round(Weather.windSpeed)} km/h` : "--"
                }

                DetailTile {
                    icon: "water_drop"
                    label: Tr.tr("Rain")
                    value: weather.nextHours.length > 0 ? `${weather.nextHours[0].precipChance}%` : "--"
                }

                DetailTile {
                    icon: "wb_twilight"
                    label: Tr.tr("Sunrise")
                    value: Weather.sunrise
                }

                DetailTile {
                    icon: "bedtime"
                    label: Tr.tr("Sunset")
                    value: Weather.sunset
                }
            }
        }
    }

    // Mini: the sky and the temperature, nothing else
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: weather.mini
        visible: active

        sourceComponent: Item {
            StyledRect {
                id: miniIcon

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                implicitWidth: height
                radius: Tokens.rounding.full
                color: Colours.palette.m3secondaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: Weather.icon
                    color: Colours.palette.m3onSecondaryContainer
                    fontStyle: Tokens.font.icon.medium
                }
            }

            // Centred in what is left beside the icon, so the figure sits in the middle of the pill
            StyledText {
                anchors.left: miniIcon.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: Weather.temp
                color: Colours.palette.m3onSurface
                font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
            }
        }
    }

component DetailTile: StyledRect {
    id: tile

    property string icon
    property string label
    property string value

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Tokens.rounding.medium
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    // The icon is a large faint mark behind the reading rather than a glyph beside its label: a
    // tile a third of the card wide has no room for both on one line
    MaterialIcon {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: -Tokens.padding.extraSmall
        anchors.bottomMargin: -Tokens.padding.small
        text: tile.icon
        color: Colours.palette.m3primary
        opacity: 0.18
        fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.1).build()
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.small
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: tile.label
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: tile.value
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
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
