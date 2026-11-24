pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.components.misc
import qs.services

Scope {
    LazyLoader {
        id: root

        property bool freeze
        property bool closing

        // NOTE(fork): every capture mode behaves the same way now - the capture is
        // copied to the clipboard and handed to the preview, which offers the editor
        // and clears the temporary file when it is not used. The extra entry points
        // below are kept so that existing keybinds keep working.

        function capture(path: string, screen: ShellScreen): void {
            preview.capture(path, screen);
        }

        function openPicker(freeze: bool): void {
            // Clear any preview still up so it can't end up inside the next capture.
            preview.dismiss();

            root.freeze = freeze;
            root.closing = false;
            root.activeAsync = true;
        }

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "area-picker"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: root.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                Picker {
                    loader: root
                    screen: win.modelData
                }
            }
        }
    }

    // Opened by anything that is not the picker's own IPC or keybinds, such as a hot corner
    Connections {
        function onScreenshotRequested(freeze: bool): void {
            root.openPicker(freeze);
        }

        target: ShellState
    }

    IpcHandler {
        function open(): void {
            root.openPicker(false);
        }

        function openFreeze(): void {
            root.openPicker(true);
        }

        function openClip(): void {
            root.openPicker(false);
        }

        function openFreezeClip(): void {
            root.openPicker(true);
        }

        target: "picker"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshot"
        description: "Open screenshot tool"
        onPressed: root.openPicker(false)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotFreeze"
        description: "Open screenshot tool (freeze mode)"
        onPressed: root.openPicker(true)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotClip"
        description: "Open screenshot tool (clipboard)"
        onPressed: root.openPicker(false)
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotFreezeClip"
        description: "Open screenshot tool (freeze mode, clipboard)"
        onPressed: root.openPicker(true)
    }

    ScreenshotPreview {
        id: preview
    }
}
