pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

// The session actions as a standing pill, for the layouts without the resources card the classic
// layout hides them behind. Same switch (Nexus > Lock screen > Session controls) and the same
// list of actions in the same order; power off is tinted so it isn't hit by mistake
StyledRect {
    id: root

    property real uiScale: 1

    readonly property var builtinActions: ({
            logout: {
                icon: Config.session.icons.logout,
                command: Config.session.commands.logout
            },
            shutdown: {
                icon: Config.session.icons.shutdown,
                command: Config.session.commands.shutdown
            },
            sleep: {
                icon: Config.session.icons.sleep,
                command: Config.session.commands.sleep
            },
            reboot: {
                icon: Config.session.icons.reboot,
                command: Config.session.commands.reboot
            }
        })
    readonly property var actions: GlobalConfig.lock.entries.values.filter(e => e.enabled && root.builtinActions[e.id])

    visible: GlobalConfig.lock.enableSessionControls && root.actions.length > 0
    implicitWidth: row.implicitWidth + Tokens.padding.medium * 2 * root.uiScale
    implicitHeight: row.implicitHeight + Tokens.padding.medium * 2 * root.uiScale
    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surfaceContainer

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small * root.uiScale

        Repeater {
            model: root.actions

            SessionButton {}
        }
    }

    // NOTE(fork): a hover state that actually reads on a busy wallpaper. A tinted pill grows in
    // behind the icon (error-tinted for power off), the icon fills in and lifts slightly, and a
    // press squashes the whole thing and squares its corners off a little
    component SessionButton: Item {
        id: button

        required property var modelData
        readonly property bool danger: modelData.id === "shutdown"
        readonly property bool hovered: hover.hovered
        readonly property bool pressed: mouse.pressed
        readonly property real size: icon.implicitHeight + Tokens.padding.medium * 2 * root.uiScale

        implicitWidth: size
        implicitHeight: size

        StyledRect {
            id: bg

            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: button.pressed ? Tokens.rounding.medium : height / 2
            color: button.danger ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer
            opacity: button.hovered ? 1 : 0
            scale: button.pressed ? 0.88 : button.hovered ? 1 : 0.5

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }

            Behavior on radius {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        MaterialIcon {
            id: icon

            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            text: root.builtinActions[button.modelData.id].icon
            color: {
                if (button.hovered)
                    return button.danger ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer;
                return button.danger ? Colours.palette.m3error : Colours.palette.m3onSurface;
            }
            fontStyle: Tokens.font.icon.builders.medium.scale(root.uiScale * 1.1).build()
            fill: button.hovered ? 1 : 0
            scale: button.pressed ? 0.85 : button.hovered ? 1.12 : 1

            Behavior on color {
                CAnim {}
            }

            Behavior on fill {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on scale {
                Anim {
                    type: Anim.FastSpatial
                }
            }
        }

        // A HoverHandler rather than the MouseArea's own hover: the lock surface lays a full-screen
        // layer of HoverHandlers over everything to notice the pointer moving (LockSurface.qml's
        // activityLayer), and hover handlers share the pointer side by side where a MouseArea's
        // hover tracking can be shut out by them
        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            onClicked: {
                const command = root.builtinActions[button.modelData.id].command;
                if (!SessionManager.exec(command))
                    Quickshell.execDetached(command);
            }
        }
    }
}
