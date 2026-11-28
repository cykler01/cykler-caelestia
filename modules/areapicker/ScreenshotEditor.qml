pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils

// NOTE(fork): the shell's own screenshot editor, opened from the screenshot preview.
//
// Everything is laid out in the capture's own pixels: the scene is the full capture
// with any pasted images on top of it, and the crop picks the part of the scene that
// is shown and exported. Nothing is flattened until the result is saved or copied, so
// pasted images can be moved, resized or removed and the crop changed at any time.
//
// The window owns the capture's temporary file, and any pasted from the clipboard,
// and clears them all when it closes.
FloatingWindow {
    id: root

    // Local path of the capture being edited.
    property string capturePath
    // Temporary files the clipboard was pasted into, cleared when the window closes.
    property list<string> tempFiles

    // Size of the capture, which is the size of the scene.
    readonly property real imageWidth: baseImage.implicitWidth
    readonly property real imageHeight: baseImage.implicitHeight

    // The part of the scene that is kept, in capture pixels.
    property rect crop: Qt.rect(0, 0, imageWidth, imageHeight)
    // While cropping, the whole scene is shown and the crop being drawn is held here.
    property bool cropping
    property rect pendingCrop

    // The part of the scene currently on show.
    readonly property rect shown: cropping ? Qt.rect(0, 0, imageWidth, imageHeight) : crop
    // How many window pixels a capture pixel takes up; never blown up past 1:1.
    readonly property real fit: {
        if (shown.width <= 0 || shown.height <= 0)
            return 1;
        const pad = contentItem.Tokens.padding.large * 2;
        return Math.min(1, (view.width - pad) / shown.width, (view.height - pad) / shown.height);
    }

    // Index of the selected pasted image in the overlay model, or -1.
    property int selected: -1
    // Hides the selection and crop handles while the scene is being grabbed.
    property bool exporting

    // Snapshots of the crop and the pasted images, for undo and redo.
    property var undoStack: []
    property var redoStack: []

    // Count used to give each pasted temporary file its own name.
    property int pasteCount

    function snapshot(): var {
        const overlays = [];
        for (let i = 0; i < overlayModel.count; i++) {
            const o = overlayModel.get(i);
            overlays.push({
                src: o.src,
                ox: o.ox,
                oy: o.oy,
                ow: o.ow,
                oh: o.oh
            });
        }
        return {
            crop: Qt.rect(root.crop.x, root.crop.y, root.crop.width, root.crop.height),
            overlays: overlays
        };
    }

    function restore(state: var): void {
        root.selected = -1;
        root.crop = state.crop;
        overlayModel.clear();
        for (const o of state.overlays)
            overlayModel.append(o);
    }

    // Record the current state before a change, so the change can be undone.
    function pushUndo(state: var): void {
        root.undoStack = root.undoStack.concat([state ?? root.snapshot()]);
        root.redoStack = [];
    }

    function undo(): void {
        if (root.cropping || root.undoStack.length === 0)
            return;
        const stack = root.undoStack.slice();
        const state = stack.pop();
        root.redoStack = root.redoStack.concat([root.snapshot()]);
        root.undoStack = stack;
        root.restore(state);
    }

    function redo(): void {
        if (root.cropping || root.redoStack.length === 0)
            return;
        const stack = root.redoStack.slice();
        const state = stack.pop();
        root.undoStack = root.undoStack.concat([root.snapshot()]);
        root.redoStack = stack;
        root.restore(state);
    }

    // Puts an image on top of the scene; its size is settled once it has loaded.
    function addImage(path: string): void {
        if (!path)
            return;
        if (root.cropping)
            root.applyCrop();
        root.pushUndo();
        overlayModel.append({
            src: Qt.resolvedUrl(path).toString(),
            ox: 0,
            oy: 0,
            ow: 0,
            oh: 0
        });
        root.selected = overlayModel.count - 1;
    }

    // Sizes a freshly added image to fit comfortably inside the visible part of the
    // scene, centred on it, without blowing small images up.
    function place(index: int, naturalWidth: real, naturalHeight: real): void {
        const s = Math.min(1, root.crop.width * 0.6 / naturalWidth, root.crop.height * 0.6 / naturalHeight);
        const w = Math.max(1, naturalWidth * s);
        const h = Math.max(1, naturalHeight * s);
        overlayModel.set(index, {
            ox: root.crop.x + (root.crop.width - w) / 2,
            oy: root.crop.y + (root.crop.height - h) / 2,
            ow: w,
            oh: h
        });
    }

    function removeSelected(): void {
        if (root.selected < 0 || root.selected >= overlayModel.count)
            return;
        root.pushUndo();
        overlayModel.remove(root.selected);
        root.selected = -1;
    }

    // Raises an image above the rest and selects it.
    function select(index: int): void {
        const last = overlayModel.count - 1;
        if (index !== last)
            overlayModel.move(index, last, 1);
        root.selected = last;
    }

    function paste(): void {
        if (pasteProcess.running)
            return;
        root.pasteCount++;
        pasteProcess.target = `/tmp/caelestia-editor-${Quickshell.processId}-${Date.now()}-${root.pasteCount}`;
        pasteProcess.running = true;
    }

    function startCrop(): void {
        if (root.cropping)
            return;
        root.selected = -1;
        root.pendingCrop = root.crop;
        root.cropping = true;
    }

    function applyCrop(): void {
        if (!root.cropping)
            return;
        const p = root.pendingCrop;
        const c = Qt.rect(Math.round(p.x), Math.round(p.y), Math.round(p.width), Math.round(p.height));
        root.cropping = false;
        if (c.width < 1 || c.height < 1)
            return;
        if (c.x !== root.crop.x || c.y !== root.crop.y || c.width !== root.crop.width || c.height !== root.crop.height) {
            root.pushUndo();
            root.crop = c;
        }
    }

    function cancelCrop(): void {
        root.cropping = false;
    }

    // Flattens the kept part of the scene into a png at the capture's own resolution
    // and hands its path to the callback.
    function exportTo(path: string, done: var): void {
        if (root.cropping)
            root.applyCrop();
        root.selected = -1;
        root.exporting = true;
        canvas.grabToImage(result => {
            root.exporting = false;
            done(result.saveToFile(path) ? path : "");
        }, Qt.size(Math.round(root.crop.width), Math.round(root.crop.height)));
    }

    function exportPath(): string {
        return `/tmp/caelestia-editor-${Quickshell.processId}-${Date.now()}-out.png`;
    }

    function copy(): void {
        root.exportTo(root.exportPath(), path => {
            if (!path) {
                Toaster.toast(Tr.tr("Failed to copy screenshot"), "", "error", Toast.Error);
                return;
            }
            // wl-copy reads the whole image before it forks, so the file can go straight away.
            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"; rm -f -- \"$1\"", "sh", path]);
            Toaster.toast(Tr.tr("Screenshot copied"), Tr.tr("The edited screenshot is on the clipboard"), "content_copy", Toast.Success);
        });
    }

    function save(): void {
        if (saveProcess.running)
            return;
        root.exportTo(root.exportPath(), path => {
            if (!path) {
                Toaster.toast(Tr.tr("Failed to save screenshot"), "", "error", Toast.Error);
                return;
            }
            saveProcess.savePath = `${Paths.desktop}/Screenshot ${Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm.ss")}.png`;
            saveProcess.command = ["sh", "-c", "mkdir -p \"$1\" && mv -- \"$2\" \"$3\"", "sh", Paths.desktop, path, saveProcess.savePath];
            saveProcess.running = true;
        });
    }

    // Hands the flattened result to satty for drawing tools this editor doesn't have.
    function openInSatty(): void {
        root.exportTo(root.exportPath(), path => {
            if (!path) {
                Toaster.toast(Tr.tr("Failed to open screenshot"), "", "error", Toast.Error);
                return;
            }
            Quickshell.execDetached(["satty", "--filename", path, "--output-filename", `${Paths.desktop}/Screenshot %Y-%m-%d %H.%M.%S.png`, "--copy-command", "wl-copy", "--early-exit"]);
            root.visible = false;
        });
    }

    function cleanUp(): void {
        if (root.capturePath)
            CUtils.deleteFile(Qt.resolvedUrl(root.capturePath));
        for (const f of root.tempFiles)
            CUtils.deleteFile(Qt.resolvedUrl(f));
        root.capturePath = "";
        root.tempFiles = [];
    }

    title: Tr.tr("Screenshot editor")
    color: Colours.tPalette.m3surface
    surfaceFormat.opaque: false

    // Open at a size that shows the whole capture without filling the screen.
    implicitWidth: {
        const maxW = (screen?.width ?? 1920) * 0.75;
        const maxH = (screen?.height ?? 1080) * 0.75 - toolbar.implicitHeight;
        const s = imageWidth > 0 && imageHeight > 0 ? Math.min(1, maxW / imageWidth, maxH / imageHeight) : 1;
        return Math.max(toolbar.implicitWidth, Math.round(imageWidth * s)) + contentItem.Tokens.padding.large * 2;
    }
    implicitHeight: {
        const maxW = (screen?.width ?? 1920) * 0.75;
        const maxH = (screen?.height ?? 1080) * 0.75 - toolbar.implicitHeight;
        const s = imageWidth > 0 && imageHeight > 0 ? Math.min(1, maxW / imageWidth, maxH / imageHeight) : 1;
        return Math.max(320, Math.round(imageHeight * s) + toolbar.implicitHeight + contentItem.Tokens.padding.large * 3);
    }
    minimumSize.width: toolbar.implicitWidth + contentItem.Tokens.padding.large * 2
    minimumSize.height: 320

    contentItem.Config.screen: screen?.name ?? ""
    contentItem.Tokens.screen: screen?.name ?? ""

    onVisibleChanged: {
        if (!visible) {
            cleanUp();
            destroy();
        }
    }

    ListModel {
        id: overlayModel
    }

    // Writes the first image on the clipboard to a temporary file, or lists the files
    // when files were copied from a file manager. Prints "none" when there is neither.
    Process {
        id: pasteProcess

        property string target

        command: ["sh", "-c", `
            types=$(wl-paste --list-types 2>/dev/null) || { echo none; exit; }
            t=$(printf '%s\\n' "$types" | grep -m1 '^image/')
            if [ -n "$t" ]; then
                ext=\${t#image/}; ext=\${ext%%+*}
                wl-paste --no-newline --type "$t" > "$1.$ext" && echo "file://$1.$ext" || echo none
            elif printf '%s\\n' "$types" | grep -qx 'text/uri-list'; then
                wl-paste --type text/uri-list | tr -d '\\r'
            else
                echo none
            fi`, "sh", target]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l && !l.startsWith("#"));
                const paths = lines.filter(l => l.startsWith("file://")).map(l => decodeURIComponent(l.slice(7)));
                const temp = paths.filter(p => p.startsWith(pasteProcess.target));
                const images = paths.filter(p => temp.includes(p) || Images.isValidImageByName(p.toLowerCase()));

                if (images.length === 0) {
                    Toaster.toast(Tr.tr("Nothing to paste"), Tr.tr("There is no image on the clipboard"), "content_paste_off", Toast.Warning);
                    return;
                }

                root.tempFiles = root.tempFiles.concat(temp);
                for (const p of images)
                    root.addImage(p);
            }
        }
    }

    Process {
        id: saveProcess

        property string savePath

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                Toaster.toast(Tr.tr("Failed to save screenshot"), Paths.shortenHome(savePath), "error", Toast.Error);
            else
                Toaster.toast(Tr.tr("Screenshot saved"), Paths.shortenHome(savePath), "save", Toast.Success);
        }
    }

    FileDialog {
        id: fileDialog

        title: Tr.tr("Select an image to add")
        filterLabel: Tr.tr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => root.addImage(path)
    }

    Shortcut {
        sequences: [StandardKey.Paste]
        onActivated: root.paste()
    }
    Shortcut {
        sequences: [StandardKey.Copy]
        onActivated: root.copy()
    }
    Shortcut {
        sequences: [StandardKey.Save]
        onActivated: root.save()
    }
    Shortcut {
        sequences: [StandardKey.Undo]
        onActivated: root.undo()
    }
    Shortcut {
        sequences: [StandardKey.Redo, "Ctrl+Y"]
        onActivated: root.redo()
    }
    Shortcut {
        sequences: [StandardKey.Delete, "Backspace"]
        onActivated: root.removeSelected()
    }
    Shortcut {
        sequence: "C"
        onActivated: root.cropping ? root.applyCrop() : root.startCrop()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: root.cropping
        onActivated: root.applyCrop()
    }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (root.cropping)
                root.cancelCrop();
            else if (root.selected >= 0)
                root.selected = -1;
            else
                root.visible = false;
        }
    }
    Shortcut {
        sequences: [StandardKey.Close]
        onActivated: root.visible = false
    }

    RowLayout {
        id: toolbar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        IconButton {
            icon: "crop"
            type: IconButton.Tonal
            isToggle: true
            optimistic: false
            checked: root.cropping
            onClicked: root.cropping ? root.applyCrop() : root.startCrop()
        }

        IconButton {
            visible: root.cropping
            icon: "crop_free"
            type: IconButton.Text
            onClicked: root.pendingCrop = Qt.rect(0, 0, root.imageWidth, root.imageHeight)
        }

        IconButton {
            visible: root.cropping
            icon: "close"
            type: IconButton.Text
            onClicked: root.cancelCrop()
        }

        IconButton {
            visible: root.cropping
            icon: "check"
            type: IconButton.Filled
            onClicked: root.applyCrop()
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        IconButton {
            icon: "content_paste"
            type: IconButton.Text
            onClicked: root.paste()
        }

        IconButton {
            icon: "add_photo_alternate"
            type: IconButton.Text
            onClicked: fileDialog.open()
        }

        IconButton {
            icon: "delete"
            type: IconButton.Text
            disabled: root.selected < 0
            onClicked: root.removeSelected()
        }

        Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Tokens.padding.small
            Layout.bottomMargin: Tokens.padding.small
            implicitWidth: 1
            color: Colours.palette.m3outlineVariant
        }

        IconButton {
            icon: "undo"
            type: IconButton.Text
            disabled: root.cropping || root.undoStack.length === 0
            onClicked: root.undo()
        }

        IconButton {
            icon: "redo"
            type: IconButton.Text
            disabled: root.cropping || root.redoStack.length === 0
            onClicked: root.redo()
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            text: root.cropping ? Tr.tr("Drag to choose the area to keep, Enter to apply") : Tr.tr("Paste or drop images to add them")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
            elide: Text.ElideRight
        }

        // Satty has the drawing tools: arrows, shapes, text, blur and so on.
        IconTextButton {
            icon: "draw"
            text: Tr.tr("Annotate")
            type: TextButton.Tonal
            onClicked: root.openInSatty()
        }

        IconButton {
            icon: "content_copy"
            type: IconButton.Tonal
            onClicked: root.copy()
        }

        IconButton {
            icon: "save"
            type: IconButton.Filled
            onClicked: root.save()
        }
    }

    Item {
        id: view

        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: Tokens.padding.small

        // Clicking the empty space around the capture clears the selection.
        MouseArea {
            anchors.fill: parent
            onPressed: root.selected = -1
        }

        // Images dropped from a file manager are added on top of the capture.
        DropArea {
            anchors.fill: parent
            onEntered: drag => drag.accepted = drag.hasUrls // qmllint disable signal-handler-parameters
            onDropped: drop => { // qmllint disable signal-handler-parameters
                const paths = Array.from(drop.urls).map(u => Paths.toLocalFile(u)).filter(p => p && Images.isValidImageByName(p.toLowerCase()));
                for (const p of paths)
                    root.addImage(p);
                if (paths.length > 0)
                    drop.acceptProposedAction();
            }
        }

        // The scaled stand-in for the canvas; the canvas itself stays in capture
        // pixels so it can be grabbed at full resolution.
        Item {
            id: viewport

            x: Math.round((view.width - root.shown.width * root.fit) / 2)
            y: Math.round((view.height - root.shown.height * root.fit) / 2)
            width: root.shown.width
            height: root.shown.height
            transform: Scale {
                xScale: root.fit
                yScale: root.fit
            }

            Item {
                id: canvas

                anchors.fill: parent
                clip: true

                Item {
                    id: scene

                    // A handle's size in capture pixels, so it stays the same size on screen.
                    readonly property real handleSize: 14 / root.fit
                    readonly property real lineWidth: 2 / root.fit

                    x: -root.shown.x
                    y: -root.shown.y
                    width: root.imageWidth
                    height: root.imageHeight

                    Image {
                        id: baseImage

                        anchors.fill: parent
                        source: root.capturePath ? Qt.resolvedUrl(root.capturePath) : ""
                        // Loaded up front so the window can open at the capture's size.
                        asynchronous: false
                        cache: false
                        smooth: true
                        mipmap: true
                    }

                    Repeater {
                        model: overlayModel

                        delegate: Item {
                            id: overlay

                            required property int index
                            required property string src
                            required property real ox
                            required property real oy
                            required property real ow
                            required property real oh

                            readonly property bool isSelected: root.selected === index && !root.exporting

                            x: ox
                            y: oy
                            width: ow
                            height: oh

                            Image {
                                anchors.fill: parent
                                source: overlay.src
                                asynchronous: true
                                smooth: true
                                mipmap: true
                                onStatusChanged: {
                                    if (status === Image.Ready && overlay.ow <= 0)
                                        root.place(overlay.index, implicitWidth, implicitHeight);
                                    else if (status === Image.Error) {
                                        Toaster.toast(Tr.tr("Failed to add image"), Tr.tr("The image could not be loaded"), "broken_image", Toast.Error);
                                        const i = overlay.index;
                                        Qt.callLater(() => {
                                            overlayModel.remove(i);
                                            root.selected = -1;
                                        });
                                    }
                                }
                            }

                            // Dragging the image moves it.
                            MouseArea {
                                property point start
                                property rect startRect
                                property var before
                                property bool moved

                                anchors.fill: parent
                                enabled: !root.cropping
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                onPressed: mouse => { // qmllint disable signal-handler-parameters
                                    before = root.snapshot();
                                    moved = false;
                                    start = mapToItem(scene, mouse.x, mouse.y);
                                    startRect = Qt.rect(overlay.ox, overlay.oy, overlay.ow, overlay.oh);
                                    root.select(overlay.index);
                                }
                                onPositionChanged: mouse => { // qmllint disable signal-handler-parameters
                                    const p = mapToItem(scene, mouse.x, mouse.y);
                                    moved = true;
                                    overlayModel.set(root.selected, {
                                        ox: startRect.x + p.x - start.x,
                                        oy: startRect.y + p.y - start.y
                                    });
                                }
                                onReleased: {
                                    if (moved)
                                        root.pushUndo(before);
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                visible: overlay.isSelected
                                color: "transparent"
                                border.width: scene.lineWidth
                                border.color: Colours.palette.m3primary
                            }

                            // Corner handles resize the image, keeping its shape unless
                            // shift is held.
                            Repeater {
                                model: [[-1, -1], [1, -1], [-1, 1], [1, 1]]

                                delegate: Rectangle {
                                    id: handle

                                    required property var modelData

                                    visible: overlay.isSelected
                                    x: (modelData[0] < 0 ? 0 : overlay.width) - width / 2
                                    y: (modelData[1] < 0 ? 0 : overlay.height) - height / 2
                                    width: scene.handleSize
                                    height: scene.handleSize
                                    radius: width / 2
                                    color: Colours.palette.m3primary
                                    border.width: scene.lineWidth
                                    border.color: Colours.palette.m3onPrimary

                                    MouseArea {
                                        property point start
                                        property rect startRect
                                        property var before
                                        property bool moved

                                        anchors.fill: parent
                                        anchors.margins: -scene.handleSize / 2
                                        cursorShape: handle.modelData[0] === handle.modelData[1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                                        onPressed: mouse => { // qmllint disable signal-handler-parameters
                                            before = root.snapshot();
                                            moved = false;
                                            start = mapToItem(scene, mouse.x, mouse.y);
                                            startRect = Qt.rect(overlay.ox, overlay.oy, overlay.ow, overlay.oh);
                                        }
                                        onPositionChanged: mouse => { // qmllint disable signal-handler-parameters
                                            const p = mapToItem(scene, mouse.x, mouse.y);
                                            const sx = handle.modelData[0];
                                            const sy = handle.modelData[1];
                                            const minSize = scene.handleSize;
                                            let w = Math.max(minSize, startRect.width + sx * (p.x - start.x));
                                            let h = Math.max(minSize, startRect.height + sy * (p.y - start.y));
                                            if (!(mouse.modifiers & Qt.ShiftModifier)) {
                                                const s = Math.max(w / startRect.width, h / startRect.height);
                                                w = startRect.width * s;
                                                h = startRect.height * s;
                                            }
                                            moved = true;
                                            overlayModel.set(overlay.index, {
                                                ox: sx > 0 ? startRect.x : startRect.x + startRect.width - w,
                                                oy: sy > 0 ? startRect.y : startRect.y + startRect.height - h,
                                                ow: w,
                                                oh: h
                                            });
                                        }
                                        onReleased: {
                                            if (moved)
                                                root.pushUndo(before);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // The crop being drawn, over everything else while cropping.
                    Item {
                        id: cropLayer

                        anchors.fill: parent
                        visible: root.cropping

                        // Dragging anywhere outside the crop draws a new one.
                        MouseArea {
                            property point start

                            anchors.fill: parent
                            cursorShape: Qt.CrossCursor
                            onPressed: mouse => { // qmllint disable signal-handler-parameters
                                start = Qt.point(CUtils.clamp(mouse.x, 0, root.imageWidth), CUtils.clamp(mouse.y, 0, root.imageHeight));
                                root.pendingCrop = Qt.rect(start.x, start.y, 0, 0);
                            }
                            onPositionChanged: mouse => { // qmllint disable signal-handler-parameters
                                const x = CUtils.clamp(mouse.x, 0, root.imageWidth);
                                const y = CUtils.clamp(mouse.y, 0, root.imageHeight);
                                root.pendingCrop = Qt.rect(Math.min(start.x, x), Math.min(start.y, y), Math.abs(x - start.x), Math.abs(y - start.y));
                            }
                        }

                        // Dims what the crop leaves out.
                        Rectangle {
                            x: 0
                            y: 0
                            width: parent.width
                            height: root.pendingCrop.y
                            color: Qt.alpha("black", 0.5)
                        }
                        Rectangle {
                            x: 0
                            y: root.pendingCrop.y + root.pendingCrop.height
                            width: parent.width
                            height: parent.height - y
                            color: Qt.alpha("black", 0.5)
                        }
                        Rectangle {
                            x: 0
                            y: root.pendingCrop.y
                            width: root.pendingCrop.x
                            height: root.pendingCrop.height
                            color: Qt.alpha("black", 0.5)
                        }
                        Rectangle {
                            x: root.pendingCrop.x + root.pendingCrop.width
                            y: root.pendingCrop.y
                            width: parent.width - x
                            height: root.pendingCrop.height
                            color: Qt.alpha("black", 0.5)
                        }

                        Rectangle {
                            id: cropRect

                            x: root.pendingCrop.x
                            y: root.pendingCrop.y
                            width: root.pendingCrop.width
                            height: root.pendingCrop.height
                            color: "transparent"
                            border.width: scene.lineWidth
                            border.color: Colours.palette.m3primary

                            // Dragging inside the crop moves it, keeping it on the capture.
                            MouseArea {
                                property point start
                                property rect startRect

                                anchors.fill: parent
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.SizeAllCursor
                                onPressed: mouse => { // qmllint disable signal-handler-parameters
                                    start = mapToItem(scene, mouse.x, mouse.y);
                                    startRect = root.pendingCrop;
                                }
                                onPositionChanged: mouse => { // qmllint disable signal-handler-parameters
                                    const p = mapToItem(scene, mouse.x, mouse.y);
                                    const x = CUtils.clamp(startRect.x + p.x - start.x, 0, root.imageWidth - startRect.width);
                                    const y = CUtils.clamp(startRect.y + p.y - start.y, 0, root.imageHeight - startRect.height);
                                    root.pendingCrop = Qt.rect(x, y, startRect.width, startRect.height);
                                }
                            }

                            // Corner handles resize the crop freely.
                            Repeater {
                                model: [[-1, -1], [1, -1], [-1, 1], [1, 1]]

                                delegate: Rectangle {
                                    id: cropHandle

                                    required property var modelData

                                    x: (modelData[0] < 0 ? 0 : cropRect.width) - width / 2
                                    y: (modelData[1] < 0 ? 0 : cropRect.height) - height / 2
                                    width: scene.handleSize
                                    height: scene.handleSize
                                    radius: width / 2
                                    color: Colours.palette.m3primary
                                    border.width: scene.lineWidth
                                    border.color: Colours.palette.m3onPrimary

                                    MouseArea {
                                        // The corner opposite the handle, which stays where it is.
                                        property point fixed

                                        anchors.fill: parent
                                        anchors.margins: -scene.handleSize / 2
                                        cursorShape: cropHandle.modelData[0] === cropHandle.modelData[1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                                        onPressed: {
                                            const c = root.pendingCrop;
                                            fixed = Qt.point(cropHandle.modelData[0] < 0 ? c.x + c.width : c.x, cropHandle.modelData[1] < 0 ? c.y + c.height : c.y);
                                        }
                                        onPositionChanged: mouse => { // qmllint disable signal-handler-parameters
                                            const p = mapToItem(scene, mouse.x, mouse.y);
                                            const fx = fixed.x;
                                            const fy = fixed.y;
                                            const x = CUtils.clamp(p.x, 0, root.imageWidth);
                                            const y = CUtils.clamp(p.y, 0, root.imageHeight);
                                            root.pendingCrop = Qt.rect(Math.min(fx, x), Math.min(fy, y), Math.abs(x - fx), Math.abs(y - fy));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
