pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// One shortcut of a keybind: toggles for its modifiers, the key (click it, then press the new
// one) and a button to remove it. The modifiers are chosen with the toggles rather than by
// holding them because Hyprland would act on most combinations before this window saw them.
FocusScope {
    id: root

    // "SUPER + SHIFT + F", or "" for a shortcut that has not been given a key yet
    property string combo
    // Bound under modifiers alone (the number keys go after them), so there is no key to pick
    property bool prefix
    property bool removable: true
    property bool startCapturing

    // Modifiers picked on a shortcut that has no combo yet
    property var pendingMods: ["SUPER"]

    readonly property var parts: Keybinds.split(root.combo)
    readonly property var mods: root.combo === "" ? root.pendingMods : root.parts.mods
    readonly property string key: root.parts.key
    property bool capturing: root.startCapturing

    signal changed(string combo)
    signal removed

    function toggleMod(name: string): void {
        const has = root.mods.includes(name);
        // A prefix has nothing else to bind it, so keeps at least one
        if (has && root.prefix && root.mods.length <= 1)
            return;

        const next = has ? root.mods.filter(m => m !== name) : [...root.mods, name];
        if (root.combo === "" && !root.prefix)
            root.pendingMods = next;
        else
            root.changed(Keybinds.join(next, root.key));
    }

    // Qt's name for a key, which Keybinds turns into Hyprland's
    function qtName(key: int): string {
        switch (key) {
        case Qt.Key_Return:
            return "Return";
        case Qt.Key_Enter:
            return "Enter";
        case Qt.Key_Space:
            return "Space";
        case Qt.Key_Tab:
            return "Tab";
        case Qt.Key_Backtab:
            return "Backtab";
        case Qt.Key_Backspace:
            return "Backspace";
        case Qt.Key_Delete:
            return "Delete";
        case Qt.Key_Insert:
            return "Insert";
        case Qt.Key_Home:
            return "Home";
        case Qt.Key_End:
            return "End";
        case Qt.Key_PageUp:
            return "PageUp";
        case Qt.Key_PageDown:
            return "PageDown";
        case Qt.Key_Up:
            return "Up";
        case Qt.Key_Down:
            return "Down";
        case Qt.Key_Left:
            return "Left";
        case Qt.Key_Right:
            return "Right";
        case Qt.Key_Minus:
            return "Minus";
        case Qt.Key_Equal:
            return "Equal";
        case Qt.Key_Plus:
            return "Plus";
        case Qt.Key_Comma:
            return "Comma";
        case Qt.Key_Period:
            return "Period";
        case Qt.Key_Slash:
            return "Slash";
        case Qt.Key_Backslash:
            return "Backslash";
        case Qt.Key_Semicolon:
            return "Semicolon";
        case Qt.Key_Apostrophe:
            return "Apostrophe";
        case Qt.Key_BracketLeft:
            return "BracketLeft";
        case Qt.Key_BracketRight:
            return "BracketRight";
        case Qt.Key_QuoteLeft:
            return "QuoteLeft";
        case Qt.Key_Print:
            return "Print";
        case Qt.Key_Pause:
            return "Pause";
        case Qt.Key_VolumeUp:
            return "VolumeUp";
        case Qt.Key_VolumeDown:
            return "VolumeDown";
        case Qt.Key_VolumeMute:
            return "VolumeMute";
        case Qt.Key_MediaPlay:
            return "MediaPlay";
        case Qt.Key_MediaTogglePlayPause:
            return "MediaTogglePlayPause";
        case Qt.Key_MediaStop:
            return "MediaStop";
        case Qt.Key_MediaNext:
            return "MediaNext";
        case Qt.Key_MediaPrevious:
            return "MediaPrevious";
        case Qt.Key_MonBrightnessUp:
            return "MonBrightnessUp";
        case Qt.Key_MonBrightnessDown:
            return "MonBrightnessDown";
        }

        if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
            return `F${key - Qt.Key_F1 + 1}`;
        if (key >= Qt.Key_A && key <= Qt.Key_Z || key >= Qt.Key_0 && key <= Qt.Key_9)
            return String.fromCharCode(key);
        return "";
    }

    function capture(event: var): void {
        // Holding a modifier on its own is not the key
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr, Qt.Key_CapsLock].includes(event.key)) {
            event.accepted = true;
            return;
        }

        event.accepted = true;
        if (event.key === Qt.Key_Escape) {
            root.capturing = false;
            if (root.combo === "")
                root.removed();
            return;
        }

        const name = Keybinds.keyName(root.qtName(event.key), event.text);
        if (name === "")
            return;

        // Any modifiers held down join the ones already toggled on
        const held = [];
        if (event.modifiers & Qt.MetaModifier)
            held.push("SUPER");
        if (event.modifiers & Qt.ControlModifier)
            held.push("CTRL");
        if (event.modifiers & Qt.AltModifier)
            held.push("ALT");
        if (event.modifiers & Qt.ShiftModifier)
            held.push("SHIFT");

        const mods = [...new Set([...root.mods, ...held])];
        root.capturing = false;
        root.changed(Keybinds.join(mods, name));
    }

    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth

    Component.onCompleted: {
        if (root.capturing)
            root.forceActiveFocus();
    }

    onCapturingChanged: {
        if (root.capturing)
            root.forceActiveFocus();
    }

    // Clicking away abandons the capture
    onActiveFocusChanged: {
        if (!root.activeFocus && root.capturing) {
            root.capturing = false;
            if (root.combo === "")
                root.removed();
        }
    }

    Keys.onPressed: event => {
        if (root.capturing)
            root.capture(event);
    }

    RowLayout {
        id: row

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.small

        Repeater {
            model: ["SUPER", "CTRL", "ALT", "SHIFT"]

            StyledRect {
                id: chip

                required property string modelData
                readonly property bool on: root.mods.includes(modelData)

                implicitWidth: chipLabel.implicitWidth + Tokens.padding.large * 2
                implicitHeight: chipLabel.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.small
                color: chip.on ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHighest

                StateLayer {
                    onClicked: root.toggleMod(chip.modelData)
                }

                StyledText {
                    id: chipLabel

                    anchors.centerIn: parent
                    text: chip.modelData.charAt(0) + chip.modelData.slice(1).toLowerCase()
                    color: chip.on ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }
        }

        StyledText {
            visible: !root.prefix
            text: "+"
            color: Colours.palette.m3outline
        }

        StyledRect {
            visible: !root.prefix
            Layout.preferredWidth: Math.max(keyLabel.implicitWidth + Tokens.padding.large * 2, 96)
            implicitHeight: keyLabel.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.small
            color: root.capturing ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHighest
            border.width: 1
            border.color: root.capturing ? Colours.palette.m3primary : Colours.tPalette.m3outlineVariant

            StateLayer {
                onClicked: {
                    root.capturing = true;
                    root.forceActiveFocus();
                }
            }

            StyledText {
                id: keyLabel

                anchors.centerIn: parent
                text: root.capturing ? Tr.tr("Press a key…") : root.key === "" ? Tr.tr("Choose key") : Keybinds.pretty(root.key)
                color: root.capturing ? Colours.palette.m3onPrimary : root.key === "" ? Colours.palette.m3outline : Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }
        }

        Item {
            Layout.fillWidth: true
        }

        IconButton {
            visible: root.removable && !root.prefix
            type: IconButton.Text
            isRound: true
            icon: "close"
            inactiveOnColour: Colours.palette.m3error
            font: Tokens.font.icon.medium
            label.fill: 0
            onClicked: root.removed()
        }
    }
}
