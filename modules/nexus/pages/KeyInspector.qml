pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common
import qs.modules.launcher.services

// NOTE(fork): what the key hovered or clicked on the keyboard does, and - once one is clicked -
// the controls to put something else on it. See KeyboardMap.qml, which picks the key.
ConnectedRect {
    id: root

    // Hyprland's name for the key being shown, and the label the keyboard draws on it
    required property string keyName
    required property string keyLabel
    // Hovering only looks; a key has to be clicked before it can be changed
    required property bool editable

    // The shortcut being built for this key
    property var pendingMods: ["SUPER"]
    // "action" (give an existing keybind another shortcut), "command" or "app"
    property string mode: "action"
    property string actionQuery
    property string actionId
    property string command
    property string appQuery
    property var appEntry: null

    readonly property var binds: Keybinds.forKey(root.keyName)
    readonly property string combo: Keybinds.join(root.pendingMods, root.keyName)
    readonly property var clashing: Keybinds.bindsOn(root.pendingMods, root.keyName)
    readonly property bool ready: root.mode === "action" ? root.actionId !== "" : (root.mode === "command" ? root.command.trim() !== "" : root.appEntry !== null)

    // The keybinds that can be given another shortcut, narrowed by what was typed
    readonly property var actions: {
        const q = root.actionQuery.trim().toLowerCase();
        const all = Keybinds.entries.filter(e => !e.prefix);
        return (q === "" ? all : all.filter(e => e.label.toLowerCase().includes(q))).slice(0, 60);
    }
    readonly property var apps: root.appQuery.trim() === "" ? [] : Apps.search(root.appQuery.trim()).slice(0, 12)

    // A desktop entry as a command line Hyprland can exec, with anything awkward quoted. The
    // parsed command is used rather than the raw Exec line so the %U/%F field codes are gone.
    function appCommand(entry: DesktopEntry): string {
        const quote = a => /[^A-Za-z0-9_.:,=\/+@-]/.test(a) ? `'${a.replace(/'/g, "'\\''")}'` : a;
        const line = (entry.command ?? []).map(quote).join(" ");
        if (!entry.runInTerminal)
            return line;
        return `${GlobalConfig.general.apps.terminal.map(quote).join(" ")} -e ${line}`;
    }

    function bind(): void {
        if (!root.ready)
            return;

        if (root.mode === "action")
            Keybinds.addToEntry(root.actionId, root.combo);
        else if (root.mode === "command")
            Keybinds.addCustomBind(root.combo, root.command.trim());
        else
            Keybinds.addCustomBind(root.combo, root.appCommand(root.appEntry));

        root.actionId = "";
        root.appEntry = null;
        commandField.text = "";
        root.command = "";
    }

    // One of the shortcuts listed above, in the words the row shows for it
    function describe(b: var): string {
        return b.kind === "custom" ? b.detail : b.label;
    }

    function tagFor(b: var): string {
        if (b.kind === "custom")
            return Tr.tr("Custom");
        if (b.kind === "prefix")
            return Tr.tr("Number keys 1-0");
        return Keybinds.entries.find(e => e.id === b.id)?.overridden ? Tr.tr("Changed") : Tr.tr("Default");
    }

    first: true
    last: true
    implicitHeight: body.implicitHeight + Tokens.padding.largeIncreased * 2

    // A different key: nothing half-chosen for the last one should carry over
    onKeyNameChanged: {
        root.actionId = "";
        root.appEntry = null;
        commandField.text = "";
        root.command = "";
    }

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledText {
                text: root.keyLabel
                font: Tokens.font.title.small
            }

            StyledText {
                Layout.fillWidth: true
                text: root.editable ? Tr.tr("Click the key again to close it") : Tr.tr("Click the key to change it")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.binds.length === 0
            text: Tr.tr("Nothing is bound to this key.")
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.binds

            RowLayout {
                id: bindRow

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                StyledRect {
                    Layout.preferredWidth: Math.max(comboLabel.implicitWidth + Tokens.padding.medium * 2, 150)
                    implicitHeight: comboLabel.implicitHeight + Tokens.padding.extraSmall * 2
                    radius: Tokens.rounding.small
                    color: Colours.tPalette.m3surfaceContainerHighest

                    StyledText {
                        id: comboLabel

                        anchors.centerIn: parent
                        text: Keybinds.pretty(bindRow.modelData.combo) + (bindRow.modelData.kind === "prefix" ? " + 1-0" : "")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.medium
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.describe(bindRow.modelData)
                    elide: Text.ElideRight
                }

                StyledText {
                    text: root.tagFor(bindRow.modelData)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }

                IconButton {
                    visible: root.editable
                    type: IconButton.Text
                    isRound: true
                    icon: "close"
                    inactiveOnColour: Colours.palette.m3error
                    font: Tokens.font.icon.small
                    label.fill: 0
                    onClicked: Keybinds.removeBind(bindRow.modelData)
                }
            }
        }

        // Putting something new on this key
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.editable
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Add a shortcut")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: ["SUPER", "CTRL", "ALT", "SHIFT"]

                    StyledRect {
                        id: modChip

                        required property string modelData

                        readonly property bool on: root.pendingMods.includes(modChip.modelData)

                        implicitWidth: modLabel.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: modLabel.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: modChip.on ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHighest

                        StateLayer {
                            radius: parent.radius

                            onClicked: root.pendingMods = modChip.on ? root.pendingMods.filter(m => m !== modChip.modelData) : [...root.pendingMods, modChip.modelData]
                        }

                        StyledText {
                            id: modLabel

                            anchors.centerIn: parent
                            text: modChip.modelData.charAt(0) + modChip.modelData.slice(1).toLowerCase()
                            color: modChip.on ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.medium
                        }
                    }
                }

                StyledText {
                    text: `+ ${root.keyLabel}`
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.medium
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            SegmentedBar {
                Layout.fillWidth: true
                Layout.maximumWidth: 420
                Layout.topMargin: Tokens.spacing.extraSmall
                segmentHeight: 30
                currentIndex: ["action", "command", "app"].indexOf(root.mode)
                model: [
                    {
                        text: Tr.tr("Keybind")
                    },
                    {
                        text: Tr.tr("Command")
                    },
                    {
                        text: Tr.tr("App")
                    }
                ]

                onActivated: index => root.mode = ["action", "command", "app"][index]
            }

            StyledTextField {
                Layout.fillWidth: true
                visible: root.mode === "action"
                leadingIcon: "search"
                placeholderText: Tr.tr("Search keybinds")
                onTextEdited: root.actionQuery = text
            }

            Flow {
                Layout.fillWidth: true
                visible: root.mode === "action"
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.actions

                    StyledRect {
                        id: actionChip

                        required property var modelData

                        readonly property bool on: root.actionId === actionChip.modelData.id

                        implicitWidth: actionLabel.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: actionLabel.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: actionChip.on ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                        StateLayer {
                            radius: parent.radius

                            onClicked: root.actionId = actionChip.on ? "" : actionChip.modelData.id
                        }

                        StyledText {
                            id: actionLabel

                            anchors.centerIn: parent
                            text: actionChip.modelData.label
                            color: actionChip.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.small
                        }
                    }
                }
            }

            StyledTextField {
                id: commandField

                Layout.fillWidth: true
                visible: root.mode === "command"
                placeholderText: Tr.tr("Command to run")
                onTextEdited: root.command = text

                Keys.onReturnPressed: root.bind()
            }

            StyledTextField {
                Layout.fillWidth: true
                visible: root.mode === "app"
                leadingIcon: "search"
                placeholderText: Tr.tr("Search apps")
                onTextEdited: root.appQuery = text
            }

            Flow {
                Layout.fillWidth: true
                visible: root.mode === "app"
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: root.apps

                    StyledRect {
                        id: appChip

                        required property DesktopEntry modelData

                        readonly property bool on: root.appEntry === appChip.modelData

                        implicitWidth: appRow.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: appRow.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: appChip.on ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest

                        StateLayer {
                            radius: parent.radius

                            onClicked: root.appEntry = appChip.on ? null : appChip.modelData
                        }

                        Row {
                            id: appRow

                            anchors.centerIn: parent
                            spacing: Tokens.spacing.extraSmall

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                source: Quickshell.iconPath(appChip.modelData.icon, "application-x-executable")
                                sourceSize.width: 32
                                sourceSize.height: 32
                                width: 16
                                height: 16
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: appChip.modelData.name
                                color: appChip.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall
                spacing: Tokens.spacing.medium

                TextButton {
                    type: TextButton.Filled
                    isRound: true
                    text: Tr.tr("Bind %1").arg(Keybinds.pretty(root.combo))
                    disabled: !root.ready
                    onClicked: root.bind()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.clashing.length > 0
                    text: Tr.tr("Already used by %1").arg(root.clashing.map(b => root.describe(b)).join(", "))
                    color: Colours.palette.m3error
                    font: Tokens.font.label.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
