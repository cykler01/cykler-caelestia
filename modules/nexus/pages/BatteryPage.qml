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
    readonly property var pm: GlobalConfig.general.battery.powerManagement
    // Which profile's behaviour the tabbed card is editing
    property string behaviourTab: "powerSaver"

    function idleKind(entry: var): string {
        const action = entry.idleAction;
        if (action === "lock")
            return "lock";
        if (action === "dpms off")
            return "display";
        if (String(action).toLowerCase().includes("suspend") || String(action).toLowerCase().includes("hibernate"))
            return "sleep";
        return "";
    }

    function idleTimeout(kind: string): int {
        const entry = GlobalConfig.general.idle.timeouts.find(e => root.idleKind(e) === kind);
        return !entry || entry.enabled === false ? 0 : entry.timeout;
    }

    function setIdleTimeout(kind: string, seconds: int): void {
        const list = GlobalConfig.general.idle.timeouts.map(e => Object.assign({}, e));
        const entry = list.find(e => root.idleKind(e) === kind);
        if (entry) {
            entry.enabled = seconds > 0;
            if (seconds > 0)
                entry.timeout = seconds;
        } else if (seconds > 0) {
            const defaults = {
                lock: {
                    idleAction: "lock"
                },
                display: {
                    idleAction: "dpms off",
                    returnAction: "dpms on"
                },
                sleep: {
                    idleAction: ["suspendThenHibernate"]
                }
            };
            list.push(Object.assign({
                timeout: seconds
            }, defaults[kind]));
        }
        GlobalConfig.general.idle.timeouts = list;
    }

    function saveThresholds(): void {
        GlobalConfig.general.battery.powerManagement.thresholds = root.thresholds;
    }

    title: Tr.tr("Power & battery")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        PowerStatusCard {}

        // General
        SectionHeader {
            text: Tr.tr("Power management")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Automatic power management")
            subtext: Tr.tr("Change profile and effects when plugging in, unplugging or running low")
            checked: root.pm.enabled
            onToggled: root.pm.enabled = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Notify when settings change")
            subtext: Tr.tr("Show what was applied after each automatic change")
            checked: GlobalConfig.utilities.toasts.lowPowerModeChanged
            onToggled: GlobalConfig.utilities.toasts.lowPowerModeChanged = checked
        }

        // Everything below only runs with automatic power management on
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2
            enabled: root.pm.enabled
            opacity: enabled ? 1 : 0.5

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            // Power Saver
            SectionHeader {
                text: Tr.tr("Power Saver")
            }

            ToggleRow {
                first: true
                text: Tr.tr("Pause the performance graph")
                subtext: Tr.tr("Stop recording usage history; the dashboard shows the original cards")
                checked: root.pm.pauseGraphInPowerSaver
                onToggled: root.pm.pauseGraphInPowerSaver = checked
            }

            ToggleRow {
                last: true
                text: Tr.tr("Pause audio visualisers")
                subtext: Tr.tr("Stop audio capture for the notch, dashboard and wallpaper visualisers")
                checked: root.pm.pauseVisualisersInPowerSaver
                onToggled: root.pm.pauseVisualisersInPowerSaver = checked
            }

            // Plugged in
            SectionHeader {
                text: Tr.tr("When plugged in")
            }

            PowerProfileSelector {
                first: true
                label: Tr.tr("Power profile")
                subtext: Tr.tr("Previous goes back to the profile from before unplugging")
                showRestore: true
                showUnchanged: true
                value: root.pm.onCharging.setPowerProfile
                onProfileChanged: v => root.pm.onCharging.setPowerProfile = v
            }

            RefreshRateSelector {
                label: Tr.tr("Refresh rate")
                showRestore: true
                showUnchanged: true
                value: root.pm.onCharging.setRefreshRate
                onRateChanged: v => root.pm.onCharging.setRefreshRate = v
            }

            EffectRows {
                target: root.pm.onCharging
                lastRow: true
            }

            // Unplugged
            SectionHeader {
                text: Tr.tr("On battery")
            }

            PowerProfileSelector {
                first: true
                label: Tr.tr("Power profile")
                showUnchanged: true
                value: root.pm.onUnplugged.setPowerProfile === "restore" ? "" : root.pm.onUnplugged.setPowerProfile
                onProfileChanged: v => root.pm.onUnplugged.setPowerProfile = v
            }

            RefreshRateSelector {
                label: Tr.tr("Refresh rate")
                showUnchanged: true
                value: root.pm.onUnplugged.setRefreshRate === "restore" ? "" : root.pm.onUnplugged.setRefreshRate
                onRateChanged: v => root.pm.onUnplugged.setRefreshRate = v
            }

            EffectRows {
                target: root.pm.onUnplugged
            }

            ToggleRow {
                last: true
                text: Tr.tr("Use battery level thresholds")
                subtext: Tr.tr("Also apply the threshold actions below as the battery drains")
                checked: root.pm.onUnplugged.evaluateThresholds
                onToggled: root.pm.onUnplugged.evaluateThresholds = checked
            }

            // Thresholds
            SectionHeader {
                text: Tr.tr("Battery level thresholds")
            }

            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.small
                text: Tr.tr("Actions applied automatically when the battery falls below a level, while on battery power")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: root.thresholds

                ThresholdCard {
                    first: index === 0

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
                first: root.thresholds.length === 0
                last: true

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

            // Power profile behaviours
            SectionHeader {
                text: Tr.tr("Profile behaviours")
            }

            StyledText {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.small
                text: Tr.tr("Applied whenever a profile is switched to. The plugged in, battery and threshold settings above take priority over these")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                wrapMode: Text.WordWrap
            }

            SegmentedButtons {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.spacing.small
                fillWidth: true
                value: root.behaviourTab
                options: [
                    {
                        text: Tr.tr("Power Saver"),
                        icon: "energy_savings_leaf",
                        value: "powerSaver"
                    },
                    {
                        text: Tr.tr("Balanced"),
                        icon: "balance",
                        value: "balanced"
                    },
                    {
                        text: Tr.tr("Performance"),
                        icon: "speed",
                        value: "performance"
                    }
                ]
                onPicked: v => root.behaviourTab = v
            }

            RefreshRateSelector {
                first: true
                label: Tr.tr("Refresh rate")
                showRestore: true
                showUnchanged: true
                value: root.pm.profileBehaviors[root.behaviourTab].setRefreshRate
                onRateChanged: v => root.pm.profileBehaviors[root.behaviourTab].setRefreshRate = v
            }

            EffectRows {
                target: root.pm.profileBehaviors[root.behaviourTab]
                lastRow: true
            }
        }

        // Screen & lock
        SectionHeader {
            text: Tr.tr("Screen & lock")
        }

        TimeoutRow {
            first: true
            label: Tr.tr("Lock after")
            subtext: Tr.tr("Idle time before the device locks")
            value: root.idleTimeout("lock")
            onTimeoutChanged: seconds => root.setIdleTimeout("lock", seconds)
        }

        TimeoutRow {
            label: Tr.tr("Turn off display after")
            subtext: Tr.tr("Idle time before the display turns off")
            value: root.idleTimeout("display")
            onTimeoutChanged: seconds => root.setIdleTimeout("display", seconds)
        }

        TimeoutRow {
            label: Tr.tr("Sleep after")
            subtext: Tr.tr("Idle time before the device suspends")
            value: root.idleTimeout("sleep")
            onTimeoutChanged: seconds => root.setIdleTimeout("sleep", seconds)
        }

        ToggleRow {
            last: true
            text: Tr.tr("Session controls on lock screen")
            subtext: Tr.tr("Show power/reboot/logout buttons while locked")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
        }
    }

    // The four visual effect rows shared by the plug states and profile behaviours
    component EffectRows: ColumnLayout {
        id: effects

        required property var target
        property bool lastRow

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall / 2

        TriStateRow {
            label: Tr.tr("Animations")
            value: effects.target.disableAnimations
            onTriStateValueChanged: v => effects.target.disableAnimations = v
        }

        TriStateRow {
            label: Tr.tr("Blur")
            value: effects.target.disableBlur
            onTriStateValueChanged: v => effects.target.disableBlur = v
        }

        TriStateRow {
            label: Tr.tr("Rounding")
            value: effects.target.disableRounding
            onTriStateValueChanged: v => effects.target.disableRounding = v
        }

        TriStateRow {
            last: effects.lastRow
            label: Tr.tr("Shadows")
            value: effects.target.disableShadows
            onTriStateValueChanged: v => effects.target.disableShadows = v
        }
    }
}
