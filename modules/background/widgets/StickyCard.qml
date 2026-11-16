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

// --- Sticky note: short text written straight into the card, plain, on a ruled page, or as a headline ---
WidgetCard {
    id: sticky

    readonly property bool lined: sticky.variant === "lined"
    readonly property bool headline: sticky.variant === "headline"

    // The note is a plain file, so it outlives the shell reloading
    readonly property string notePath: `${Paths.data}/sticky-note.md`
    // Trimmed, so a note of nothing but blank lines still reads as empty
    readonly property string body: sticky.note.trim()
    // The headline variant splits the note at its first line break: the line above it is the headline, the
    // rest sits small underneath. Nothing about that is stored, so switching variant keeps the same note
    readonly property string headText: sticky.body.split("\n")[0]
    readonly property string restText: {
        const at = sticky.body.indexOf("\n");
        return at < 0 ? "" : sticky.body.slice(at + 1).trim();
    }

    property string note

    property bool editing
    property bool hovered

    function startEditing(): void {
        // A preview is not editable. It reads the same note file as the real card, so typing into a
        // tile in the Add-widget grid would save over the note actually on the desktop
        if (sticky.preview)
            return;

        if (sticky.headline) {
            headInput.text = sticky.headText;
            restInput.text = sticky.restText;
            sticky.editing = true;
            headInput.forceActiveFocus();
            headInput.cursorPosition = headInput.text.length;
            return;
        }

        const editor = sticky.lined ? linedInput : input;
        editor.text = sticky.note;
        sticky.editing = true;
        editor.forceActiveFocus();
        if (sticky.lined)
            editor.cursorPosition = editor.text.length;
    }

    // What is in the editor right now, put back together into the one note the file holds
    function draft(): string {
        if (sticky.headline)
            return restInput.text.trim() !== "" ? `${headInput.text}\n${restInput.text}` : headInput.text;
        return sticky.lined ? linedInput.text : input.text;
    }

    // The headline variant edits in two fields, and moving between them drops focus from one before the
    // other has it; checked once that has settled, so only leaving the card ends the edit
    function checkFocus(): void {
        if (sticky.editing && !headInput.activeFocus && !restInput.activeFocus && !linedInput.activeFocus && !input.activeFocus)
            sticky.stopEditing();
    }

    function stopEditing(): void {
        if (!sticky.editing)
            return;

        // Read before `editing` drops, which is what lets the ruled page go back to following the note
        const text = sticky.draft();
        sticky.editing = false;
        save.stop();
        sticky.note = text;
        sticky.write();
    }

    function write(): void {
        store.setText(sticky.note);
    }

    // The headline is the note's own title, so that variant leaves the card's off
    title: sticky.headline ? "" : Tr.tr("Sticky note")
    icon: sticky.headline ? "" : "sticky_note_2"
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

    // Saved as typing settles rather than on every keystroke. What has been typed is taken into the note
    // first, so it is the edit that reaches the file rather than the note as it stood before it
    Timer {
        id: save

        interval: 400
        onTriggered: {
            sticky.note = sticky.draft();
            sticky.write();
        }
    }

    StyledRect {
        visible: !sticky.lined && !sticky.headline
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

    // Lined: the same note on a notebook page, ruled to the text's own line height with a margin down the
    // left. One editor serves both reading and typing, read-only until clicked, so the rules sit under the
    // same lines either way and nothing jumps as an edit starts
    StyledRect {
        visible: sticky.lined
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        implicitHeight: 60
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh
        clip: true

        VerticalFadeFlickable {
            id: pageFlick

            // A line's height as the editor lays it out; an empty note is still one line
            readonly property real rule: linedInput.lineCount > 0 ? linedInput.contentHeight / linedInput.lineCount : 20
            readonly property real margin: 30

            function ensureVisible(r: rect): void {
                if (pageFlick.contentY >= r.y)
                    pageFlick.contentY = r.y;
                else if (pageFlick.contentY + pageFlick.height <= r.y + r.height)
                    pageFlick.contentY = r.y + r.height - pageFlick.height;
            }

            anchors.fill: parent
            anchors.topMargin: Tokens.padding.medium
            anchors.bottomMargin: Tokens.padding.small
            contentWidth: width
            contentHeight: linedInput.contentHeight
            interactive: !sticky.preview

            TapHandler {
                enabled: !sticky.editing
                onTapped: sticky.startEditing()
            }

            // Ruled past the end of the writing, down to the bottom of the page, and scrolling with it
            Repeater {
                model: Math.ceil(Math.max(pageFlick.height, linedInput.contentHeight) / pageFlick.rule) + 1

                Rectangle {
                    required property int index

                    x: 0
                    y: (index + 1) * pageFlick.rule - 2
                    width: pageFlick.width
                    height: 1
                    color: Qt.alpha(Colours.palette.m3outlineVariant, 0.7)
                }
            }

            TextEdit {
                id: linedInput

                x: pageFlick.margin + Tokens.padding.small
                width: pageFlick.width - x - Tokens.padding.medium
                // Off while only being read, so the press reaches the page's tap rather than an editor
                // that can't do anything with it
                enabled: sticky.editing
                readOnly: !sticky.editing
                activeFocusOnPress: false
                wrapMode: TextEdit.Wrap
                selectByMouse: sticky.editing
                persistentSelection: true
                color: Colours.palette.m3onSurface
                selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                selectedTextColor: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                renderType: Text.NativeRendering

                onCursorRectangleChanged: {
                    if (sticky.editing)
                        pageFlick.ensureVisible(cursorRectangle);
                }

                onTextChanged: {
                    if (sticky.editing)
                        save.restart();
                }

                Keys.onEscapePressed: sticky.stopEditing()

                onActiveFocusChanged: {
                    if (!activeFocus && sticky.editing)
                        sticky.stopEditing();
                }

                // Left as it is when an edit starts, rather than restored, so the text being typed into is
                // the note and not whatever the editor held before the binding first applied
                Binding on text {
                    when: !sticky.editing
                    value: sticky.note
                    restoreMode: Binding.RestoreNone
                }
            }

            StyledText {
                x: linedInput.x
                width: linedInput.width
                visible: sticky.body === "" && !sticky.editing
                text: Tr.tr("Click to write a note")
                color: Colours.palette.m3outline
                font: Tokens.font.body.medium
                elide: Text.ElideRight
            }
        }

        // The margin rule, outside the flickable so it runs the full height of the page whatever is scrolled
        Rectangle {
            x: pageFlick.margin
            width: 1
            height: parent.height
            color: Qt.alpha(Colours.palette.m3error, 0.5)
        }

        HoverHandler {
            cursorShape: Qt.IBeamCursor
            onHoveredChanged: sticky.hovered = hovered
        }
    }

    // Headline: the first line of the note big, the rest small beneath it. Typed into in two parts, the
    // headline and the rest, with Return moving from the one to the other
    Item {
        visible: sticky.headline
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        implicitHeight: 60

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.small

            Item {
                Layout.fillWidth: true
                // The height of the size it was fitted at, not the size it asked for
                implicitHeight: sticky.editing ? headInput.implicitHeight : headLabel.contentHeight

                StyledText {
                    id: headLabel

                    width: parent.width
                    visible: !sticky.editing
                    elide: Text.ElideRight
                    // A long headline steps down a size or two before it gives up and elides
                    fontSizeMode: Text.HorizontalFit
                    minimumPointSize: Tokens.font.title.medium.pointSize
                    textFormat: Text.PlainText
                    text: sticky.body !== "" ? sticky.headText : Tr.tr("Click to write a note")
                    color: sticky.body !== "" ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    font: sticky.body !== "" ? Tokens.font.headline.small : Tokens.font.body.medium
                }

                TextInput {
                    id: headInput

                    width: parent.width
                    visible: sticky.editing
                    clip: true
                    selectByMouse: true
                    color: Colours.palette.m3onSurface
                    selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                    selectedTextColor: Colours.palette.m3onSurface
                    font: Tokens.font.headline.small
                    renderType: Text.NativeRendering

                    onTextEdited: save.restart()
                    onAccepted: {
                        restInput.forceActiveFocus();
                        restInput.cursorPosition = 0;
                    }

                    Keys.onEscapePressed: sticky.stopEditing()
                    onActiveFocusChanged: {
                        if (!activeFocus)
                            Qt.callLater(sticky.checkFocus);
                    }
                }
            }

            StyledRect {
                implicitWidth: 28
                implicitHeight: 3
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                clip: true

                StyledText {
                    anchors.fill: parent
                    visible: !sticky.editing
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: sticky.restText
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }

                Flickable {
                    id: restFlick

                    anchors.fill: parent
                    visible: sticky.editing
                    contentWidth: width
                    contentHeight: restInput.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: restInput

                        width: restFlick.width
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        color: Colours.palette.m3onSurfaceVariant
                        selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                        selectedTextColor: Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        renderType: Text.NativeRendering

                        onCursorRectangleChanged: {
                            const r = cursorRectangle;
                            if (restFlick.contentY >= r.y)
                                restFlick.contentY = r.y;
                            else if (restFlick.contentY + restFlick.height <= r.y + r.height)
                                restFlick.contentY = r.y + r.height - restFlick.height;
                        }

                        onTextChanged: {
                            if (sticky.editing)
                                save.restart();
                        }

                        // Backspace at the very start goes back up to the end of the headline
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Backspace && restInput.cursorPosition === 0 && restInput.selectedText === "") {
                                headInput.forceActiveFocus();
                                headInput.cursorPosition = headInput.text.length;
                                event.accepted = true;
                            }
                        }
                        Keys.onEscapePressed: sticky.stopEditing()
                        onActiveFocusChanged: {
                            if (!activeFocus)
                                Qt.callLater(sticky.checkFocus);
                        }
                    }
                }
            }
        }

        TapHandler {
            enabled: !sticky.editing
            onTapped: sticky.startEditing()
        }

        HoverHandler {
            cursorShape: Qt.IBeamCursor
            onHoveredChanged: sticky.hovered = hovered
        }
    }
}
