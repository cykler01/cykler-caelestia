pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

StyledRect {
    id: root

    readonly property bool showCpu: Config.dashboard.performance.showCpu
    readonly property bool showGpu: Config.dashboard.performance.showGpu && Gpu.type !== GpuType.None
    readonly property bool showMemory: Config.dashboard.performance.showMemory
    readonly property bool showNetwork: Config.dashboard.performance.showNetwork
    readonly property bool showStorage: Config.dashboard.performance.showStorage

    // Network throughput below this is drawn as a flat line so idle noise doesn't fill the graph
    readonly property real netFloor: 128 * 1024
    readonly property real netTotal: (NetworkUsage.downloadSpeed ?? 0) + (NetworkUsage.uploadSpeed ?? 0)
    property real netMax: netFloor

    // Seconds of history shown at each zoom level; the last one is all ResourceHistory keeps
    readonly property list<int> zoomSteps: [15, 30, 60, ResourceHistory.historySeconds]
    property int zoomIndex: 2
    readonly property int viewSamples: Math.max(2, Math.min(ResourceHistory.capacity, Math.round(zoomSteps[zoomIndex] * 1000 / ResourceHistory.interval)))

    property var hidden: ({})

    // Line and bar colours for each resource; every preset follows the current colour scheme
    readonly property var colours: {
        const p = Colours.palette;
        switch (Config.dashboard.performance.graphColours) {
        case PerfGraphColours.Vibrant:
            // The scheme's terminal colours: distinct hues that still follow the wallpaper
            return {
                cpu: p.term1,
                gpu: p.term3,
                mem: p.term2,
                net: p.term4,
                disk: p.term5
            };
        case PerfGraphColours.Custom:
            {
                const perf = Config.dashboard.performance;
                return {
                    cpu: ResourceHistory.resolveColour(perf.cpuColour),
                    gpu: ResourceHistory.resolveColour(perf.gpuColour),
                    mem: ResourceHistory.resolveColour(perf.memoryColour),
                    net: ResourceHistory.resolveColour(perf.networkColour),
                    disk: ResourceHistory.resolveColour(perf.storageColour)
                };
            }
        case PerfGraphColours.Monochrome:
            return {
                cpu: p.m3primary,
                gpu: p.m3onPrimaryContainer,
                mem: p.m3inversePrimary,
                net: p.m3primaryFixedDim,
                disk: p.m3outline
            };
        default:
            return {
                cpu: p.m3primary,
                gpu: p.m3secondary,
                mem: p.m3tertiary,
                net: p.m3success,
                disk: p.m3onSurfaceVariant
            };
        }
    }

    readonly property var series: [
        {
            key: "cpu",
            enabled: showCpu,
            colour: colours.cpu
        },
        {
            key: "gpu",
            enabled: showGpu,
            colour: colours.gpu
        },
        {
            key: "mem",
            enabled: showMemory,
            colour: colours.mem
        },
        {
            key: "net",
            enabled: showNetwork,
            colour: colours.net
        }
    ]

    function updateNetMax(): void {
        netMax = Math.max(netFloor, ...ResourceHistory.net.slice(-viewSamples));
    }

    function toggle(key: string): void {
        const h = Object.assign({}, hidden);
        h[key] = !h[key];
        hidden = h;
    }

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    implicitWidth: Tokens.sizes.dashboard.perfHeroCardWidth * 2 + Tokens.spacing.medium
    implicitHeight: Tokens.sizes.dashboard.perfNetworkCardHeight + Tokens.sizes.dashboard.perfBattHeight / 2

    onViewSamplesChanged: {
        updateNetMax();
        graph.requestPaint();
    }
    onHiddenChanged: graph.requestPaint()
    onSeriesChanged: graph.requestPaint()

    Component.onCompleted: updateNetMax()

    Connections {
        function onRevisionChanged(): void {
            root.updateNetMax();
            graph.requestPaint();
        }

        target: ResourceHistory
    }

    ServiceRef {
        service: Storage
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        // Legend with live values
        ColumnLayout {
            Layout.preferredWidth: Tokens.sizes.dashboard.perfStorageTextWidth + Tokens.padding.extraLarge * 3
            Layout.fillHeight: true
            spacing: Tokens.spacing.medium

            Item {
                Layout.fillHeight: true
            }

            LegendRow {
                dimmed: !!root.hidden.cpu
                onToggled: root.toggle("cpu")
                visible: root.showCpu
                icon: "memory"
                colour: root.colours.cpu
                label: Cpu.name || Tr.tr("CPU")
                value: Cpu.percentage
                valueText: isNaN(Cpu.percentage) ? "..." : Strings.percentOne(Cpu.percentage)
                temperature: Cpu.temperature
            }

            LegendRow {
                dimmed: !!root.hidden.gpu
                onToggled: root.toggle("gpu")
                visible: root.showGpu
                icon: "desktop_windows"
                colour: root.colours.gpu
                label: Gpu.name || (Gpu.detecting ? Tr.tr("Detecting GPU...") : Tr.tr("GPU"))
                value: Gpu.percentage
                valueText: isNaN(Gpu.percentage) ? "..." : Strings.percentOne(Gpu.percentage)
                temperature: Gpu.temperature
            }

            LegendRow {
                dimmed: !!root.hidden.mem
                onToggled: root.toggle("mem")
                visible: root.showMemory
                icon: "memory_alt"
                colour: root.colours.mem
                label: Units.formatKibUsage(Memory.used, Memory.total)
                value: Memory.percentage
                valueText: Strings.percentOne(Memory.percentage)
            }

            LegendRow {
                dimmed: !!root.hidden.net
                onToggled: root.toggle("net")
                visible: root.showNetwork
                icon: "swap_vert"
                colour: root.colours.net
                label: {
                    const down = Units.formatBytes(NetworkUsage.downloadSpeed ?? 0, true);
                    const up = Units.formatBytes(NetworkUsage.uploadSpeed ?? 0, true);
                    // TRANSLATORS: %1 = download speed, %2 = upload speed
                    return Tr.tr("↓%1 ↑%2").arg(down).arg(up);
                }
                value: root.netTotal / root.netMax
                valueText: Units.formatBytes(root.netTotal, true)
            }

            // Storage isn't graphed; clicking cycles through the detected disks instead
            LegendRow {
                visible: root.showStorage
                icon: "hard_drive"
                colour: root.colours.disk
                label: {
                    const disk = Storage.primaryDisk;
                    if (!disk)
                        return Tr.tr("No disks detected");
                    return `${disk.mount} · ${Units.formatKibUsage(disk.used, disk.total)}`;
                }
                value: Storage.primaryDisk?.perc ?? 0
                valueText: Strings.percentOne(Storage.primaryDisk?.perc ?? 0)
                onToggled: {
                    const disks = Storage.disks;
                    if (disks.length < 2)
                        return;
                    let i = 0;
                    while (i < disks.length && disks[i] !== Storage.primaryDisk)
                        i++;
                    Storage.manualPrimaryDisk = disks[(i + 1) % disks.length];
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        StyledRect {
            Layout.fillHeight: true
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.small

            StyledClippingRect {
                Layout.fillWidth: true
                Layout.fillHeight: true

                color: Colours.tPalette.m3surfaceContainerHigh
                radius: Tokens.rounding.large

                Canvas {
                    id: graph

                    anchors.fill: parent
                    anchors.topMargin: Tokens.padding.medium

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        const w = width;
                        const h = height;
                        ctx.reset();

                        // Grid
                        ctx.lineWidth = 1;
                        ctx.strokeStyle = Qt.alpha(Colours.palette.m3outlineVariant, 0.6);
                        ctx.beginPath();
                        for (let i = 1; i < 4; i++) {
                            const y = Math.round(h * i / 4) + 0.5;
                            ctx.moveTo(0, y);
                            ctx.lineTo(w, y);
                        }
                        for (let i = 1; i < 6; i++) {
                            const x = Math.round(w * i / 6) + 0.5;
                            ctx.moveTo(x, 0);
                            ctx.lineTo(x, h);
                        }
                        ctx.stroke();

                        const step = w / (root.viewSamples - 1);
                        ctx.lineWidth = 2;
                        ctx.lineJoin = "round";

                        for (const s of root.series) {
                            if (!s.enabled || root.hidden[s.key])
                                continue;

                            const data = ResourceHistory[s.key].slice(-root.viewSamples);
                            if (data.length < 2)
                                continue;

                            const max = s.key === "net" ? root.netMax : 1;
                            const offset = root.viewSamples - data.length;
                            const yOf = v => h - Math.min(1, v / max) * (h - 2) - 1;

                            ctx.beginPath();
                            ctx.moveTo(offset * step, yOf(data[0]));
                            for (let i = 1; i < data.length; i++)
                                ctx.lineTo((offset + i) * step, yOf(data[i]));

                            ctx.strokeStyle = s.colour;
                            ctx.stroke();

                            ctx.lineTo(w, h);
                            ctx.lineTo(offset * step, h);
                            ctx.closePath();

                            const grad = ctx.createLinearGradient(0, 0, 0, h);
                            grad.addColorStop(0, Qt.alpha(s.colour, 0.3));
                            grad.addColorStop(1, Qt.alpha(s.colour, 0));
                            ctx.fillStyle = grad;
                            ctx.fill();
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: Tr.tr("Collecting data...")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3outline
                    visible: ResourceHistory.revision >= 0 && ResourceHistory.cpu.length < 2
                }
            }

            // Zoom controls
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                IconButton {
                    icon: "zoom_out"
                    type: IconButton.Text
                    disabled: root.zoomIndex >= root.zoomSteps.length - 1
                    onClicked: root.zoomIndex++
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.small
                    value: 1 - root.zoomIndex / (root.zoomSteps.length - 1)
                    fgColour: Colours.palette.m3primary
                }

                IconButton {
                    icon: "zoom_in"
                    type: IconButton.Text
                    disabled: root.zoomIndex <= 0
                    onClicked: root.zoomIndex--
                }

                StyledText {
                    Layout.leftMargin: Tokens.spacing.small
                    text: {
                        const secs = root.zoomSteps[root.zoomIndex];
                        if (secs >= 60)
                            // TRANSLATORS: %1 = minutes of history shown in the graph
                            return Tr.tr("%1m").arg(+(secs / 60).toFixed(1));
                        // TRANSLATORS: %1 = seconds of history shown in the graph
                        return Tr.tr("%1s").arg(secs);
                    }
                    font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }

    component LegendRow: Item {
        id: row

        property bool dimmed
        required property string icon
        required property color colour
        required property string label
        required property real value
        required property string valueText
        property real temperature: NaN

        signal toggled

        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight
        opacity: dimmed ? 0.4 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        RowLayout {
            id: rowLayout

            anchors.fill: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: row.icon
                color: row.colour
                fontStyle: Tokens.font.icon.medium
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                StyledProgressBar {
                    Layout.fillWidth: true
                    implicitHeight: Tokens.padding.small
                    value: isNaN(row.value) ? 0 : Math.min(1, row.value)
                    fgColour: row.colour
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: row.label
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: row.valueText
                        font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                        color: row.colour
                    }

                    MaterialIcon {
                        visible: !isNaN(row.temperature)
                        text: row.temperature > 90 ? "thermometer_alert" : "thermometer"
                        color: row.temperature > 90 ? Colours.palette.m3error : row.colour
                        fontStyle: Tokens.font.icon.small
                        fill: 1
                    }

                    StyledText {
                        visible: !isNaN(row.temperature)
                        text: Units.formatSensorTemp(row.temperature)
                        font: Tokens.font.body.small
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }
}
