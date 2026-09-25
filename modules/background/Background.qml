pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        ShellState.ComponentRef {
            screen: win.screen
            slot: "background"
            component: win
        }

        Item {
            id: insets

            // Space taken by the (left) bar; replaced by per-edge insets when the bar becomes movable
            readonly property real bar: Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness)

            // Whether tiled (non-floating) windows are covering this monitor's desktop; floating ones leave it visible
            readonly property var monitor: Hypr.monitorFor(win.screen)
            readonly property bool occupied: !(monitor?.activeWorkspace?.toplevels?.values.every(t => t.lastIpcObject?.floating) ?? true)

            // Smoothed 0..1 visibility, shared so icons and widgets animate in sync
            property real occupiedProg: occupied ? 1 : 0

            function revealFor(hideWithWindows: bool): real {
                return hideWithWindows ? 1 - occupiedProg : 1;
            }

            Behavior on occupiedProg {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled

                sourceComponent: Wallpaper {}
            }

            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
            }
        }

        Loader {
            id: clockLoader

            asynchronous: true
            active: Config.background.desktopClock.enabled

            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.small, Config.border.thickness)

            state: Config.background.desktopClock.position
            states: [
                State {
                    name: "top-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"

                    AnchorChanges {
                        target: clockLoader
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            transitions: Transition {
                AnchorAnim {}
            }

            sourceComponent: DesktopClock {
                wallpaper: behindClock
                absX: clockLoader.x
                absY: clockLoader.y
            }
        }

        // Desktop app shortcuts
        Loader {
            id: iconsLoader

            readonly property string pos: Config.background.desktopIcons.position
            readonly property real reveal: insets.revealFor(Config.background.desktopIcons.hideWithWindows)

            active: Config.background.desktopIcons.enabled
            visible: reveal > 0
            opacity: reveal
            scale: 0.94 + 0.06 * reveal
            transformOrigin: pos.endsWith("right") ? Item.Right : Item.Left
            transform: Translate {
                x: (iconsLoader.pos.endsWith("right") ? 1 : -1) * 32 * (1 - iconsLoader.reveal)
            }
            height: parent.height - anchors.topMargin - anchors.bottomMargin

            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + (pos.endsWith("left") ? insets.bar : 0)
            anchors.top: pos.startsWith("top") ? parent.top : undefined
            anchors.bottom: pos.startsWith("bottom") ? parent.bottom : undefined
            anchors.left: pos.endsWith("left") ? parent.left : undefined
            anchors.right: pos.endsWith("right") ? parent.right : undefined

            sourceComponent: DesktopIcons {
                height: iconsLoader.height
            }
        }

        // Desktop widget stack
        Loader {
            id: widgetsLoader

            readonly property string pos: Config.background.desktopWidgets.position
            readonly property real reveal: insets.revealFor(Config.background.desktopWidgets.hideWithWindows)

            active: Config.background.desktopWidgets.enabled
            visible: reveal > 0
            opacity: reveal
            scale: 0.94 + 0.06 * reveal
            transformOrigin: pos.endsWith("right") ? Item.Right : Item.Left
            transform: Translate {
                x: (widgetsLoader.pos.endsWith("right") ? 1 : -1) * 32 * (1 - widgetsLoader.reveal)
            }
            height: parent.height - anchors.topMargin - anchors.bottomMargin

            anchors.margins: Tokens.padding.extraLargeIncreased
            anchors.leftMargin: Tokens.padding.extraLargeIncreased + (pos.endsWith("left") ? insets.bar : 0)
            anchors.top: pos.startsWith("top") ? parent.top : undefined
            anchors.bottom: pos.startsWith("bottom") ? parent.bottom : undefined
            anchors.left: pos.endsWith("left") ? parent.left : undefined
            anchors.right: pos.endsWith("right") ? parent.right : undefined

            sourceComponent: DesktopWidgets {
                height: widgetsLoader.height
                layoutDirection: widgetsLoader.pos.endsWith("right") ? Qt.RightToLeft : Qt.LeftToRight
                wallpaper: behindClock
            }
        }
    }
}
