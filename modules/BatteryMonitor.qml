import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.services

Scope {
    id: root

    readonly property list<var> warnLevels: [...GlobalConfig.general.battery.warnLevels].sort((a, b) => a.level - b.level)
    // NOTE(fork): power management config, sorted from most severe to least
    readonly property list<var> powerThresholds: [...GlobalConfig.general.battery.powerManagement.thresholds].sort((a, b) => b.level - a.level)
    readonly property bool powerManagementEnabled: GlobalConfig.general.battery.powerManagement.enabled

    property real lastPercentage: 100
    property var originalSettings: ({
            refreshRates: {}
        })
    property int currentThresholdIndex: -1
    property bool settingsModified: false

    function handleBatteryWarnings(): void {
        const p = UPower.displayDevice.percentage * 100;

        if (!UPower.onBattery) {
            root.lastPercentage = p;
            return;
        }

        if (root.lastPercentage >= 0) {
            for (const level of root.warnLevels) {
                if (p <= level.level && root.lastPercentage > level.level) {
                    Toaster.toast(Tr.trMarked(level.title ?? Tr.tr("Battery warning")), Tr.trMarked(level.message ?? Tr.tr("Battery level is low")), level.icon ?? "battery_android_alert", level.critical ? Toast.Error : Toast.Warning);
                    break;
                }
            }
        }

        if (!hibernateTimer.running && p <= GlobalConfig.general.battery.criticalLevel) {
            Toaster.toast(Tr.tr("Hibernating in 5 seconds"), Tr.tr("Hibernating to prevent data loss"), "battery_android_alert", Toast.Error);
            hibernateTimer.start();
        }

        if (root.powerManagementEnabled)
            root.evaluateThresholds();

        root.lastPercentage = p;
    }

    // NOTE(fork): apply hyprland visual effect options based on a power action schema
    function applyVisualEffects(settings): void {
        const options = {};

        if (settings.disableAnimations === "disable")
            options["animations:enabled"] = 0;
        else if (settings.disableAnimations === "enable")
            options["animations:enabled"] = 1;

        if (settings.disableBlur === "disable")
            options["decoration:blur:enabled"] = 0;
        else if (settings.disableBlur === "enable")
            options["decoration:blur:enabled"] = 1;

        if (settings.disableRounding === "disable")
            options["decoration:rounding"] = 0;
        else if (settings.disableRounding === "enable")
            options["decoration:rounding"] = TokenConfig.appearance.rounding.medium;

        if (settings.disableShadows === "disable")
            options["decoration:shadow:enabled"] = 0;
        else if (settings.disableShadows === "enable")
            options["decoration:shadow:enabled"] = 1;

        if (Object.keys(options).length > 0)
            Hypr.extras.applyOptions(options);
    }

    // NOTE(fork): set monitor refresh rates. rate: "auto" | "restore" | <number>
    function applyRefreshRate(rate): void {
        let targetRate;

        if (rate === "auto") {
            targetRate = root.getLowestRefreshRate();
        } else if (rate === "restore") {
            root.restoreRefreshRates();
            return;
        } else {
            targetRate = rate;
        }

        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (!data)
                continue;

            // NOTE(fork): lua Hyprland removed "keyword monitor"; use hl.monitor() there
            if (Hypr.usingLua)
                Hypr.extras.message(`eval hl.monitor({ output = "${data.name}", mode = "${data.width}x${data.height}@${targetRate}", position = "${data.x}x${data.y}", scale = ${data.scale} });`);
            else
                Hypr.extras.message(`keyword monitor ${data.name},${data.width}x${data.height}@${targetRate},${data.x}x${data.y},${data.scale}`);
        }
    }

    function getLowestRefreshRate(): int {
        let lowestRate = 60; // Default fallback

        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (data?.availableModes) {
                const supportedRates = [];
                for (const mode of data.availableModes) {
                    const match = mode.match(/@(\d+(?:\.\d+)?)Hz/);
                    if (match) {
                        const rate = Math.round(parseFloat(match[1]));
                        if (!supportedRates.includes(rate))
                            supportedRates.push(rate);
                    }
                }

                supportedRates.sort((a, b) => a - b);
                if (supportedRates.length > 0)
                    lowestRate = Math.min(lowestRate, supportedRates[0]);
            }
        }

        return lowestRate;
    }

    function setPowerProfile(profileName): void {
        const profileMap = {
            "power-saver": PowerProfile.PowerSaver,
            "balanced": PowerProfile.Balanced,
            "performance": PowerProfile.Performance
        };
        if (profileMap[profileName] !== undefined)
            PowerProfiles.profile = profileMap[profileName];
    }

    function saveOriginalSettings(): void {
        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (data)
                root.originalSettings.refreshRates[data.name] = data.refreshRate;
        }
    }

    function restoreRefreshRates(): void {
        for (const monitor of Hypr.monitors.values) {
            const data = monitor.lastIpcObject;
            if (data && root.originalSettings.refreshRates[data.name]) {
                const originalRate = root.originalSettings.refreshRates[data.name];

                if (Hypr.usingLua)
                    Hypr.extras.message(`eval hl.monitor({ output = "${data.name}", mode = "${data.width}x${data.height}@${originalRate}", position = "${data.x}x${data.y}", scale = ${data.scale} });`);
                else
                    Hypr.extras.message(`keyword monitor ${data.name},${data.width}x${data.height}@${originalRate},${data.x}x${data.y},${data.scale}`);
            }
        }
    }

    function applyPowerSavingSettings(settings): void {
        root.applyVisualEffects(settings);

        if (settings.setRefreshRate !== null && settings.setRefreshRate !== undefined && settings.setRefreshRate !== "")
            root.applyRefreshRate(settings.setRefreshRate);
    }

    function handleUnpluggedState(): void {
        const unpluggedConfig = GlobalConfig.general.battery.powerManagement.onUnplugged;

        const hasExplicitActions = (unpluggedConfig.setPowerProfile && unpluggedConfig.setPowerProfile !== "") || (unpluggedConfig.setRefreshRate && unpluggedConfig.setRefreshRate !== "") || unpluggedConfig.disableAnimations !== "" || unpluggedConfig.disableBlur !== "" || unpluggedConfig.disableRounding !== "" || unpluggedConfig.disableShadows !== "";

        if (hasExplicitActions) {
            if (!root.settingsModified)
                root.saveOriginalSettings();

            if (unpluggedConfig.setPowerProfile && unpluggedConfig.setPowerProfile !== "")
                root.setPowerProfile(unpluggedConfig.setPowerProfile);

            root.applyPowerSavingSettings({
                disableAnimations: unpluggedConfig.disableAnimations,
                disableBlur: unpluggedConfig.disableBlur,
                disableRounding: unpluggedConfig.disableRounding,
                disableShadows: unpluggedConfig.disableShadows,
                setRefreshRate: (unpluggedConfig.setRefreshRate && unpluggedConfig.setRefreshRate !== "") ? unpluggedConfig.setRefreshRate : null
            });
            root.settingsModified = true;
        }

        if (unpluggedConfig.evaluateThresholds)
            root.evaluateThresholds();
    }

    function evaluateThresholds(): void {
        if (!UPower.onBattery || !root.powerManagementEnabled)
            return;

        const p = UPower.displayDevice.percentage * 100;

        let targetThresholdIndex = -1;
        for (let i = 0; i < root.powerThresholds.length; i++) {
            if (p <= root.powerThresholds[i].level) {
                targetThresholdIndex = i;
                break;
            }
        }

        if (targetThresholdIndex !== root.currentThresholdIndex) {
            root.currentThresholdIndex = targetThresholdIndex;

            if (targetThresholdIndex >= 0)
                root.applyThreshold(root.powerThresholds[targetThresholdIndex]);
        }
    }

    function applyThreshold(threshold): void {
        if (!root.settingsModified)
            root.saveOriginalSettings();

        if (threshold.setPowerProfile && threshold.setPowerProfile !== "")
            root.setPowerProfile(threshold.setPowerProfile);

        root.applyPowerSavingSettings(threshold);

        root.settingsModified = true;

        if (GlobalConfig.utilities.toasts.lowPowerModeChanged) {
            const actions = [];
            if (threshold.setPowerProfile && threshold.setPowerProfile !== "")
                actions.push("profile: " + threshold.setPowerProfile);
            if (threshold.setRefreshRate && threshold.setRefreshRate !== "")
                actions.push(threshold.setRefreshRate === "auto" ? "lowest Hz" : threshold.setRefreshRate + "Hz");
            if (threshold.disableAnimations === "disable")
                actions.push("no animations");
            else if (threshold.disableAnimations === "enable")
                actions.push("animations on");
            if (threshold.disableBlur === "disable")
                actions.push("no blur");
            else if (threshold.disableBlur === "enable")
                actions.push("blur on");

            if (actions.length > 0)
                Toaster.toast(Tr.tr("Battery saving active"), Tr.tr("Applied: %1").arg(actions.join(", ")), "battery_saver");
        }
    }

    function handleChargingState(): void {
        const config = GlobalConfig.general.battery.powerManagement.onCharging;

        if (config.setPowerProfile === "restore")
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (config.setPowerProfile && config.setPowerProfile !== "")
            root.setPowerProfile(config.setPowerProfile);

        if (config.setRefreshRate && config.setRefreshRate !== "" && config.setRefreshRate !== "unchanged")
            root.applyRefreshRate(config.setRefreshRate);

        root.applyVisualEffects(config);

        root.settingsModified = false;
        root.currentThresholdIndex = -1;
    }

    Connections {
        function onOnBatteryChanged(): void {
            if (!UPower.displayDevice.ready)
                return;

            if (UPower.onBattery) {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(Tr.tr("Charger unplugged"), Tr.tr("Battery is discharging"), "power_off");
                root.handleBatteryWarnings();

                // NOTE(fork): apply power saving settings on unplug
                if (root.powerManagementEnabled)
                    root.handleUnpluggedState();
            } else {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(Tr.tr("Charger plugged in"), Tr.tr("Battery is charging"), "power");
                root.lastPercentage = 100;

                // NOTE(fork): restore settings on plug in
                if (root.powerManagementEnabled && root.settingsModified)
                    root.handleChargingState();
            }
        }

        target: UPower
    }

    Connections {
        function onReadyChanged(): void {
            if (!UPower.displayDevice.ready)
                return;
            root.handleBatteryWarnings();
        }

        target: UPower.displayDevice
    }

    Connections {
        function onPercentageChanged(): void {
            if (!UPower.displayDevice.ready)
                return;
            root.handleBatteryWarnings();
        }

        target: UPower.displayDevice
    }

    // NOTE(fork): react to power profile changes made outside the shell
    Connections {
        function onProfileChanged(): void {
            if (!root.powerManagementEnabled)
                return;

            const profileBehaviors = GlobalConfig.general.battery.powerManagement.profileBehaviors;
            let behavior = null;
            let profileName = "";

            if (PowerProfiles.profile === PowerProfile.PowerSaver) {
                behavior = profileBehaviors.powerSaver;
                profileName = Tr.tr("Power Saver");
            } else if (PowerProfiles.profile === PowerProfile.Balanced) {
                behavior = profileBehaviors.balanced;
                profileName = Tr.tr("Balanced");
            } else if (PowerProfiles.profile === PowerProfile.Performance) {
                behavior = profileBehaviors.performance;
                profileName = Tr.tr("Performance");
            }

            if (!behavior)
                return;

            if (behavior.setRefreshRate && behavior.setRefreshRate !== "" && behavior.setRefreshRate !== "unchanged")
                root.applyRefreshRate(behavior.setRefreshRate);

            root.applyVisualEffects(behavior);

            if (GlobalConfig.utilities.toasts.lowPowerModeChanged) {
                const actions = [];
                if (behavior.setRefreshRate && behavior.setRefreshRate !== "" && behavior.setRefreshRate !== "restore")
                    actions.push(behavior.setRefreshRate === "auto" ? "lowest Hz" : behavior.setRefreshRate + "Hz");
                if (behavior.disableAnimations === "disable")
                    actions.push("no animations");
                else if (behavior.disableAnimations === "enable")
                    actions.push("animations on");
                if (behavior.disableBlur === "disable")
                    actions.push("no blur");
                else if (behavior.disableBlur === "enable")
                    actions.push("blur on");
                if (behavior.disableRounding === "disable")
                    actions.push("no rounding");
                else if (behavior.disableRounding === "enable")
                    actions.push("rounding on");
                if (behavior.disableShadows === "disable")
                    actions.push("no shadows");
                else if (behavior.disableShadows === "enable")
                    actions.push("shadows on");

                if (actions.length > 0)
                    Toaster.toast(Tr.tr("%1 profile").arg(profileName), Tr.tr("Applied: %1").arg(actions.join(", ")), "battery_saver");
            }
        }

        target: PowerProfiles
    }

    Timer {
        id: hibernateTimer

        interval: 5000
        onTriggered: SessionManager.hibernate()
    }
}
