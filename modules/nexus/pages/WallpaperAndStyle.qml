pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // TRANSLATORS: %1 = an opacity from 0 to 100
    function percent(value: real): string {
        return Tr.tr("%1%").arg(Math.round(value * 100));
    }

    title: Tr.tr("Wallpaper & style")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        ClipRect {
            id: wallWrapper

            Layout.alignment: Qt.AlignHCenter
            implicitWidth: {
                const screen = root.nState.screen;
                return implicitHeight / screen.height * screen.width;
            }
            implicitHeight: {
                const screen = root.nState.screen;
                const cWidth = root.cappedWidth;
                return Math.min(Math.round(cWidth * 0.4), cWidth / screen.width * screen.height);
            }

            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            Loader {
                anchors.centerIn: parent
                opacity: Config.background.wallpaperEnabled ? 0 : 1
                active: opacity > 0

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Tr.tr("Wallpaper disabled")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.large
                    }
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }

            WallpaperImpl {
                anchors.fill: parent
                opacity: Config.background.wallpaperEnabled ? 1 : 0

                Behavior on opacity {
                    Anim {
                        type: Anim.SlowEffects
                    }
                }
            }
        }

        ButtonRow {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            IconTextButton {
                icon: "wallpaper"
                text: Tr.tr("Wallpapers")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                disabled: !Config.background.wallpaperEnabled
                onClicked: root.nState.openSubPage(1) // Wallpaper page
            }

            IconTextButton {
                icon: "palette"
                text: Tr.tr("Colours")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                type: IconTextButton.Tonal
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: root.nState.openSubPage(3) // Colours page
            }
        }

        ToggleRow {
            first: true
            // SEARCH: background image desktop picture
            text: Tr.tr("Display wallpaper")
            checked: Config.background.wallpaperEnabled
            onToggled: GlobalConfig.background.wallpaperEnabled = checked
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing

            // SEARCH: opacity translucent see through
            text: Tr.tr("Transparency")
            // TRANSLATORS: %1/%2 = opacity values from 0 to 1 for the base surface and layered surfaces
            subtext: Tr.tr("Base %1, layers %2").arg(Colours.transparency.base).arg(Colours.transparency.layers)
            checked: Colours.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        // NOTE(fork): how long everything the shell animates takes, as a multiplier on the whole
        // set of durations at once. The defaults are Material 3's expressive ones, which are on the
        // slow side for a panel that opens and closes all day; below 1 the shell moves the same way,
        // just more briskly. 0 would stop the motion being animation at all, so it stops short of it.
        StepperRow {
            last: true
            label: Tr.tr("Animation speed")
            subtext: Tr.tr("How long the shell's own animations take, as a multiple of the usual; lower is quicker")
            value: Config.appearance.anim.durations.scale
            from: 0.1
            to: 2
            stepSize: 0.05
            onMoved: v => GlobalConfig.appearance.anim.durations.scale = v
        }

        // NOTE(fork): window transparency is Hyprland's, not the shell's - the Transparency
        // switch above only reaches the shell's own panels and popups, while this reaches every
        // window on screen. It is one value rather than a focused/unfocused pair because the
        // dots pin all non-fullscreen windows to a single opacity; see services/WindowSettings.
        SectionHeader {
            text: Tr.tr("Windows")
        }

        SliderRow {
            first: true
            last: true
            icon: "web_asset"
            label: Tr.tr("Window opacity")
            valueLabel: root.percent(WindowSettings.value)
            value: WindowSettings.value
            // A window you are working in has to stay readable, so it can go a little
            // see-through but not far
            from: 0.5
            to: 1
            stepSize: 0.01
            onMoved: v => WindowSettings.set(v)
        }
    }
}
