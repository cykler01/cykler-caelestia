pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services
import qs.modules.background

// --- Temperatures: the processor and graphics card as two gauges, every sensor the machine has as a list, or
// just the hottest one. Read from hwmon through services/Sensors.qml, which only polls while a card holds it ---
WidgetCard {
    id: therm

    readonly property string style: therm.variant === "detail" || therm.variant === "compact" ? therm.variant : "gauges"

    // hwmon has no reading for a graphics card on NVIDIA's own driver, and some machines name their CPU chip in
    // a way Sensors does not know. Either falls back to the reading the Cpu and Gpu services already take
    readonly property bool cpuFromService: Sensors.loaded && Sensors.cpu < 0
    readonly property bool gpuFromService: Sensors.loaded && Sensors.gpu < 0 && Gpu.type !== GpuType.None
    readonly property real cpuTemp: Sensors.cpu >= 0 ? Sensors.cpu : therm.cpuFromService ? Cpu.temperature : -1
    readonly property real gpuTemp: Sensors.gpu >= 0 ? Sensors.gpu : therm.gpuFromService ? Gpu.temperature : -1

    // With no graphics card to show, the second gauge goes to the warmest of whatever else there is (usually a
    // drive), rather than sitting empty
    readonly property var second: {
        if (therm.gpuTemp > 0)
            return {
                label: "GPU",
                icon: "videogame_asset",
                value: therm.gpuTemp,
                crit: 0
            };
        const rest = Sensors.temperatures.filter(r => r.kind !== "cpu" && r.kind !== "gpu").sort((a, b) => b.value - a.value)[0];
        return rest ? {
            label: rest.label,
            icon: therm.iconFor(rest.kind),
            value: rest.value,
            crit: rest.crit
        } : null;
    }

    function iconFor(kind: string): string {
        if (kind === "cpu")
            return "memory";
        if (kind === "gpu")
            return "videogame_asset";
        if (kind === "drive")
            return "hard_drive";
        if (kind === "wifi")
            return "wifi";
        if (kind === "fan")
            return "mode_fan";
        return "thermostat";
    }

    // Three bands rather than a blend, so a glance tells you which one you are in: the scheme's own colour
    // while cool, its tertiary as things warm up, and the error colour once it is close to the limit
    function heatColour(heat: real): color {
        if (heat >= 0.8)
            return Colours.palette.m3error;
        if (heat >= 0.5)
            return Colours.palette.m3tertiary;
        return Colours.palette.m3primary;
    }

    function heatWord(heat: real): string {
        if (heat >= 0.8)
            return Tr.tr("Hot");
        if (heat >= 0.5)
            return Tr.tr("Warm");
        return Tr.tr("Cool");
    }

    // The fan that goes with a part, when the machine names its fans that way (most laptops do)
    function fanFor(kind: string): var {
        const pattern = kind === "gpu" ? /gpu/i : /cpu/i;
        return Sensors.fans.find(f => pattern.test(f.label)) ?? (kind === "cpu" ? Sensors.fans[0] ?? null : null);
    }

    title: therm.style === "compact" ? "" : Tr.tr("Temperatures")
    icon: "thermostat"
    padding: therm.style === "compact" ? Tokens.padding.large : Tokens.padding.largeIncreased

    Ref {
        service: Sensors
    }

    ServiceRef {
        service: therm.cpuFromService ? Cpu : null
    }

    ServiceRef {
        service: therm.gpuFromService ? Gpu : null
    }

    // Gauges: two arcs side by side, the reading in the middle and what it is beside it
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: therm.style === "gauges"
        spacing: Tokens.spacing.medium
        uniformCellSizes: true

        Gauge {
            label: "CPU"
            icon: "memory"
            value: therm.cpuTemp
            fan: therm.fanFor("cpu")
        }

        Gauge {
            label: therm.second?.label ?? "GPU"
            icon: therm.second?.icon ?? "videogame_asset"
            value: therm.second?.value ?? -1
            crit: therm.second?.crit ?? 0
            fan: therm.gpuTemp > 0 ? therm.fanFor("gpu") : null
        }
    }

    // Detail: every sensor, a row each, with the fans at the bottom. Scrolls rather than growing the card
    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        visible: therm.style === "detail"
        clip: true
        spacing: Tokens.spacing.extraSmall
        interactive: contentHeight > height
        model: therm.style === "detail" ? Sensors.readings : []

        delegate: SensorRow {}
    }

    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: therm.style === "detail" && Sensors.loaded && Sensors.readings.length === 0
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        text: Tr.tr("No temperature sensors found")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    // Compact: the hottest reading, and a bar per sensor beside it so the rest are not forgotten
    RowLayout {
        id: compact

        readonly property var hot: Sensors.hottest
        readonly property real heat: compact.hot ? Sensors.heat(compact.hot.value, compact.hot.crit) : 0

        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: therm.style === "compact"
        spacing: Tokens.spacing.medium

        StyledRect {
            implicitWidth: implicitHeight
            implicitHeight: hotIcon.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            color: Qt.alpha(therm.heatColour(compact.heat), 0.18)

            MaterialIcon {
                id: hotIcon

                anchors.centerIn: parent
                text: compact.hot ? therm.iconFor(compact.hot.kind) : "thermostat"
                color: therm.heatColour(compact.heat)
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                text: compact.hot ? Units.formatSensorTemp(compact.hot.value) : "–"
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: compact.hot ? compact.hot.label : Sensors.loaded ? Tr.tr("No sensors") : ""
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        Row {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: hotIcon.implicitHeight + Tokens.padding.small * 2
            spacing: 3

            Repeater {
                model: therm.style === "compact" ? Sensors.temperatures : []

                Item {
                    id: pip

                    required property var modelData
                    readonly property real heat: Sensors.heat(pip.modelData.value, pip.modelData.crit)

                    width: 4
                    height: parent.height

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3surfaceContainerHighest
                    }

                    StyledRect {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: Math.max(width, parent.height * Math.max(0.05, pip.heat))
                        radius: Tokens.rounding.full
                        color: therm.heatColour(pip.heat)
                    }
                }
            }
        }
    }

    component Gauge: RowLayout {
        id: gauge

        property string label
        property string icon
        property real value: -1
        property real crit: 0
        property var fan: null

        readonly property bool known: gauge.value > 0
        readonly property real heat: gauge.known ? Sensors.heat(gauge.value, gauge.crit) : 0
        readonly property color colour: gauge.known ? therm.heatColour(gauge.heat) : Colours.palette.m3outline

        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        // Three quarters of a circle, open at the bottom like a dial. It fills against 100 degrees (or the
        // part's own limit) rather than from room temperature, so a cool machine still shows some arc
        CircularProgress {
            implicitSize: 66
            strokeWidth: 6
            startAngle: 135
            sweepAngle: 270
            value: gauge.known ? gauge.value / (gauge.crit > 0 ? gauge.crit : 100) : 0
            fgColour: gauge.colour
            bgColour: Colours.palette.m3surfaceContainerHighest

            // Short and without overshoot: it only moves once every few seconds
            Behavior on clampedVal {
                Anim {
                    type: Anim.FastEffects
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: gauge.known ? Units.formatSensorTemp(gauge.value) : "–"
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
            }

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: gauge.icon
                color: gauge.colour
                fontStyle: Tokens.font.icon.small
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: gauge.label
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: gauge.known ? therm.heatWord(gauge.heat) : Tr.tr("No reading")
                color: gauge.colour
                font: Tokens.font.label.small
            }

            RowLayout {
                Layout.fillWidth: true
                visible: gauge.fan !== null
                spacing: 2

                MaterialIcon {
                    text: "mode_fan"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.size(Tokens.font.label.small.pointSize).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: gauge.fan ? `${gauge.fan.value}` : ""
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }
    }

    component SensorRow: RowLayout {
        id: row

        required property var modelData
        readonly property bool isFan: row.modelData.kind === "fan"
        // A fan has no limit to measure against; it is drawn against a brisk laptop fan's top speed instead
        readonly property real fill: row.isFan ? Math.min(1, row.modelData.value / 6000) : Sensors.heat(row.modelData.value, row.modelData.crit)
        readonly property color colour: row.isFan ? Colours.palette.m3secondary : therm.heatColour(row.fill)

        width: ListView.view.width
        // A touch shorter than the text would make it, so a laptop's usual six readings fit the card without
        // the last one cut in half
        height: 22
        spacing: Tokens.spacing.small

        MaterialIcon {
            text: therm.iconFor(row.modelData.kind)
            color: row.colour
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: row.modelData.label
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.medium
        }

        StyledRect {
            implicitWidth: 64
            implicitHeight: 4
            radius: Tokens.rounding.full
            color: Colours.palette.m3surfaceContainerHighest

            StyledRect {
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, row.fill)))
                height: parent.height
                radius: Tokens.rounding.full
                color: row.colour
            }
        }

        StyledText {
            Layout.preferredWidth: 64
            horizontalAlignment: Text.AlignRight
            text: row.isFan ? Tr.tr("%1 RPM").arg(row.modelData.value) : Units.formatSensorTemp(row.modelData.value)
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
        }
    }
}
