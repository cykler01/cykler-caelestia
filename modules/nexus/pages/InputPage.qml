pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    function signed(value: real): string {
        const rounded = Math.round(value * 100) / 100;
        return (rounded > 0 ? "+" : "") + rounded.toFixed(2);
    }

    function factor(value: real): string {
        return (Math.round(value * 100) / 100).toFixed(2);
    }

    title: Tr.tr("Input")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Mouse
        SectionHeader {
            first: true
            text: Tr.tr("Mouse")
        }

        SliderRow {
            first: true
            icon: "mouse"
            label: Tr.tr("Sensitivity")
            valueLabel: root.signed(InputSettings.sensitivity)
            value: InputSettings.sensitivity
            from: -1
            to: 1
            stepSize: 0.05
            onMoved: v => InputSettings.set(InputSettings.sensitivityKey, Math.round(v * 100) / 100)
        }

        ToggleRow {
            text: Tr.tr("Acceleration")
            subtext: Tr.tr("Flat pointer movement when off, adaptive when on")
            checked: InputSettings.accelProfile !== "flat"
            onToggled: InputSettings.set(InputSettings.accelProfileKey, checked ? "adaptive" : "flat")
        }

        SliderRow {
            last: true
            icon: "swap_vert"
            label: Tr.tr("Scroll sensitivity")
            valueLabel: root.factor(InputSettings.scrollFactor)
            value: InputSettings.scrollFactor
            from: 0.1
            to: 3
            stepSize: 0.05
            onMoved: v => InputSettings.set(InputSettings.scrollFactorKey, Math.round(v * 100) / 100)
        }

        // Touchpad
        SectionHeader {
            text: Tr.tr("Touchpad")
        }

        SliderRow {
            first: true
            last: true
            icon: "touch_app"
            label: Tr.tr("Scroll sensitivity")
            valueLabel: root.factor(InputSettings.touchpadScrollFactor)
            value: InputSettings.touchpadScrollFactor
            from: 0.1
            to: 3
            stepSize: 0.05
            onMoved: v => InputSettings.set(InputSettings.touchpadScrollFactorKey, Math.round(v * 100) / 100)
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            text: Tr.tr("Applied to Hyprland while the shell runs, and put back after a config reload. Settings left alone use your Hyprland config.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
