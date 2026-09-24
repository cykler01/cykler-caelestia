pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Battery level, charge state and power draw, with the power profile switcher (fork feature)
StyledRect {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool hasBattery: device.isLaptopBattery
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(device.state)

    function formatDuration(seconds: real): string {
        const hr = Math.floor(seconds / 3600);
        const min = Math.floor((seconds % 3600) / 60);
        if (hr > 0)
            // TRANSLATORS: %1 = hours, %2 = minutes
            return Tr.trCtx("%1h %2m", "battery time remaining").arg(hr).arg(min);
        // TRANSLATORS: %1 = minutes
        return Tr.trCtx("%1m", "battery time remaining").arg(min);
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    color: Colours.tPalette.m3surfaceContainer
    radius: Tokens.rounding.extraLarge

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: root.hasBattery
            spacing: Tokens.spacing.large

            MaterialIcon {
                text: {
                    if (root.charging)
                        return "battery_charging_full";
                    const level = Math.round(root.device.percentage * 6);
                    return level >= 6 ? "battery_full" : `battery_${level}_bar`;
                }
                color: root.device.percentage <= 0.2 && !root.charging ? Colours.palette.m3error : Colours.palette.m3primary
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(1.5).build()
                fill: 1
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: Strings.percentOne(root.device.percentage)
                    font: Tokens.font.headline.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (root.device.state === UPowerDeviceState.FullyCharged)
                            return Tr.tr("Fully charged");
                        if (root.charging)
                            return root.device.timeToFull > 0 ? Tr.tr("Charging · full in %1").arg(root.formatDuration(root.device.timeToFull)) : Tr.tr("Charging");
                        return root.device.timeToEmpty > 0 ? Tr.tr("On battery · %1 left").arg(root.formatDuration(root.device.timeToEmpty)) : Tr.tr("On battery");
                    }
                    font: Tokens.font.body.medium
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                visible: root.device.changeRate > 0
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: `${root.device.changeRate.toFixed(1)} W`
                    font: Tokens.font.title.medium
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: root.charging ? Tr.tr("charging rate") : Tr.tr("power draw")
                    font: Tokens.font.label.small
                    color: Colours.palette.m3outline
                }
            }
        }

        SegmentedButtons {
            Layout.fillWidth: true
            fillWidth: true
            value: {
                if (PowerProfiles.profile === PowerProfile.PowerSaver)
                    return "power-saver";
                if (PowerProfiles.profile === PowerProfile.Performance)
                    return "performance";
                return "balanced";
            }
            options: {
                const opts = [
                    {
                        text: Tr.tr("Power Saver"),
                        icon: "energy_savings_leaf",
                        value: "power-saver"
                    },
                    {
                        text: Tr.tr("Balanced"),
                        icon: "balance",
                        value: "balanced"
                    }
                ];
                if (PowerProfiles.hasPerformanceProfile)
                    opts.push({
                        text: Tr.tr("Performance"),
                        icon: "speed",
                        value: "performance"
                    });
                return opts;
            }
            onPicked: v => {
                if (v === "power-saver")
                    PowerProfiles.profile = PowerProfile.PowerSaver;
                else if (v === "performance")
                    PowerProfiles.profile = PowerProfile.Performance;
                else
                    PowerProfiles.profile = PowerProfile.Balanced;
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            visible: PowerSaving.pauseGraph || PowerSaving.pauseVisualisers
            text: {
                const paused = [];
                if (PowerSaving.pauseGraph)
                    paused.push(Tr.tr("performance graph"));
                if (PowerSaving.pauseVisualisers)
                    paused.push(Tr.tr("audio visualisers"));
                // TRANSLATORS: %1 = list of paused shell features
                return Tr.tr("Power Saver is pausing: %1").arg(paused.join(", "));
            }
            font: Tokens.font.label.small
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }
    }
}
