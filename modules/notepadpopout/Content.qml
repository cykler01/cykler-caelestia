pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// The notepad: the fourth tab of the notification popout (see
// modules/notifpopout/Content.qml), next to the to-do list. One free-form text
// buffer, autosaved as it is typed by the Notepad service (services/Notepad.qml);
// no lists, no formatting, no toolbar.
Item {
    id: root

    required property bool open
    required property ScreenState screenState

    // Pushes the stored buffer into the editor, but only while nothing is being
    // typed in it: a slow first load must never land on top of the first keystrokes,
    // and once the user is typing the editor is the source of truth
    function seedFromStore(): void {
        if (!editor.activeFocus && editor.text !== Notepad.text)
            editor.text = Notepad.text;
    }

    onOpenChanged: {
        if (open)
            editor.forceActiveFocus();
    }

    focus: true
    Keys.onEscapePressed: root.screenState.sidebar = false
    Component.onCompleted: root.seedFromStore()

    // The store loads asynchronously, so the first text may arrive after this
    // tab was built
    Connections {
        function onTextChanged(): void {
            root.seedFromStore();
        }

        target: Notepad
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerHigh

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            clip: true
            contentWidth: width
            contentHeight: Math.max(editor.implicitHeight, height)
            boundsBehavior: Flickable.StopAtBounds

            StyledText {
                anchors.left: editor.left
                anchors.top: editor.top
                visible: editor.text.length === 0
                text: Tr.tr("Start typing…")
                color: Colours.palette.m3outline
                font: Tokens.font.body.medium
            }

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

                onTextChanged: Notepad.save(text)

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
