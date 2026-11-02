pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background
import qs.modules.launcher.services

// --- To-do: the task lists from the sidebar, either the next few or just today's ---
WidgetCard {
    id: todo

    readonly property string mode: todo.variant === "today" ? "today" : "upcoming"

    // Read through `revision` so the card follows edits made in the sidebar instead of showing a stale list
    readonly property var shown: {
        void Todo.revision;
        const today = new Date().toDateString();
        const open = Todo.tasks.filter(t => !t.done);
        const list = todo.mode === "today" ? open.filter(t => t.deadline && new Date(t.deadline).toDateString() === today) : open;
        // Soonest deadline first, then the ones with none in the order they were added
        return [...list].sort((a, b) => {
            const da = a.deadline ? new Date(a.deadline).getTime() : Number.POSITIVE_INFINITY;
            const db = b.deadline ? new Date(b.deadline).getTime() : Number.POSITIVE_INFINITY;
            return da - db;
        }).slice(0, 6);
    }

    function deadlineText(task: var): string {
        if (!task.deadline)
            return "";
        const d = new Date(task.deadline);
        if (isNaN(d.getTime()))
            return "";
        return d.toDateString() === new Date().toDateString() ? Tr.tr("Today") : Qt.formatDate(d, "d MMM");
    }

    title: todo.mode === "today" ? Tr.tr("Due today") : Tr.tr("To-do")
    icon: "checklist"

    StyledText {
        Layout.fillWidth: true
        visible: todo.shown.length === 0
        wrapMode: Text.Wrap
        text: todo.mode === "today" ? Tr.tr("Nothing due today") : Tr.tr("Nothing to do")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    Repeater {
        model: todo.shown

        RowLayout {
            id: taskRow

            required property var modelData

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "radio_button_unchecked"
                    color: Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.small
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Todo.toggleDone(taskRow.modelData.id)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: taskRow.modelData.text
                elide: Text.ElideRight
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }

            StyledText {
                visible: text !== ""
                text: todo.deadlineText(taskRow.modelData)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }
}
