pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// NOTE(fork): change the Hyprland keybinds without editing Lua. See services/Keybinds.qml. The
// binds are shown two ways: drawn on a keyboard (KeyboardView), which is where a key is picked
// and what is on it changed, and as a list of every bind by name (KeybindList), which is also
// where the custom binds and the touchpad gestures live.
PageBase {
    id: root

    readonly property var views: ["keyboard", "list"]
    property string view: "keyboard"
    // The list builds a row per keybind, which is most of what opening this page used to cost.
    // It is only built once the List tab has been asked for, and kept after that.
    property bool listWanted: false

    title: Tr.tr("Keybinds")

    onViewChanged: {
        if (root.view === "list")
            root.listWanted = true;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SegmentedBar {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Tokens.spacing.large
            // The bar splits itself into equal segments and does not grow for its labels, so the
            // default 240 left "Keyboard" running over its own pill
            implicitWidth: 340
            visible: Keybinds.available
            currentIndex: root.views.indexOf(root.view)
            model: [
                {
                    icon: "keyboard",
                    text: Tr.tr("Keyboard")
                },
                {
                    icon: "format_list_bulleted",
                    text: Tr.tr("List")
                }
            ]

            onActivated: index => root.view = root.views[index]
        }

        StyledText {
            Layout.fillWidth: true
            visible: !Keybinds.available
            text: Tr.tr("No keybinds were found in your Hyprland config (hypr/variables.lua).")
            color: Colours.palette.m3outline
            wrapMode: Text.WordWrap
        }

        KeyboardView {
            Layout.fillWidth: true
            visible: Keybinds.available && root.view === "keyboard"
        }

        Loader {
            Layout.fillWidth: true
            active: Keybinds.available && root.listWanted
            visible: active && root.view === "list"
            asynchronous: true

            sourceComponent: KeybindList {}
        }
    }
}
