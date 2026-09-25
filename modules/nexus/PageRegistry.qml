pragma Singleton

import QtQuick
import Caelestia.I18n

QtObject {
    id: root

    readonly property list<var> pages: [
        // Appearance
        {
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        {
            // NOTE(fork): shell assets page
            label: Tr.tr("Shell assets"),
            icon: "image",
            description: Tr.tr("Logo, gifs, placeholder images"),
            category: "appearance"
        },

        // Connectivity
        {
            label: qsTr("Display"),
            icon: "monitor",
            description: qsTr("Output configuration"),
            category: "connectivity"
        },
        {
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity"
        },

        // System
        {
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system"
        },

        // Shell
        {
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            label: Tr.tr("Layout"),
            icon: "dashboard_customize",
            description: Tr.tr("Move the bar, panels and widgets"),
            category: "shell"
        },
        {
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            // NOTE(fork): battery power management page
            label: Tr.tr("Power & battery"),
            icon: "battery_charging_full",
            description: Tr.tr("Power profiles, thresholds, power saving"),
            category: "shell"
        },
        {
            // NOTE(fork): mouse and touchpad input configuration
            label: Tr.tr("Input"),
            icon: "mouse",
            description: Tr.tr("Mouse, touchpad, scrolling"),
            category: "shell"
        },
        {
            // NOTE(fork): change the Hyprland keybinds from settings
            label: Tr.tr("Keybinds"),
            icon: "keyboard",
            description: Tr.tr("Change keyboard shortcuts"),
            category: "shell"
        },
        {
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell"
        },

        // About
        {
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]
}
