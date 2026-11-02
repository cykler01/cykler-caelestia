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

// --- System resources: rings, bars or a line graph, showing all three readings or just CPU and RAM ---
WidgetCard {
    id: sys

    readonly property string style: sys.variant.startsWith("bars") ? "bars" : sys.variant.startsWith("line") ? "line" : "rings"
    readonly property bool basic: sys.variant.endsWith("basic")

    // The readings show a sample taken every few seconds rather than following the live value: a ring that
    // restarts an animation on every tick keeps the whole desktop redrawing, and that was the shell's
    // biggest single power cost while idle. The histories are what the line graph draws.
    property real cpu
    property real memory
    property real disk
    property var cpuHistory: []
    property var ramHistory: []
    property var diskHistory: []

    function push(history: var, value: real): var {
        const next = history.concat([Math.max(0, Math.min(1, value))]);
        return next.length > 24 ? next.slice(next.length - 24) : next;
    }

    title: Tr.tr("System")
    icon: "monitoring"

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    Timer {
        interval: 3000 * PowerSaving.pollSlowdown
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            sys.cpu = Cpu.percentage;
            sys.memory = Memory.percentage;
            sys.disk = Storage.percentage;
            sys.cpuHistory = sys.push(sys.cpuHistory, sys.cpu);
            sys.ramHistory = sys.push(sys.ramHistory, sys.memory);
            sys.diskHistory = sys.push(sys.diskHistory, sys.disk);
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        visible: sys.style === "rings"
        spacing: 0
        // Three equal columns spread across the card, rather than bunched at the left
        uniformCellSizes: true

        Meter {
            label: "CPU"
            icon: "memory"
            value: sys.cpu
            colour: Colours.palette.m3primary
        }

        Meter {
            label: "RAM"
            icon: "memory_alt"
            value: sys.memory
            colour: Colours.palette.m3tertiary
        }

        Meter {
            visible: !sys.basic
            label: Tr.tr("Disk")
            icon: "hard_disk"
            value: sys.disk
            colour: Colours.palette.m3secondary
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: sys.style === "bars"
        spacing: Tokens.spacing.medium
        uniformCellSizes: true

        BarMeter {
            label: "CPU"
            value: sys.cpu
            colour: Colours.palette.m3primary
        }

        BarMeter {
            label: "RAM"
            value: sys.memory
            colour: Colours.palette.m3tertiary
        }

        BarMeter {
            visible: !sys.basic
            label: Tr.tr("Disk")
            value: sys.disk
            colour: Colours.palette.m3secondary
        }
    }

    ResourceLines {
        visible: sys.style === "line"
        series: sys.basic ? [{
                label: "CPU",
                values: sys.cpuHistory,
                value: sys.cpu,
                colour: Colours.palette.m3primary
            }, {
                label: "RAM",
                values: sys.ramHistory,
                value: sys.memory,
                colour: Colours.palette.m3tertiary
            }] : [{
                label: "CPU",
                values: sys.cpuHistory,
                value: sys.cpu,
                colour: Colours.palette.m3primary
            }, {
                label: "RAM",
                values: sys.ramHistory,
                value: sys.memory,
                colour: Colours.palette.m3tertiary
            }, {
                label: Tr.tr("Disk"),
                values: sys.diskHistory,
                value: sys.disk,
                colour: Colours.palette.m3secondary
            }]
    }

component Meter: ColumnLayout {
    id: meter

    property string label
    property string icon
    property real value
    property color colour

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
        text: `${meter.label} ${Math.round(meter.value * 100)}%`
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }
}

component BarMeter: ColumnLayout {
    id: bar

    property string label
    property real value
    property color colour

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
        text: Math.round(Math.max(0, Math.min(1, bar.value)) * 100) + "%"
        color: Colours.palette.m3onSurface
        font: Tokens.font.label.small
    }
}

component ResourceLines: ColumnLayout {
    id: lines

    // [{ label, values, value, colour }]
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
                    text: Math.round(Math.max(0, Math.min(1, legend.modelData.value ?? 0)) * 100) + "%"
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.small
                }
            }
        }
    }
}
}
