pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages.battery

PageBase {
    id: root

    // NOTE(fork): thresholds are a QVariantList in config, mirrored into a local
    // JS model for editing and written back on every change
    property list<var> thresholds: [...GlobalConfig.general.battery.powerManagement.thresholds]
    readonly property list<MenuItem> profileItems: [
        MenuItem {
            text: Tr.trCtx("Auto", "default power profile")
            value: ""
        },
        MenuItem {
            text: Tr.tr("Power Saver")
            value: "power-saver"
        },
        MenuItem {
            text: Tr.tr("Balanced")
            value: "balanced"
        },
        MenuItem {
            text: Tr.tr("Performance")
            value: "performance"
        }
    ]

    function saveThresholds(): void {
        GlobalConfig.general.battery.powerManagement.thresholds = root.thresholds;
    }

    title: Tr.tr("Power & battery")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: Tr.tr("Power management")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Enable power management")
            subtext: Tr.tr("Apply power-saving settings automatically")
            checked: GlobalConfig.general.battery.powerManagement.enabled
            onToggled: GlobalConfig.general.battery.powerManagement.enabled = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Power change notifications")
            subtext: Tr.tr("Notify when power-saving settings are applied")
            checked: GlobalConfig.utilities.toasts.lowPowerModeChanged
            onToggled: GlobalConfig.utilities.toasts.lowPowerModeChanged = checked
        }

        // Plugged in
        SectionHeader {
            text: Tr.tr("When plugged in")
        }

        SelectRow {
            first: true
            label: Tr.tr("Power profile")
            menuItems: root.profileItems
            active: root.profileItems.find(item => item.value === GlobalConfig.general.battery.powerManagement.onCharging.setPowerProfile) ?? root.profileItems[0]
            onSelected: item => GlobalConfig.general.battery.powerManagement.onCharging.setPowerProfile = item.value
        }

        RefreshRateSelector {
            last: true
            label: Tr.tr("Refresh rate")
            showRestore: true
            showUnchanged: true
            value: GlobalConfig.general.battery.powerManagement.onCharging.setRefreshRate
            onRateChanged: newValue => GlobalConfig.general.battery.powerManagement.onCharging.setRefreshRate = newValue
        }

        TriStateRow {
            first: true
            label: Tr.tr("Animations")
            value: GlobalConfig.general.battery.powerManagement.onCharging.disableAnimations
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onCharging.disableAnimations = newValue
        }

        TriStateRow {
            label: Tr.tr("Blur")
            value: GlobalConfig.general.battery.powerManagement.onCharging.disableBlur
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onCharging.disableBlur = newValue
        }

        TriStateRow {
            label: Tr.tr("Rounding")
            value: GlobalConfig.general.battery.powerManagement.onCharging.disableRounding
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onCharging.disableRounding = newValue
        }

        TriStateRow {
            last: true
            label: Tr.tr("Shadows")
            value: GlobalConfig.general.battery.powerManagement.onCharging.disableShadows
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onCharging.disableShadows = newValue
        }

        // Unplugged
        SectionHeader {
            text: Tr.tr("On battery")
        }

        SelectRow {
            first: true
            label: Tr.tr("Power profile")
            menuItems: root.profileItems
            active: root.profileItems.find(item => item.value === GlobalConfig.general.battery.powerManagement.onUnplugged.setPowerProfile) ?? root.profileItems[0]
            onSelected: item => GlobalConfig.general.battery.powerManagement.onUnplugged.setPowerProfile = item.value
        }

        RefreshRateSelector {
            last: true
            label: Tr.tr("Refresh rate")
            showRestore: true
            showUnchanged: true
            value: GlobalConfig.general.battery.powerManagement.onUnplugged.setRefreshRate
            onRateChanged: newValue => GlobalConfig.general.battery.powerManagement.onUnplugged.setRefreshRate = newValue
        }

        TriStateRow {
            first: true
            label: Tr.tr("Animations")
            value: GlobalConfig.general.battery.powerManagement.onUnplugged.disableAnimations
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onUnplugged.disableAnimations = newValue
        }

        TriStateRow {
            label: Tr.tr("Blur")
            value: GlobalConfig.general.battery.powerManagement.onUnplugged.disableBlur
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onUnplugged.disableBlur = newValue
        }

        TriStateRow {
            label: Tr.tr("Rounding")
            value: GlobalConfig.general.battery.powerManagement.onUnplugged.disableRounding
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onUnplugged.disableRounding = newValue
        }

        TriStateRow {
            label: Tr.tr("Shadows")
            value: GlobalConfig.general.battery.powerManagement.onUnplugged.disableShadows
            onTriStateValueChanged: newValue => GlobalConfig.general.battery.powerManagement.onUnplugged.disableShadows = newValue
        }

        ToggleRow {
            last: true
            text: Tr.tr("Evaluate battery thresholds")
            subtext: Tr.tr("Also apply the threshold actions below")
            checked: GlobalConfig.general.battery.powerManagement.onUnplugged.evaluateThresholds
            onToggled: GlobalConfig.general.battery.powerManagement.onUnplugged.evaluateThresholds = checked
        }

        // Thresholds
        SectionHeader {
            text: Tr.tr("Battery level thresholds")
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Actions to apply automatically when the battery falls below a level, while on battery power")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.thresholds

            ThresholdCard {
                onThresholdChanged: newData => {
                    const thresholds = [...root.thresholds];
                    thresholds[index] = newData;
                    root.thresholds = thresholds;
                    root.saveThresholds();
                }
                onRemoveRequested: {
                    const thresholds = [...root.thresholds];
                    thresholds.splice(index, 1);
                    root.thresholds = thresholds;
                    root.saveThresholds();
                }
            }
        }

        AddThresholdButton {
            onClicked: {
                const thresholds = [...root.thresholds,
                    {
                        level: 50,
                        setPowerProfile: "",
                        setRefreshRate: "auto",
                        disableAnimations: "",
                        disableBlur: "",
                        disableRounding: "",
                        disableShadows: ""
                    }
                ];
                root.thresholds = thresholds;
                root.saveThresholds();
            }
        }

        // Power profile behaviors
        SectionHeader {
            text: Tr.tr("Power profile behaviors")
        }

        StyledText {
            Layout.fillWidth: true
            text: Tr.tr("Hyprland settings applied while each power profile is active")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            ProfileBehaviorCard {
                Layout.fillWidth: true
                profileName: Tr.tr("Power Saver")
                behavior: GlobalConfig.general.battery.powerManagement.profileBehaviors.powerSaver
            }

            ProfileBehaviorCard {
                Layout.fillWidth: true
                profileName: Tr.tr("Balanced")
                behavior: GlobalConfig.general.battery.powerManagement.profileBehaviors.balanced
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            ProfileBehaviorCard {
                Layout.fillWidth: true
                profileName: Tr.tr("Performance")
                behavior: GlobalConfig.general.battery.powerManagement.profileBehaviors.performance
            }

            Item {
                Layout.fillWidth: true
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }
}
