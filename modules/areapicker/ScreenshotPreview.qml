pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): the preview shown once a screenshot has been captured.
//
// The capture is already on the clipboard by the time this appears, so the preview
// only exists to offer a short window in which the capture can be edited or saved.
// If that window passes without either, the temporary file is cleared and the
// clipboard keeps the image.
StyledWindow {
    id: root

    // How long to wait for a click before discarding the capture.
    readonly property int timeout: 3000
    // The bar owns the left edge, so the preview sits to the right of it.
    readonly property int barWidth: ShellState.componentsFor(root.screen)?.bar?.implicitWidth ?? 0
    // Match the outline Hyprland draws around client windows, using the theme's
    // primary colour so the preview reads as another window rather than a panel.
    readonly property int borderWidth: Hypr.options["general:border_size"] ?? 2
    // Local path of the capture being previewed, empty while the preview is idle.
    property string capturePath
    // Where the save button writes its copy of the capture to.
    property string savePath

    function capture(path: string, target: ShellScreen): void {
        // Clear any capture still being previewed before taking over.
        root.dismiss();

        root.screen = target;
        root.capturePath = path;
        root.visible = true;
        timer.restart();
    }

    // Put the preview away and clear the capture's temporary file.
    function dismiss(): void {
        timer.stop();
        root.visible = false;

        if (root.capturePath)
            CUtils.deleteFile(Qt.resolvedUrl(root.capturePath));

        root.capturePath = "";
    }

    // Hand the capture to the editor, which keeps the file to save its edits into.
    function edit(): void {
        const path = root.capturePath;
        if (!path)
            return;

        timer.stop();
        root.visible = false;
        root.capturePath = "";
        Quickshell.execDetached(["swappy", "-f", path]);
    }

    // Write a copy of the capture to the desktop, leaving the original for the editor.
    function saveToDesktop(): void {
        if (!root.capturePath || saveProcess.running)
            return;

        // Hold off the timeout so the copy can't be cleared part way through.
        timer.stop();

        root.savePath = `${Paths.desktop}/Screenshot ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss")}.png`;
        saveProcess.command = ["sh", "-c", "mkdir -p \"$1\" && cp -- \"$2\" \"$3\"", "sh", Paths.desktop, root.capturePath, root.savePath];
        saveProcess.running = true;
    }

    name: "screenshot-preview"

    visible: false
    // While idle the window must not swallow clicks in the corner it sits in.
    mask: root.visible ? null : empty
    margins.bottom: card.edgeMargin
    margins.left: root.barWidth + card.edgeMargin
    anchors.bottom: true
    anchors.left: true
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Never take keyboard focus away from whatever the user was doing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Region {
        id: empty
    }

    Timer {
        id: timer

        interval: root.timeout
        onTriggered: root.dismiss()
    }

    Process {
        id: saveProcess

        // The desktop directory is not guaranteed to exist, and the copy is left
        // behind so the capture can still be sent to the editor afterwards.
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                Toaster.toast(Tr.tr("Failed to save screenshot"), Paths.shortenHome(root.savePath), "error", Toast.Error);
                timer.restart();
                return;
            }

            Toaster.toast(Tr.tr("Screenshot saved"), Paths.shortenHome(root.savePath), "save", Toast.Success);
            root.dismiss();
        }
    }

    StyledClippingRect {
        id: card

        // Gap kept from the bar and the screen edges.
        readonly property int edgeMargin: Tokens.padding.large
        // Padding between the frame and the capture, so the frame reads as a box.
        readonly property int framePadding: Tokens.padding.medium
        // Captures are usually screen sized, so keep the preview a thumbnail.
        readonly property real maxWidth: Math.round((root.screen?.width ?? 0) / 5)
        readonly property real maxHeight: Math.round((root.screen?.height ?? 0) / 5)

        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.extraLarge

        border.width: root.borderWidth
        border.color: Colours.palette.m3primary
        implicitWidth: Math.max(img.width, buttons.implicitWidth) + framePadding * 2
        implicitHeight: img.height + buttons.implicitHeight + framePadding * 3
        anchors.fill: parent

        Behavior on border.color {
            CAnim {}
        }

        Image {
            id: img

            // The image is sized to the capture's own aspect ratio and never blown up
            // past the bounds of the thumbnail, so a small capture previews small.
            readonly property real previewScale: implicitWidth > 0 && implicitHeight > 0 ? Math.min(1, card.maxWidth / implicitWidth, card.maxHeight / implicitHeight) : 1

            // Bound the decoded size so a full screen capture isn't decoded at full
            // resolution only to be shown as a thumbnail.
            sourceSize: Qt.size(card.maxWidth * 2, card.maxHeight * 2)
            width: Math.round(implicitWidth * previewScale)
            height: Math.round(implicitHeight * previewScale)
            anchors.top: parent.top
            anchors.topMargin: card.framePadding
            anchors.horizontalCenter: parent.horizontalCenter
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            source: root.capturePath ? Qt.resolvedUrl(root.capturePath) : ""

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.edit()
            }
        }

        Row {
            id: buttons

            spacing: Tokens.spacing.small
            anchors.right: parent.right
            anchors.rightMargin: card.framePadding
            anchors.bottom: parent.bottom
            anchors.bottomMargin: card.framePadding

            // Opens the capture in the editor, leaving the temporary file to it.
            IconButton {
                id: editButton

                icon: "edit"
                type: IconButton.Tonal
                radius: Tokens.rounding.full
                radiusMorph: false
                onClicked: root.edit()
            }

            IconButton {
                id: saveButton

                icon: "save"
                type: IconButton.Filled
                radius: Tokens.rounding.full
                radiusMorph: false
                onClicked: root.saveToDesktop()
            }
        }
    }
}
