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
    // Profile active before the shell first changed it, for "restore" (-1 = nothing saved)
    property int originalProfile: -1
    // Profile the shell just switched to itself, so onProfileChanged doesn't re-apply that
    // profile's behaviour over the settings that asked for it (-1 = none pending)
    property int expectedProfile: -1
    // Whether the current plug state has been applied since the shell started
    property bool initialised: false

    readonly property list<string> effectKeys: ["disableAnimations", "disableBlur", "disableRounding", "disableShadows"]

    // NOTE(fork): critical-battery shell shutdown. Seconds left on the countdown (0 = not counting down), and
    // whether the shell has already been told to unload (so it is only asked once)
    property int shutdownRemaining: 0
    property bool shutdownFired: false
    readonly property var shutdownConfig: GlobalConfig.general.battery.powerManagement.shellShutdown

    function shutdownText(secs: int): string {
        return secs >= 60 && secs % 60 === 0 ? Tr.tr("%1 min").arg(secs / 60) : Tr.tr("%1 s").arg(secs);
    }

    function warnShutdown(secs: int): void {
        // The first toast stays up for the whole countdown; later reminders are shorter
        Toaster.toast(Tr.tr("Critical battery"), Tr.tr("Shell shuts down in %1. Plug in to cancel.").arg(root.shutdownText(secs)), "battery_android_alert", Toast.Error, Math.max(5000, secs * 1000));
    }

    function startShellShutdown(): void {
        root.shutdownRemaining = Math.max(1, root.shutdownConfig.delay);
        root.warnShutdown(root.shutdownRemaining);
        shutdownTimer.start();
    }

    function cancelShellShutdown(): void {
        if (!shutdownTimer.running)
            return;

        shutdownTimer.stop();
        root.shutdownRemaining = 0;
        Toaster.toast(Tr.tr("Shell shutdown cancelled"), Tr.tr("The battery is no longer critical"), "battery_charging_full", Toast.Success);
    }

    // Starts the countdown once the battery is at or below the level while unplugged, and cancels it if a charger
    // goes in or the level comes back up
    function checkShellShutdown(p: real): void {
        const critical = root.shutdownConfig.enabled && UPower.onBattery && p <= root.shutdownConfig.level;
        if (critical && !shutdownTimer.running && !root.shutdownFired)
            root.startShellShutdown();
        else if (!critical && shutdownTimer.running)
            root.cancelShellShutdown();

        if (!critical)
            root.shutdownFired = false;
    }

    function handleBatteryWarnings(): void {
        const p = UPower.displayDevice.percentage * 100;
        root.checkShellShutdown(p);

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
        // The shell's own effects follow the same switches as Hyprland's
        PowerSaving.applyEffects(settings);

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

    function profileFromName(name: string): int {
        if (name === "power-saver")
            return PowerProfile.PowerSaver;
        if (name === "balanced")
            return PowerProfile.Balanced;
        if (name === "performance")
            return PowerProfile.Performance;
        return -1;
    }

    function behaviourFor(profile: int): var {
        const behaviours = GlobalConfig.general.battery.powerManagement.profileBehaviors;
        if (profile === PowerProfile.PowerSaver)
            return behaviours.powerSaver;
        if (profile === PowerProfile.Performance)
            return behaviours.performance;
        if (profile === PowerProfile.Balanced)
            return behaviours.balanced;
        return null;
    }

    function hasValue(value: var): bool {
        return value !== undefined && value !== null && value !== "" && value !== "unchanged";
    }

    // NOTE(fork): applies a set of power actions (plug state, threshold or profile behaviour).
    // A profile switch also brings in that profile's behaviour, with the actions' own settings
    // taking precedence, so switching profile never undoes what the actions asked for.
    // Returns a short description of what was applied, for toasts.
    function applyActions(actions: var, restoreFallback: int): list<string> {
        let profile = -1;
        if (actions.setPowerProfile === "restore")
            profile = root.originalProfile >= 0 ? root.originalProfile : restoreFallback;
        else
            profile = root.profileFromName(actions.setPowerProfile ?? "");

        const behaviour = profile >= 0 ? root.behaviourFor(profile) : null;
        const effects = {};
        for (const key of root.effectKeys)
            effects[key] = root.hasValue(actions[key]) ? actions[key] : (behaviour && root.hasValue(behaviour[key]) ? behaviour[key] : "");

        let rate = "";
        if (root.hasValue(actions.setRefreshRate))
            rate = actions.setRefreshRate;
        else if (behaviour && root.hasValue(behaviour.setRefreshRate))
            rate = behaviour.setRefreshRate;

        if (profile >= 0 && PowerProfiles.profile !== profile) {
            root.expectedProfile = profile;
            PowerProfiles.profile = profile;
        }

        root.applyVisualEffects(effects);
        if (rate)
            root.applyRefreshRate(rate);

        return root.describe(profile, rate, effects);
    }

    function describe(profile: int, rate: string, effects: var): list<string> {
        const applied = [];
        if (profile === PowerProfile.PowerSaver)
            applied.push(Tr.tr("Power Saver"));
        else if (profile === PowerProfile.Balanced)
            applied.push(Tr.tr("Balanced"));
        else if (profile === PowerProfile.Performance)
            applied.push(Tr.tr("Performance"));

        if (rate === "auto")
            applied.push(Tr.tr("lowest Hz"));
        else if (rate === "restore")
            applied.push(Tr.tr("original Hz"));
        else if (rate)
            applied.push(`${rate}Hz`);

        const names = {
            disableAnimations: Tr.tr("animations"),
            disableBlur: Tr.tr("blur"),
            disableRounding: Tr.tr("rounding"),
            disableShadows: Tr.tr("shadows")
        };
        for (const key of root.effectKeys) {
            if (effects[key] === "disable")
                // TRANSLATORS: %1 = a visual effect, e.g. "blur"
                applied.push(Tr.tr("no %1").arg(names[key]));
            else if (effects[key] === "enable")
                // TRANSLATORS: %1 = a visual effect, e.g. "blur"
                applied.push(Tr.tr("%1 on").arg(names[key]));
        }
        return applied;
    }

    function toastApplied(title: string, applied: list<string>): void {
        if (GlobalConfig.utilities.toasts.lowPowerModeChanged && applied.length > 0)
            Toaster.toast(title, Tr.tr("Applied: %1").arg(applied.join(", ")), "battery_saver");
    }

    function saveOriginalSettings(): void {
        root.originalProfile = PowerProfiles.profile;
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

    function handleUnpluggedState(silent: bool): void {
        const config = GlobalConfig.general.battery.powerManagement.onUnplugged;

        if (!root.settingsModified)
            root.saveOriginalSettings();

        const applied = root.applyActions(config, -1);
        root.settingsModified = true;
        if (!silent)
            root.toastApplied(Tr.tr("On battery"), applied);

        root.currentThresholdIndex = -1;
        if (config.evaluateThresholds)
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

        const applied = root.applyActions(threshold, -1);
        root.settingsModified = true;
        root.toastApplied(Tr.tr("Battery saving active"), applied);
    }

    // NOTE(fork): runs on every plug-in, not only after the shell changed something on unplug,
    // so plugging in always gives the "When plugged in" settings
    function handleChargingState(silent: bool): void {
        const applied = root.applyActions(GlobalConfig.general.battery.powerManagement.onCharging, PowerProfile.Balanced);

        root.settingsModified = false;
        root.originalProfile = -1;
        root.currentThresholdIndex = -1;
        if (!silent)
            root.toastApplied(Tr.tr("Plugged in"), applied);
    }

    // NOTE(fork): applies the settings for the current plug state once the battery is known,
    // so they hold after a shell restart instead of waiting for the next plug or unplug
    function applyCurrentState(): void {
        if (root.initialised || !root.powerManagementEnabled || !UPower.displayDevice.ready)
            return;

        root.initialised = true;
        if (UPower.onBattery)
            root.handleUnpluggedState(true);
        else
            root.handleChargingState(true);
    }

    onPowerManagementEnabledChanged: {
        root.initialised = false;
        startupTimer.restart();
    }

    Component.onCompleted: startupTimer.start()

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
                    root.handleUnpluggedState(false);
            } else {
                if (GlobalConfig.utilities.toasts.chargingChanged)
                    Toaster.toast(Tr.tr("Charger plugged in"), Tr.tr("Battery is charging"), "power");
                root.lastPercentage = 100;
                root.cancelShellShutdown();
                root.shutdownFired = false;

                // NOTE(fork): apply the plugged-in settings
                if (root.powerManagementEnabled)
                    root.handleChargingState(false);
            }
        }

        target: UPower
    }

    Connections {
        function onReadyChanged(): void {
            if (!UPower.displayDevice.ready)
                return;
            root.handleBatteryWarnings();
            startupTimer.restart();
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

    // NOTE(fork): react to power profile changes made outside the shell (e.g. the bar's battery
    // popout) by applying that profile's behaviour. Changes the shell made itself already
    // included it, merged under the settings that asked for them, so they are skipped here.
    Connections {
        function onProfileChanged(): void {
            const expected = root.expectedProfile;
            root.expectedProfile = -1;
            if (!root.powerManagementEnabled || PowerProfiles.profile === expected)
                return;

            const behaviour = root.behaviourFor(PowerProfiles.profile);
            if (!behaviour)
                return;

            const applied = root.applyActions({
                setPowerProfile: "",
                setRefreshRate: behaviour.setRefreshRate,
                disableAnimations: behaviour.disableAnimations,
                disableBlur: behaviour.disableBlur,
                disableRounding: behaviour.disableRounding,
                disableShadows: behaviour.disableShadows
            }, -1);
            root.toastApplied(root.describe(PowerProfiles.profile, "", {})[0] ?? "", applied);
        }

        target: PowerProfiles
    }

    // NOTE(fork): counts the critical-battery warning down and then unloads the shell (`caelestia shell -k`)
    Timer {
        id: shutdownTimer

        interval: 1000
        repeat: true
        onTriggered: {
            root.shutdownRemaining--;
            if (root.shutdownRemaining === 30 || root.shutdownRemaining === 10)
                root.warnShutdown(root.shutdownRemaining);

            if (root.shutdownRemaining <= 0) {
                shutdownTimer.stop();
                root.shutdownFired = true;
                root.runShutdown();
            }
        }
    }

    // Split out so the command is in one place
    function runShutdown(): void {
        Quickshell.execDetached(["caelestia", "shell", "-k"]);
    }

    // Gives Hyprland's monitor list a moment to load before the startup state is applied,
    // since refresh rates are set per monitor
    Timer {
        id: startupTimer

        interval: 1500
        onTriggered: root.applyCurrentState()
    }

    Timer {
        id: hibernateTimer

        interval: 5000
        onTriggered: SessionManager.hibernate()
    }
}
