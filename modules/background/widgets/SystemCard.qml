pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.modules.background

// --- System resources: rings, bars or a line graph, showing three readings or two. Which readings each style
// shows is picked in the settings. The tiles and the compact strip always show the same four: processor,
// graphics, memory and storage ---
WidgetCard {
    id: sys

    readonly property string style: {
        if (sys.variant === "tiles" || sys.variant === "compact")
            return sys.variant;
        return sys.variant.startsWith("bars") ? "bars" : sys.variant.startsWith("line") ? "line" : "rings";
    }
    readonly property bool basic: sys.variant.endsWith("basic")

    // Which readings this style shows, as picked in Settings > Panels > Widgets > System. The two-reading
    // variants show the first two of the three slots
    readonly property var metrics: {
        const all = sys.style === "bars" ? WidgetData.barMetrics : sys.style === "line" ? WidgetData.lineMetrics : WidgetData.ringMetrics;
        return sys.basic ? all.slice(0, 2) : all;
    }

    // One colour per slot rather than per reading, so the card keeps the same look whichever readings it shows
    readonly property list<color> slotColours: [Colours.palette.m3primary, Colours.palette.m3tertiary, Colours.palette.m3secondary]

    // The readings are a sample taken every few seconds rather than the live value: a ring that restarts an
    // animation on every tick keeps the whole desktop redrawing, and that was the shell's biggest single power
    // cost while idle. They and their histories are sampled in services/WidgetData.qml rather than here, since
    // the card is unloaded whenever windows hide the desktop - sampling here would empty the graph and drop
    // every reading to zero each time you came back to a bare workspace
    readonly property var readings: WidgetData.readings
    readonly property var histories: WidgetData.histories

    // --- The fixed four (tiles, compact strip) ---
    readonly property bool fixedFour: sys.style === "tiles" || sys.style === "compact"
    readonly property bool hasGpu: Gpu.type !== GpuType.None
    // WidgetData only samples the graphics card when one of the configurable styles is set to show it, which
    // these two cannot count on. When nothing else has asked for it, the card references and samples it itself
    readonly property bool ownGpu: sys.fixedFour && sys.hasGpu && !WidgetData.wantsGpu
    property var gpuHistory: []
    readonly property real gpuValue: WidgetData.wantsGpu ? WidgetData.valueFor("gpu") : WidgetData.finite(Gpu.percentage)
    readonly property real gpuTemp: WidgetData.wantsGpu ? WidgetData.gpuTemperature : WidgetData.finite(Gpu.temperature)

    // One reading of the four, as the tiles and the strip draw it. A function rather than a list of
    // objects, so a new sample updates the delegates in place instead of rebuilding them every few seconds
    function fixedReading(key: string): var {
        if (key === "gpu")
            return {
                label: "GPU",
                icon: "videogame_asset",
                value: sys.hasGpu ? sys.gpuValue : 0,
                history: WidgetData.wantsGpu ? WidgetData.historyFor("gpu") : sys.gpuHistory,
                detail: !sys.hasGpu ? Tr.tr("No graphics card") : sys.gpuTemp > 0 ? Units.formatSensorTemp(sys.gpuTemp) : (Gpu.name || ""),
                colour: Colours.palette.m3tertiary,
                graph: true
            };
        if (key === "ram")
            return {
                label: "RAM",
                icon: "memory_alt",
                value: WidgetData.valueFor("ram"),
                history: WidgetData.historyFor("ram"),
                detail: Memory.total > 0 ? Units.formatKibUsage(Memory.used, Memory.total) : "",
                colour: Colours.palette.m3secondary,
                graph: true
            };
        if (key === "disk") {
            const disk = Storage.primaryDisk;
            return {
                label: Tr.tr("Disk"),
                icon: "hard_drive",
                value: WidgetData.valueFor("disk"),
                history: [],
                detail: disk ? Units.formatKibUsage(disk.used, disk.total) : "",
                colour: Colours.palette.m3primary,
                // A disk fills over weeks, not seconds, so a graph of it would be a flat line: it gets a bar
                graph: false
            };
        }
        return {
            label: "CPU",
            icon: "memory",
            value: WidgetData.valueFor("cpu"),
            history: WidgetData.historyFor("cpu"),
            detail: WidgetData.temperature > 0 ? Units.formatSensorTemp(WidgetData.temperature) : "",
            colour: Colours.palette.m3primary,
            graph: true
        };
    }

    title: sys.style === "compact" ? "" : Tr.tr("System")
    icon: "monitoring"

    ServiceRef {
        service: sys.ownGpu ? Gpu : null
    }

    // The used and total amounts the tiles write out are read off these directly; WidgetData keeps only the
    // fractions
    ServiceRef {
        service: sys.fixedFour ? Memory : null
    }

    ServiceRef {
        service: sys.fixedFour ? Storage : null
    }

    Timer {
        interval: WidgetData.sampleInterval
        running: sys.ownGpu
        repeat: true
        triggeredOnStart: true
        onTriggered: sys.gpuHistory = WidgetData.push(sys.gpuHistory, WidgetData.finite(Gpu.percentage))
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        visible: sys.style === "rings"
        spacing: 0
        // Equal columns spread across the card, rather than bunched at the left
        uniformCellSizes: true

        Repeater {
            model: sys.style === "rings" ? sys.metrics : []

            Meter {
                required property string modelData
                required property int index

                readonly property var info: WidgetData.metricInfo(modelData)

                label: info.label
                icon: info.icon
                value: WidgetData.valueFor(modelData)
                valueText: WidgetData.isTemperature(modelData) ? WidgetData.textFor(modelData) : ""
                colour: sys.slotColours[index] ?? Colours.palette.m3primary
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: sys.style === "bars"
        spacing: Tokens.spacing.medium
        uniformCellSizes: true

        Repeater {
            model: sys.style === "bars" ? sys.metrics : []

            BarMeter {
                required property string modelData
                required property int index

                label: WidgetData.metricInfo(modelData).label
                value: WidgetData.valueFor(modelData)
                valueText: WidgetData.textFor(modelData)
                colour: sys.slotColours[index] ?? Colours.palette.m3primary
            }
        }
    }

    ResourceLines {
        visible: sys.style === "line"
        series: sys.style !== "line" ? [] : sys.metrics.map((id, i) => ({
                    label: WidgetData.metricInfo(id).label,
                    values: sys.histories[id] ?? [],
                    value: sys.readings[id] ?? 0,
                    valueText: WidgetData.textFor(id),
                    colour: sys.slotColours[i] ?? Colours.palette.m3primary
                }))
    }

    // Tiles: the four readings in a two by two grid, each with its last minute drawn under the figure
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: sys.style === "tiles"
        columns: 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small
        uniformCellWidths: true
        uniformCellHeights: true

        Repeater {
            model: sys.style === "tiles" ? ["cpu", "gpu", "ram", "disk"] : []

            Tile {}
        }
    }

    // Compact: the four side by side in one short strip, a figure and a sliver of bar each
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: sys.style === "compact"
        spacing: Tokens.spacing.small
        uniformCellSizes: true

        Repeater {
            model: sys.style === "compact" ? ["cpu", "gpu", "ram", "disk"] : []

            StripReading {}
        }
    }

component Tile: StyledRect {
    id: tile

    required property string modelData
    readonly property var info: sys.fixedReading(modelData)

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: Tokens.rounding.large
    color: Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.85)

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.topMargin: Tokens.padding.small
        anchors.bottomMargin: Tokens.padding.small
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: tile.info.icon
                color: tile.info.colour
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: tile.info.label
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.small
            }

            StyledText {
                text: `${Math.round(Math.max(0, Math.min(1, tile.info.value)) * 100)}%`
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
            }
        }

        SystemSparkline {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 12
            visible: tile.info.graph
            values: tile.info.history
            colour: tile.info.colour
            lineWidth: 1.5
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !tile.info.graph

            StyledRect {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: 8
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: Math.max(height, parent.width * Math.max(0, Math.min(1, tile.info.value)))
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: tile.info.colour
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: tile.info.detail
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}

component StripReading: ColumnLayout {
    id: strip

    required property string modelData
    readonly property var info: sys.fixedReading(modelData)

    Layout.fillWidth: true
    Layout.alignment: Qt.AlignVCenter
    spacing: Tokens.spacing.extraSmall

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        MaterialIcon {
            text: strip.info.icon
            color: strip.info.colour
            fontStyle: Tokens.font.icon.small
        }

        // A quarter of the card is only just wide enough for "100%" beside the icon, so the
        // figure gives up a point or two of size rather than spilling past the card's edge
        StyledText {
            Layout.fillWidth: true
            text: `${Math.round(Math.max(0, Math.min(1, strip.info.value)) * 100)}%`
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.builders.large.weight(Font.DemiBold).build()
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 9
        }
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: 4
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHighest

        StyledRect {
            width: Math.max(height, parent.width * Math.max(0, Math.min(1, strip.info.value)))
            height: parent.height
            radius: Tokens.rounding.full
            color: strip.info.colour
        }
    }
}

