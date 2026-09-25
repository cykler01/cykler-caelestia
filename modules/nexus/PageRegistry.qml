pragma Singleton

import QtQuick
import Caelestia.I18n

// The settings sidebar. The order here is the order shown, and it has to match PageCompRegistry.pageComps entry for
// entry. Pages are also given a `key`, so anything that needs to open a particular page asks for it by name with
// indexOfKey() instead of relying on where it happens to sit in the list.
QtObject {
    id: root

    function indexOfKey(key: string): int {
        return pages.findIndex(p => p.key === key);
    }

    readonly property list<var> pages: [
        // Look & feel
        {
            key: "wallpaper",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        {
            // NOTE(fork): shell assets page
            key: "assets",
            label: Tr.tr("Shell assets"),
            icon: "image",
            description: Tr.tr("Logo, gifs, placeholder images"),
            category: "appearance"
        },

        // The shell itself: what it shows and where
        {
            key: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Taskbar, dashboard, launcher, sidebar, notch, desktop"),
            category: "shell"
        },
        {
            key: "layout",
            label: Tr.tr("Layout"),
            icon: "dashboard_customize",
            description: Tr.tr("Move the bar, panels and widgets"),
            category: "shell"
        },
        {
            key: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            key: "services",
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, notifications, lyrics backend"),
            category: "shell"
        },

        // Connections
        {
            key: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            key: "bluetooth",
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },

        // Hardware
        {
            key: "display",
            label: Tr.tr("Display"),
            icon: "monitor",
            description: Tr.tr("Output configuration"),
            category: "devices"
        },
        {
            key: "audio",
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "devices"
        },
        {
            // NOTE(fork): mouse and touchpad input configuration
            key: "input",
            label: Tr.tr("Input"),
            icon: "mouse",
            description: Tr.tr("Mouse, touchpad, scrolling"),
            category: "devices"
        },
        {
            // NOTE(fork): change the Hyprland keybinds from settings
            key: "keybinds",
            label: Tr.tr("Keybinds"),
            icon: "keyboard",
            description: Tr.tr("Change keyboard shortcuts"),
            category: "devices"
        },
        {
            // NOTE(fork): battery power management page
            key: "power",
            label: Tr.tr("Power & battery"),
            icon: "battery_charging_full",
            description: Tr.tr("Power profiles, thresholds, power saving"),
            category: "devices"
        },

        // System
        {
            key: "language",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "system"
        },
        {
            key: "updates",
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            key: "plugins",
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system"
        },

        // About
        {
            key: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]
}
