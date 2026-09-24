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
    readonly property bool powerSaver: PowerProfiles.profile === PowerProfile.PowerSaver

    // Stops the performance graph's background recording; the dashboard shows the original cards
    readonly property bool pauseGraph: pm.enabled && powerSaver && pm.pauseGraphInPowerSaver
    // Stops audio capture for the notch, dashboard and wallpaper visualisers
    readonly property bool pauseVisualisers: pm.enabled && powerSaver && pm.pauseVisualisersInPowerSaver
}