component Meter: ColumnLayout {
    id: meter

    property string label
    property string icon
    property real value
    property color colour
    // The reading as it should be read out, for a meter whose value isn't a percentage. Percent is assumed
    // when this is empty
    property string valueText: ""

    Layout.fillWidth: true
    Layout.maximumWidth: Number.POSITIVE_INFINITY
    spacing: Tokens.spacing.extraSmall

    CircularProgress {
        Layout.alignment: Qt.AlignHCenter
        implicitSize: 64
        strokeWidth: 6
        value: meter.value
        fgColour: meter.colour
        bgColour: Colours.palette.m3surfaceContainerHighest

        // Short and without overshoot: it only ever runs once every few seconds
        Behavior on clampedVal {
            Anim {
                type: Anim.FastEffects
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: meter.icon
            color: meter.colour
            fontStyle: Tokens.font.icon.medium
        }
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: meter.valueText !== "" ? `${meter.label} ${meter.valueText}` : `${meter.label} ${Math.round(meter.value * 100)}%`
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }
}

component BarMeter: ColumnLayout {
    id: bar

    property string label
    property real value
    property color colour
    property string valueText: ""

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Tokens.spacing.extraSmall

    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: bar.label
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 20

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.small
            color: Qt.alpha(Colours.palette.m3outlineVariant, 0.3)
        }

        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            radius: Tokens.rounding.small
            height: Math.max(2, parent.height * Math.max(0, Math.min(1, bar.value)))
            color: bar.colour
        }
    }

    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: bar.valueText !== "" ? bar.valueText : Math.round(Math.max(0, Math.min(1, bar.value)) * 100) + "%"
        color: Colours.palette.m3onSurface
        font: Tokens.font.label.small
    }
}

