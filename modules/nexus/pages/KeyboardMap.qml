pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// NOTE(fork): the keys, drawn as a keyboard. Every key sits where it does on a real board and is
// outlined by what is on it: the accent when something is bound, the error colour when two binds
// share one shortcut (Hyprland fires both, which is rarely meant), and faint when it is free. A
// dot marks a key bound under more than one set of modifiers. Hovering a key shows what it does,
// clicking one opens it to edit - both of those live in KeyInspector, which this feeds.
Item {
    id: root

    // "60%", "75%" or "100%": how much of a keyboard to draw
    property string boardSize: "100%"
    // Which modifiers the colours describe: -1 for every combination, or one mask on its own
    property int mask: -1
    // The key under the pointer, and the one clicked open, by Hyprland's name for it
    property string hovered
    property string selected

    readonly property real unitsWide: root.boardSize === "100%" ? 23 : (root.boardSize === "75%" ? 18.5 : 15)
    readonly property real unitsTall: (root.boardSize === "60%" ? 6.5 : 8) + 1.5
    // A key unit, capped so a wide window does not draw an enormous keyboard
    readonly property real unit: Math.min(46, root.width / root.unitsWide)
    readonly property real gap: Math.max(2, root.unit * 0.09)

    // Every key as { label, key, x, y, w, h }, in key units from the top left
    readonly property var layout: {
        const keys = [];
        const k = (label, key, x, y, w, h) => keys.push({
            label,
            key,
            x,
            y,
            w: w ?? 1,
            h: h ?? 1
        });
        const spread = (labels, names, x, y) => labels.forEach((l, i) => k(l, names[i], x + i, y));
        const letters = text => text.split("");

        const sixty = root.boardSize === "60%";
        const y = sixty ? 0 : 1.5;

        if (!sixty) {
            k("Esc", "Escape", 0, 0);
            ["F1", "F2", "F3", "F4"].forEach((n, i) => k(n, n, 2 + i, 0));
            ["F5", "F6", "F7", "F8"].forEach((n, i) => k(n, n, 6.5 + i, 0));
            ["F9", "F10", "F11", "F12"].forEach((n, i) => k(n, n, 11 + i, 0));
        }

        k(sixty ? "Esc" : "`", sixty ? "Escape" : "grave", 0, y);
        spread(letters("1234567890"), letters("1234567890"), 1, y);
        k("-", "Minus", 11, y);
        k("=", "Equal", 12, y);
        k("Back", "Backspace", 13, y, 2);

        k("Tab", "Tab", 0, y + 1, 1.5);
        spread(letters("QWERTYUIOP"), letters("QWERTYUIOP"), 1.5, y + 1);
        k("[", "Bracketleft", 11.5, y + 1);
        k("]", "Bracketright", 12.5, y + 1);
        k("\\", "Backslash", 13.5, y + 1, 1.5);

        k("Caps", "Caps_Lock", 0, y + 2, 1.75);
        spread(letters("ASDFGHJKL"), letters("ASDFGHJKL"), 1.75, y + 2);
        k(";", "Semicolon", 10.75, y + 2);
        k("'", "Apostrophe", 11.75, y + 2);
        k("Enter", "RETURN", 12.75, y + 2, 2.25);

        k("Shift", "Shift_L", 0, y + 3, 2.25);
        spread(letters("ZXCVBNM"), letters("ZXCVBNM"), 2.25, y + 3);
        k(",", "Comma", 9.25, y + 3);
        k(".", "Period", 10.25, y + 3);
        k("/", "Slash", 11.25, y + 3);
        k("Shift", "Shift_R", 12.25, y + 3, 2.75);

        k("Ctrl", "Control_L", 0, y + 4, 1.25);
        k("Super", "Super_L", 1.25, y + 4, 1.25);
        k("Alt", "Alt_L", 2.5, y + 4, 1.25);
        k("Space", "Space", 3.75, y + 4, 6.25);
        k("Alt", "Alt_R", 10, y + 4, 1.25);
        k("Super", "Super_R", 11.25, y + 4, 1.25);
        k("Menu", "Menu", 12.5, y + 4, 1.25);
        k("Ctrl", "Control_R", 13.75, y + 4, 1.25);

        if (!sixty) {
            k("Prt", "Print", 15.5, 0);
            k("Scr", "Scroll_Lock", 16.5, 0);
            k("Pau", "Pause", 17.5, 0);
            k("Ins", "Insert", 15.5, y);
            k("Home", "Home", 16.5, y);
            k("PgU", "Page_Up", 17.5, y);
            k("Del", "Delete", 15.5, y + 1);
            k("End", "End", 16.5, y + 1);
            k("PgD", "Page_Down", 17.5, y + 1);
            k("↑", "Up", 16.5, y + 3);
            k("←", "Left", 15.5, y + 4);
            k("↓", "Down", 16.5, y + 4);
            k("→", "Right", 17.5, y + 4);
        }

        if (root.boardSize === "100%") {
            k("Num", "Num_Lock", 19, y);
            k("/", "KP_Divide", 20, y);
            k("*", "KP_Multiply", 21, y);
            k("-", "KP_Subtract", 22, y);
            k("7", "KP_7", 19, y + 1);
            k("8", "KP_8", 20, y + 1);
            k("9", "KP_9", 21, y + 1);
            k("+", "KP_Add", 22, y + 1, 1, 2);
            k("4", "KP_4", 19, y + 2);
            k("5", "KP_5", 20, y + 2);
            k("6", "KP_6", 21, y + 2);
            k("1", "KP_1", 19, y + 3);
            k("2", "KP_2", 20, y + 3);
            k("3", "KP_3", 21, y + 3);
            k("Ent", "KP_Enter", 22, y + 3, 1, 2);
            k("0", "KP_0", 19, y + 4, 2);
            k(".", "KP_Decimal", 21, y + 4);
        }

        // The keys laptops and media keyboards add, in a row of their own
        [["prev", "XF86AudioPrev"], ["play", "XF86AudioPlay"], ["next", "XF86AudioNext"], ["mute", "XF86AudioMute"], ["vol -", "XF86AudioLowerVolume"], ["vol +", "XF86AudioRaiseVolume"], ["mic", "XF86AudioMicMute"], ["bri -", "XF86MonBrightnessDown"], ["bri +", "XF86MonBrightnessUp"]].forEach(([l, n], i) => k(l, n, i * 1.25, y + 5.5, 1.25));

        // Not keys at all, but Hyprland binds them the same way and this config leans on them,
        // so a shortcut on the scroll wheel is not invisible here
        [["scr ↑", "mouse_up"], ["scr ↓", "mouse_down"], ["click", "mouse:272"], ["right", "mouse:273"], ["mid", "mouse:274"]].forEach(([l, n], i) => k(l, n, i * 1.5, y + 6.75, 1.5));

        return keys;
    }

    implicitHeight: root.unitsTall * root.unit

    // The board is drawn into a child of its own so the keyboard's own width never feeds back
    // into the width the layout hands this item, and so a wide window centres it rather than
    // leaving it hanging off the left
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: root.unitsWide * root.unit
        implicitHeight: root.unitsTall * root.unit

        Repeater {
            model: root.layout

            StyledRect {
                id: key

                required property var modelData

                readonly property string look: Keybinds.keyState(key.modelData.key, root.mask)
                readonly property bool chosen: root.selected === key.modelData.key
                readonly property int combos: Keybinds.comboCount(key.modelData.key, root.mask)
                readonly property color outline: key.look === "conflict" ? Colours.palette.m3error : (key.look === "bound" ? Colours.palette.m3primary : Colours.tPalette.m3outlineVariant)

                x: key.modelData.x * root.unit
                y: key.modelData.y * root.unit
                implicitWidth: key.modelData.w * root.unit - root.gap
                implicitHeight: key.modelData.h * root.unit - root.gap
                radius: Tokens.rounding.small
                color: key.chosen ? Colours.palette.m3primary : (key.look === "conflict" ? Qt.alpha(Colours.palette.m3error, 0.12) : (hover.containsMouse ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainerHigh))
                border.width: key.look === "free" ? 1 : 2
                border.color: key.chosen ? Colours.palette.m3primary : key.outline

                // A plain MouseArea rather than a StateLayer: a StateLayer carries a Shape with
                // the curve renderer for its ripple, and a hundred-odd of those took seconds to
                // build every time the page opened. A key lights up by its own colour instead.
                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onEntered: root.hovered = key.modelData.key
                    onExited: {
                        if (root.hovered === key.modelData.key)
                            root.hovered = "";
                    }
                    onClicked: root.selected = key.chosen ? "" : key.modelData.key
                }

                // Shrunk to fit rather than elided, so "Super" and "PgDn" stay readable on a
                // narrow key instead of turning into "Su..."
                StyledText {
                    anchors.fill: parent
                    anchors.margins: 2
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: Text.HorizontalFit
                    minimumPointSize: 6
                    elide: Text.ElideRight
                    text: key.modelData.label
                    color: key.chosen ? Colours.palette.m3onPrimary : (key.look === "free" ? Colours.palette.m3outline : Colours.palette.m3onSurface)
                    font: Tokens.font.label.builders.small.size(Math.max(7, Math.min(12, Math.round(root.unit * 0.28)))).weight(Font.Medium).build()
                }

                // Bound under more than one set of modifiers
                StyledRect {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: root.gap
                    visible: key.combos > 1
                    implicitWidth: 4
                    implicitHeight: 4
                    radius: Tokens.rounding.full
                    color: key.chosen ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                }
            }
        }
    }
}
