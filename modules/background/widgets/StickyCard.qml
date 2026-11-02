pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.utils
import qs.modules.background

// --- Sticky note: short text written straight into the card ---
WidgetCard {
    id: sticky

    // The note is a plain file, so it outlives the shell reloading
    readonly property string notePath: `${Paths.data}/sticky-note.md`
    // Trimmed, so a note of nothing but blank lines still reads as empty
    readonly property string body: sticky.note.trim()

    property string note

    property bool editing
    property bool hovered

    function startEditing(): void {
        // A preview is not editable. It reads the same note file as the real card, so typing into a
        // tile in the Add-widget grid would save over the note actually on the desktop
        if (sticky.preview)
            return;

        input.text = sticky.note;
        sticky.editing = true;
        input.forceActiveFocus();
    }

    function stopEditing(): void {
        if (!sticky.editing)
            return;

        sticky.editing = false;
        save.stop();
        sticky.note = input.text;
        sticky.write();
    }

    function write(): void {
        store.setText(sticky.note);
    }

    title: Tr.tr("Sticky note")
    icon: "sticky_note_2"
    onHoveredChanged: sticky.keyboardWanted(sticky.hovered || sticky.editing)
    onEditingChanged: sticky.keyboardWanted(sticky.hovered || sticky.editing)

    FileView {
        id: store

        printErrors: false
        watchChanges: true
        path: sticky.notePath

        // Text being typed in the card wins over what is on disk, so the file can't pull the
        // caret out from under it
        onLoaded: {
            if (!sticky.editing)
                sticky.note = text();
        }
        // The signal this FileView emits when the file on disk changes under it
        onFileChanged: {
            if (!sticky.editing)
                sticky.note = text();
        }
        // No file yet is the normal first run: the first keystroke creates it
        onLoadFailed: sticky.note = ""
    }

    // Saved as typing settles rather than on every keystroke
    Timer {
        id: save

        interval: 400
        onTriggered: sticky.write()
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        // The note no longer sets the card's height. A long one scrolls inside the card instead of
        // growing it, so the widget keeps the footprint its variant asks for however much is written
        implicitHeight: 60
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh
        opacity: 0.85
        clip: true

        VerticalFadeFlickable {
            id: noteFlick

            // Keeps the caret in view while typing past the bottom of the card
            function ensureVisible(r: rect): void {
                if (noteFlick.contentY >= r.y)
                    noteFlick.contentY = r.y;
                else if (noteFlick.contentY + noteFlick.height <= r.y + r.height)
                    noteFlick.contentY = r.y + r.height - noteFlick.height;
            }

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            contentWidth: width
            contentHeight: sticky.editing ? input.implicitHeight : noteText.implicitHeight
            // A preview is for looking at: without this, the wheel over a note in the Add-widget
            // grid scrolls the note instead of the page it sits on
            interactive: !sticky.preview

            // On the flickable, not on the card behind it: an interactive flickable takes the press
            // for its own drag detection, so a handler on the card never sees the tap and the note
            // could never be opened to type in. Disabled while typing so clicks place the caret
            TapHandler {
                enabled: !sticky.editing
                onTapped: sticky.startEditing()
            }

            StyledText {
                id: noteText

                width: noteFlick.width
                visible: !sticky.editing
                text: sticky.body !== "" ? sticky.note : Tr.tr("Click to write a note")
                color: sticky.body !== "" ? Colours.palette.m3onSurface : Colours.palette.m3outline
                font: Tokens.font.body.medium
                wrapMode: Text.Wrap
            }

            TextEdit {
                id: input

                width: noteFlick.width
                visible: sticky.editing
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                persistentSelection: true
                color: Colours.palette.m3onSurface
                selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                selectedTextColor: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                renderType: Text.NativeRendering

                onCursorRectangleChanged: noteFlick.ensureVisible(cursorRectangle)

                onTextChanged: {
                    if (sticky.editing)
                        save.restart();
                }

                Keys.onEscapePressed: sticky.stopEditing()

                onActiveFocusChanged: {
                    // Clicking off the note, or the desktop being covered, ends the edit
                    if (!activeFocus && sticky.editing)
                        sticky.stopEditing();
                }
            }
        }

        // Separate from the tap, so hovering stays tracked while that is disabled
        HoverHandler {
            cursorShape: Qt.IBeamCursor
            onHoveredChanged: sticky.hovered = hovered
        }
    }
}
