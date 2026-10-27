import QtQuick
import Quickshell
import Caelestia.Config
import qs.services

// NOTE(fork): switches to a random wallpaper when the shell starts and, while cycling is on, on a
// timer. Both are off by default and are set from Nexus -> Wallpaper & style -> Wallpapers. This is
// the same random pick the Random button uses, so the colour scheme follows it when the smart scheme
// is on.
Scope {
    id: root

    function rotate(): void {
        // The wallpaper is hidden, so a switch would recolour the shell with nothing to show for it
        if (!GlobalConfig.background.wallpaperEnabled)
            return;

        Wallpapers.setRandom();
    }

    Component.onCompleted: {
        if (GlobalConfig.background.randomWallpaperOnStart)
            root.rotate();
    }

    Timer {
        // A zero interval would switch wallpapers as fast as the CLI can run
        interval: Math.max(1000, GlobalConfig.background.wallpaperCycleInterval)
        running: GlobalConfig.background.wallpaperCycle && GlobalConfig.background.wallpaperEnabled
        repeat: true

        // A new interval counts from where it was set, instead of keeping the old deadline
        onIntervalChanged: if (running) restart()
        onTriggered: root.rotate()
    }
}
