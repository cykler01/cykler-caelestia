pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background
import qs.modules.launcher.services

// --- To-do: the task lists from the sidebar, the next few, just today's, or the one that matters most ---
WidgetCard {
    id: todo

    readonly property string mode: todo.variant === "today" ? "today" : "upcoming"
    readonly property bool focusView: todo.variant === "focus"

    // Every open task, soonest deadline first. Focus reads the head of it and counts the rest, so it
    // can't be cut down to the handful the lists show
    readonly property var open: {
        void Todo.revision;
        return Todo.tasks.filter(t => !t.done).sort((a, b) => todo.deadlineTime(a) - todo.deadlineTime(b));
    }
    readonly property var focused: todo.open.length > 0 ? todo.open[0] : null
    // Ticked over once a minute so a countdown doesn't freeze at whatever it said when the card loaded
    property double now: Date.now()

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

    // A task with no deadline (or one that can't be read) sorts after every dated one, keeping the order
    // it was added in among the rest
    function deadlineTime(task: var): double {
        const time = task.deadline ? new Date(task.deadline).getTime() : NaN;
        return isNaN(time) ? Number.POSITIVE_INFINITY : time;
    }

    // How far off the deadline is, in the largest unit that still says something
    function countdownText(task: var): string {
        const time = task ? todo.deadlineTime(task) : Number.POSITIVE_INFINITY;
        if (!isFinite(time))
            return Tr.tr("No deadline");

        const diff = time - todo.now;
        const minutes = Math.round(Math.abs(diff) / 60000);
        const hours = Math.round(minutes / 60);
        const days = Math.round(hours / 24);
        const span = minutes < 60 ? Tr.tr("%1 min").arg(Math.max(1, minutes)) : hours < 24 ? Tr.tr("%1 h").arg(hours) : Tr.tr("%1 d").arg(days);
        return diff < 0 ? Tr.tr("Overdue by %1").arg(span) : Tr.tr("Due in %1").arg(span);
    }

    function deadlineText(task: var): string {
        if (!task.deadline)
            return "";
        const d = new Date(task.deadline);
        if (isNaN(d.getTime()))
            return "";
        return d.toDateString() === new Date().toDateString() ? Tr.tr("Today") : Qt.formatDate(d, "d MMM");
    }

    title: todo.focusView ? Tr.tr("Focus") : todo.mode === "today" ? Tr.tr("Due today") : Tr.tr("To-do")
    icon: todo.focusView ? "target" : "checklist"

    Timer {
        interval: 60000
        repeat: true
        running: todo.focusView
        onTriggered: todo.now = Date.now()
    }

    StyledText {
        Layout.fillWidth: true
        visible: !todo.focusView && todo.shown.length === 0
        wrapMode: Text.Wrap
        text: todo.mode === "today" ? Tr.tr("Nothing due today") : Tr.tr("Nothing to do")
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    Repeater {
        model: todo.focusView ? [] : todo.shown

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

    // Focus: the one task to do next, large, with the way to be done with it right beside it
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: todo.focusView && todo.focused !== null
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: todo.focused ? Todo.listName(todo.focused.listId) : ""
                    color: Colours.palette.m3primary
                    font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: todo.focused?.text ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.medium
                }
            }

            // Ticking it off brings the next task up in its place. Not in a preview, which shows the real
            // list and would otherwise complete a task from the Add-widget grid
            StyledRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 48
                implicitHeight: 48
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "check"
                    color: Colours.palette.m3onPrimaryContainer
                    fontStyle: Tokens.font.icon.medium
                }

                StateLayer {
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3onPrimaryContainer
                    disabled: todo.preview
                    onClicked: Todo.toggleDone(todo.focused.id)
                }
            }
        }

        // Overdue reads in the error colour so it stands out from a deadline that is merely close, and
        // what else is waiting shares the line rather than taking one of its own
        RowLayout {
            readonly property bool overdue: todo.focused !== null && todo.deadlineTime(todo.focused) < todo.now

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                text: parent.overdue ? "alarm" : "schedule"
                color: parent.overdue ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: todo.countdownText(todo.focused)
                color: parent.overdue ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }

            StyledText {
                text: todo.open.length <= 1 ? Tr.tr("Nothing else waiting") : Tr.tr("+%1 more").arg(todo.open.length - 1)
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: todo.focusView && todo.focused === null
        spacing: Tokens.spacing.extraSmall

        Item {
            Layout.fillHeight: true
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: "task_alt"
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Tr.tr("All clear")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
