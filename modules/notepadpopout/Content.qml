pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// The notepad: the fourth tab of the notification popout (see
// modules/notifpopout/Content.qml). Notes are plain files edited in place, autosaving
// as they are typed. The file picker is only shown on demand: the folder button in the
// header slides it in, and opening a file (or a new note) slides it back out so the
// editor has the whole tab. It starts at the notes directory (Documents by default) and
// can walk the whole filesystem from there. That directory and the file last opened are
// remembered by the Notepad service (services/Notepad.qml).
Item {
    id: root

    required property bool open
    required property ScreenState screenState

    // The directory being browsed and the file open in the editor. The browser list and
    // the breadcrumb read currentPath; the editor reads selectedPath.
    property string currentPath: ""
    property string selectedPath: ""
    property bool adding: false
    // Whether the file picker is showing. It takes a good part of the tab, which the
    // editor should have while a note is open, so it is opened from the header and closed
    // again the moment a file is picked.
    property bool browsing: false
    // False from the moment a file is chosen until its contents have loaded, so the
    // editor's own text changes during that window are not written back over the file
    property bool fileReady: false

    // Up only stops at the filesystem root, so the picker can walk the whole filesystem
    readonly property bool canGoUp: {
        const trimmed = root.currentPath.replace(/\/+$/, "");
        return trimmed !== "" && trimmed !== "/";
    }
    // Nothing here filters the browser, but only something that looks like text is ever
    // loaded, so opening a stray binary cannot turn it into a mangled note
    readonly property var textSuffixes: ["md", "markdown", "txt", "text", "org", "rst", "log", "json", "yaml", "yml", "toml", "ini", "conf", "cfg", "csv", "tsv", "tex", "sh", "bash", "zsh", "fish", "py", "js", "ts", "qml", "css", "html", "xml", "lua", "rs", "go", "java", "nix"]
    readonly property bool selectedIsText: root.selectedPath !== "" && root.isText(root.selectedPath)

    function isText(path: string): bool {
        const name = path.split("/").pop();
        const dot = name.lastIndexOf(".");
        // No suffix, or a dotfile's leading dot, counts as plain text
        if (dot <= 0)
            return true;

        return root.textSuffixes.includes(name.slice(dot + 1).toLowerCase());
    }

    // The store loads almost immediately, but not before this tab is built, so both the
    // first load and a directory change are funnelled through here
    function syncFromStore(): void {
        if (!Notepad.loaded)
            return;

        root.currentPath = Notepad.dir;
        if (Notepad.lastFile.startsWith(`${Notepad.dir}/`))
            root.openPath(Notepad.lastFile);
        else
            root.closeFile();
    }

    function openPath(path: string): void {
        root.selectedPath = path;
        Notepad.setLastFile(path);
        // Picking a file is the picker's job done, so it gets out of the editor's way
        root.browsing = false;
    }

    function closeFile(): void {
        root.selectedPath = "";
        root.fileReady = false;
    }

    function enter(entry: var): void {
        root.currentPath = entry.path;
        root.closeFile();
    }

    function goUp(): void {
        if (!root.canGoUp)
            return;

        const parent = root.currentPath.replace(/\/+$/, "").split("/").slice(0, -1).join("/");
        root.currentPath = parent.length === 0 ? "/" : parent;
        root.closeFile();
    }

    // A file that appears in the browser already, and is created empty on disk, so the
    // editor opens a real file rather than a missing one
    function createNote(name: string): void {
        const trimmed = name.trim();
        if (!trimmed)
            return;

        const path = `${root.currentPath}/${trimmed}`;
        Quickshell.execDetached(["touch", path]);
        root.openPath(path);
    }

    onSelectedPathChanged: root.fileReady = false

    onOpenChanged: {
        if (!open)
            return;

        // Nothing to edit yet, so show the picker rather than an empty pane; with a note
        // open it stays out of the way
        if (root.selectedPath === "")
            root.browsing = true;
        else if (root.selectedIsText)
            editor.forceActiveFocus();
    }

    onBrowsingChanged: {
        if (!browsing) {
            root.adding = false;
            newField.text = "";
        }
    }

    focus: true
    Keys.onEscapePressed: {
        if (root.adding)
            root.adding = false;
        else if (root.browsing)
            root.browsing = false;
        else
            root.screenState.sidebar = false;
    }
    Component.onCompleted: root.syncFromStore()

    Connections {
        function onLoadedChanged(): void {
            root.syncFromStore();
        }
        function onDirChanged(): void {
            root.syncFromStore();
        }

        target: Notepad
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            IconButton {
                icon: "folder_open"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.small
                isToggle: true
                checked: root.browsing
                onClicked: root.browsing = !root.browsing
            }

            IconButton {
                icon: "arrow_upward"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.small
                visible: root.browsing
                disabled: !root.canGoUp
                onClicked: root.goUp()
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: pathText.implicitHeight + Tokens.padding.small * 2

                radius: Tokens.rounding.full
                color: Colours.tPalette.m3surfaceContainerHigh

                StyledText {
                    id: pathText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.medium

                    // The directory while picking, the open note's name otherwise
                    text: root.browsing ? Paths.shortenHome(root.currentPath) : (root.selectedPath === "" ? "" : root.selectedPath.split("/").pop())
                    elide: Text.ElideLeft
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }

            IconButton {
                icon: "note_add"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.small
                visible: root.browsing
                onClicked: {
                    root.adding = true;
                    newField.forceActiveFocus();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: opacity > 0
            opacity: root.adding ? 1 : 0
            spacing: Tokens.spacing.small

            Behavior on opacity {
                Anim {
                    type: Anim.FastEffects
                }
            }

            StyledTextField {
                id: newField

                Layout.fillWidth: true
                leadingIcon: "note_add"
                placeholderText: Tr.tr("Note name")
                onAccepted: {
                    root.createNote(text);
                    text = "";
                    root.adding = false;
                }
            }

            IconButton {
                icon: "close"
                type: IconButton.Text
                isRound: true
                font: Tokens.font.icon.small
                onClicked: {
                    newField.text = "";
                    root.adding = false;
                }
            }
        }

        // The picker. Its height is animated so the editor grows smoothly back into the
        // space when it closes; clip keeps the list from spilling out of the shrinking card.
        StyledRect {
            id: browserCard

            Layout.fillWidth: true
            implicitHeight: root.browsing ? 180 : 0
            // Stays visible through the collapse so the shrink itself is what is seen
            visible: root.browsing || implicitHeight > 0.5

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh
            clip: true

            Behavior on implicitHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            StyledText {
                anchors.centerIn: list
                visible: list.count === 0 && !browser.loading
                horizontalAlignment: Text.AlignHCenter
                text: Tr.tr("This folder is empty")
                color: Colours.palette.m3outline
            }

            ListView {
                id: list

                anchors.fill: parent
                anchors.margins: Tokens.padding.small

                clip: true
                spacing: Tokens.spacing.extraSmall / 2

                model: FileSystemModel {
                    id: browser

                    path: root.currentPath
                }

                delegate: StyledRect {
                    id: entry

                    required property FileSystemEntry modelData

                    readonly property bool isSelected: !entry.modelData.isDir && entry.modelData.path === root.selectedPath

                    width: ListView.view.width
                    implicitHeight: entryRow.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.medium
                    color: entry.isSelected ? Colours.tPalette.m3secondaryContainer : "transparent"

                    StateLayer {
                        radius: entry.radius
                        color: entry.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        onClicked: {
                            if (entry.modelData.isDir)
                                root.enter(entry.modelData);
                            else
                                root.openPath(entry.modelData.path);
                        }
                    }

                    RowLayout {
                        id: entryRow

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: entry.modelData.isDir ? "folder" : "description"
                            color: entry.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            fontStyle: Tokens.font.icon.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: entry.modelData.name
                            elide: Text.ElideRight
                            color: entry.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                        }
                    }
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh

            StyledText {
                anchors.centerIn: parent
                visible: root.selectedPath === "" || !root.selectedIsText
                horizontalAlignment: Text.AlignHCenter
                text: root.selectedIsText ? "" : (root.selectedPath === "" ? Tr.tr("Select a note to edit") : Tr.tr("This does not look like a text file"))
                color: Colours.palette.m3outline
            }

            Flickable {
                id: flick

                anchors.fill: parent
                anchors.margins: Tokens.padding.large

                visible: root.selectedIsText
                clip: true
                contentWidth: width
                contentHeight: Math.max(editor.implicitHeight, height)
                boundsBehavior: Flickable.StopAtBounds

                TextEdit {
                    id: editor

                    width: flick.width
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    persistentSelection: true
                    color: Colours.palette.m3onSurface
                    selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                    selectedTextColor: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                    renderType: Text.NativeRendering

                    onTextChanged: {
                        if (root.fileReady && root.selectedIsText)
                            fileView.setText(text);
                    }

                    // Keep the caret in view while typing past either edge
                    onCursorRectangleChanged: {
                        const y = cursorRectangle.y;
                        if (y < flick.contentY)
                            flick.contentY = y;
                        else if (y + cursorRectangle.height > flick.contentY + flick.height)
                            flick.contentY = y + cursorRectangle.height - flick.height;
                    }
                }

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: flick
                }
            }
        }
    }

    FileView {
        id: fileView

        printErrors: false
        path: root.selectedIsText ? root.selectedPath : ""
        onLoaded: {
            if (root.selectedPath === "" || fileView.path !== root.selectedPath)
                return;

            root.fileReady = false;
            editor.text = text();
            root.fileReady = true;
        }
        onLoadFailed: err => {
            // A note created a moment ago may not be on disk yet: open it empty, and
            // the first keystroke writes it out
            if (root.selectedPath === "" || fileView.path !== root.selectedPath || err !== FileViewError.FileNotFound)
                return;

            editor.text = "";
            root.fileReady = true;
        }
    }
}
