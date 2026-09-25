pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Caelestia.Config

// Shell features to pause while the Power Saver profile is active, so battery saver saves more
// than the CPU governor does. Controlled from Power & battery > Power Saver.
Singleton {
    id: root

    readonly property var pm: GlobalConfig.general.battery.powerManagement
    // Unplugged. One place for the whole shell to ask, so the decorative-motion rules all agree.
    readonly property bool onBattery: UPower.onBattery
    readonly property bool powerSaver: PowerProfiles.profile === PowerProfile.PowerSaver

    // Stops the performance graph's background recording; the dashboard shows the original cards
    readonly property bool pauseGraph: pm.enabled && powerSaver && pm.pauseGraphInPowerSaver
    // Stops audio capture for the notch, dashboard and wallpaper visualisers
    readonly property bool pauseVisualisers: pm.enabled && powerSaver && pm.pauseVisualisersInPowerSaver

    // The visual effects the current power settings (Power & battery > plug state, profile, thresholds) have
    // switched off. BatteryMonitor sets these along with the matching Hyprland options, and the shell's own
    // animations, blur and shadows follow them, so a "no blur / no animations" battery setting also applies to the
    // shell and not just to windows. Rounding is deliberately not among them: it only ever affects windows. Everything
    // defaults to on.
    // How often decorative motion (spinning covers, drifting shapes, the visualiser ring) is redrawn. These are slow
    // movements, so nothing is lost at 30 a second, and each redraw of a layered shape is what it costs; on battery
    // it drops to 15.
    readonly property int fps: onBattery ? 15 : 30
    readonly property int frameMs: Math.round(1000 / fps)

    property bool animations: true
    property bool blur: true
    property bool shadows: true

    function applyEffects(settings: var): void {
        if (settings.disableAnimations === "disable")
            animations = false;
        else if (settings.disableAnimations === "enable")
            animations = true;

        if (settings.disableBlur === "disable")
            blur = false;
        else if (settings.disableBlur === "enable")
            blur = true;

        if (settings.disableShadows === "disable")
            shadows = false;
        else if (settings.disableShadows === "enable")
            shadows = true;
    }
}
