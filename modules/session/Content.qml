pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Column {
    id: root

    required property ScreenState screenState

    // Everything an entry id can map to. "standby" isn't a command - it's the same ambient clock the
    // standby keybind shows, on this screen - so it carries an action instead
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
            standby: {
                icon: "schedule",
                action: () => {
                    root.screenState.session = false;
                    root.screenState.standby = true;
                }
            },
            reboot: {
                icon: Config.session.icons.reboot,
                command: Config.session.commands.reboot
            }
        })

    // The animation isn't an action, so it stays in a fixed slot while the actions around it are
    // reordered (and keeps its old spot in the default order)
    readonly property int gifIndex: 2

    // Enabled actions in their configured order, with the animation slotted back in
    readonly property var items: {
        const entries = Config.session.entries.values.filter(e => e.enabled && root.builtinActions[e.id]);
        return entries.slice(0, root.gifIndex).concat([{ id: "__gif" }], entries.slice(root.gifIndex));
    }

    readonly property int firstActionIndex: {
        for (let i = 0; i < root.items.length; i++) {
            if (root.items[i].id !== "__gif")
                return i;
        }
        return -1;
    }

    function buttonAt(index: int): var {
        const item = repeater.itemAt(index);
        return item && item.isAction ? item.buttonItem : null;
    }

    // Move focus to the next/previous action, skipping the animation and anything switched off
    function focusSibling(from: int, delta: int): void {
        for (let i = from + delta; i >= 0 && i < root.items.length; i += delta) {
            const button = root.buttonAt(i);
            if (button) {
                button.forceActiveFocus();
                return;
            }
        }
    }

    function focusFirst(): void {
        for (let i = 0; i < root.items.length; i++) {
            const button = root.buttonAt(i);
            if (button) {
                button.forceActiveFocus();
                return;
            }
        }
    }

    padding: Tokens.padding.large
    rightPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)
    spacing: Tokens.spacing.large

    Connections {
        function onLauncherChanged(): void {
            if (!root.screenState.launcher)
                root.focusFirst();
        }

        target: root.screenState
    }

    Repeater {
        id: repeater

        model: root.items

        delegate: Item {
            id: delegateItem

            required property var modelData
            required property int index

            readonly property bool isAction: delegateItem.modelData.id !== "__gif"
            readonly property var action: root.builtinActions[delegateItem.modelData.id] ?? null

            property alias buttonItem: sessionButton

            width: Tokens.sizes.session.button
            height: width
            implicitWidth: Tokens.sizes.session.button
            implicitHeight: Tokens.sizes.session.button

            Component.onCompleted: {
                if (delegateItem.index === root.firstActionIndex)
                    sessionButton.forceActiveFocus();
            }

            SessionButton {
                id: sessionButton

                anchors.fill: parent
                visible: delegateItem.isAction
                displayIndex: delegateItem.index
                icon: delegateItem.action?.icon ?? ""
                command: delegateItem.action?.command ?? []
                action: delegateItem.action?.action ?? null
            }

            AnimatedImage {
                anchors.fill: parent
                visible: !delegateItem.isAction

                playing: visible
                asynchronous: true
                speed: Config.general.sessionGifSpeed
                source: Paths.absolutePath(Config.paths.sessionGif)
                fillMode: AnimatedImage.PreserveAspectFit

                sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)
            }
        }
    }

    component SessionButton: IconButton {
        id: button

        property list<string> command: []
        // When set, called instead of running command - for actions that aren't an external process
        property var action: null
        // Where this button sits in root.items, so the keys below can find its neighbours
        property int displayIndex: -1

        function exec(): void {
            if (button.action) {
                button.action();
                return;
            }
            if (!SessionManager.exec(command))
                Quickshell.execDetached(command);
        }

        implicitWidth: Tokens.sizes.session.button
        implicitHeight: Tokens.sizes.session.button

        inactiveColour: activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        inactiveOnColour: activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
        font: Tokens.font.icon.builders.large.scale(1.3).build()
        onClicked: exec()

        Keys.onEnterPressed: exec()
        Keys.onReturnPressed: exec()
        Keys.onEscapePressed: root.screenState.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    root.focusSibling(button.displayIndex, 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    root.focusSibling(button.displayIndex, -1);
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                root.focusSibling(button.displayIndex, 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                root.focusSibling(button.displayIndex, -1);
                event.accepted = true;
            }
        }
    }
}