component ResourceLines: ColumnLayout {
    id: lines

    // [{ label, values, value, valueText, colour }]
    property var series

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Tokens.spacing.extraSmall

    Canvas {
        id: plot

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 24

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            const series = lines.series ?? [];
            const longest = series.reduce((n, s) => Math.max(n, (s.values ?? []).length), 0);
            if (longest < 2)
                return;

            const step = width / (longest - 1);
            const lineWidth = 2;
            const top = lineWidth / 2;
            const bottom = height - lineWidth / 2;

            // Faint lines at half and full, so a reading has a scale to be read against
            ctx.strokeStyle = Qt.alpha(Colours.palette.m3outlineVariant, 0.35);
            ctx.lineWidth = 1;
            for (const at of [0.5, 1]) {
                const y = bottom - at * (bottom - top);
                ctx.beginPath();
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
                ctx.stroke();
            }

            // Shorter histories sit against the right edge, so every line ends at "now"
            for (const s of series) {
                const values = s.values ?? [];
                if (values.length < 2)
                    continue;

                const offset = (longest - values.length) * step;
                ctx.beginPath();
                ctx.lineWidth = lineWidth;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.strokeStyle = s.colour;
                values.forEach((v, i) => {
                    const x = offset + i * step;
                    const y = bottom - Math.max(0, Math.min(1, v)) * (bottom - top);
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                });
                ctx.stroke();
            }
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        Connections {
            function onSeriesChanged(): void {
                plot.requestPaint();
            }

            target: lines
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium

        Repeater {
            model: lines.series ?? []

            RowLayout {
                id: legend

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledRect {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: Tokens.rounding.full
                    color: legend.modelData.colour
                }

                StyledText {
                    Layout.fillWidth: true
                    text: legend.modelData.label
                    elide: Text.ElideRight
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledText {
                    text: legend.modelData.valueText ?? Math.round(Math.max(0, Math.min(1, legend.modelData.value ?? 0)) * 100) + "%"
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
}
