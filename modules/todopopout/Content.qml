pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.services

// The to-do list: the third tab of the notification popout (see modules/notifpopout/Content.qml),
// with a list-of-lists tab strip, the tasks in the chosen list (wrapping properly, unlike the
// one-line launcher entries), and an add-task field. Click a task's text to rename it in place;
// the clock icon opens the small deadline/reminder editor underneath it.
Item {
    id: root

    required property bool open
    required property ScreenState screenState

    // Which list is showing. Falls back to the first list if the chosen one was deleted.
    property string selectedListId: Todo.defaultListId
    // The task currently being renamed inline, or "" for none
    property string editingId: ""
    // The task whose deadline/reminder editor is open, or "" for none
    property string schedulingId: ""
    property bool addingList: false

    readonly property var currentTasks: {
        Todo.revision; // re-evaluate when tasks change
        const listId = root.selectedListId;
        const tasks = Todo.tasks.filter(t => t.listId === listId);
        // Not done first (soonest deadline first, then no deadline), done tasks last
        return tasks.slice().sort((a, b) => {
            if (a.done !== b.done)
                return a.done ? 1 : -1;
            if (!a.deadline !== !b.deadline)
                return a.deadline ? -1 : 1;
            return a.deadline.localeCompare(b.deadline);
        });
    }

    // How the list on show divides up, for the ring in the header. An overdue task counts as
    // overdue only, so the three parts add up to the whole list.
    readonly property int totalTasks: root.currentTasks.length
    readonly property int doneTasks: root.currentTasks.filter(t => t.done).length
    readonly property int overdueTasks: root.currentTasks.filter(t => root.isOverdue(t)).length
    readonly property int todoTasks: root.totalTasks - root.doneTasks - root.overdueTasks

    function formatDate(iso: string): string {
        if (!iso)
            return "";

        const d = new Date(iso);
        if (Number.isNaN(d.getTime()))
            return "";

        const now = new Date();
        const sameYear = d.getFullYear() === now.getFullYear();
        return d.toLocaleString(Qt.locale(), sameYear ? "d MMM, HH:mm" : "d MMM yyyy, HH:mm");
    }

    function isOverdue(task: var): bool {
        if (!task.deadline || task.done)
            return false;

        const at = Date.parse(task.deadline);
        return !Number.isNaN(at) && at < Date.now();
    }

    // The fixed offsets on offer before the deadline, besides the deadline itself and a custom time
    function reminderOffsets(): var {
        return [
            {
                label: Tr.tr("5 minutes before"),
                ms: 5 * 60000
            },
            {
                label: Tr.tr("30 minutes before"),
                ms: 30 * 60000
            },
            {
                label: Tr.tr("1 hour before"),
                ms: 60 * 60000
            },
            {
                label: Tr.tr("1 day before"),
                ms: 24 * 60 * 60000
            },
            {
                label: Tr.tr("1 week before"),
                ms: 7 * 24 * 60 * 60000
            }
        ];
    }

    onOpenChanged: {
        if (open) {
            root.editingId = "";
            root.schedulingId = "";
            root.addingList = false;
            if (!Todo.lists.some(l => l.id === root.selectedListId))
                root.selectedListId = Todo.defaultListId;
            addField.forceActiveFocus();
        }
    }

    focus: true
    Keys.onEscapePressed: {
        if (root.schedulingId !== "") {
            root.schedulingId = "";
        } else if (root.editingId !== "") {
            root.editingId = "";
        } else {
            root.screenState.sidebar = false;
        }
    }

    // Underneath everything else, so it only ever sees a click that nothing above it wanted -
    // blank space in the panel, not a tap on some other row or button. Closing the rename field
    // this way discards whatever was typed, since it is never saved without pressing enter.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            root.editingId = "";
            root.schedulingId = "";
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        // The tabs, the add button and the list actions on the left, with the ring taking the
        // height of those rows on the right
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                id: header

                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                // List tabs
                StyledFlickable {
                    Layout.fillWidth: true
                    implicitHeight: tabRow.implicitHeight
                    contentWidth: tabRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    clip: true

                    RowLayout {
                        id: tabRow

                        spacing: Tokens.spacing.small

                        Repeater {
                            model: Todo.lists

                            StyledRect {
                                id: tab

                                required property var modelData
                                readonly property bool current: modelData.id === root.selectedListId

                                // With only the default list there is nothing to switch between, so
                                // the strip is left out and its name stays out of the header
                                visible: Todo.lists.length > 1
                                implicitWidth: tabLabel.implicitWidth + Tokens.padding.large * 2
                                implicitHeight: tabLabel.implicitHeight + Tokens.padding.small * 2
                                radius: Tokens.rounding.full
                                // The same "picked out" primary highlight the segmented tabs elsewhere use
                                color: tab.current ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh

                                Behavior on color {
                                    CAnim {}
                                }

                                StateLayer {
                                    radius: parent.radius
                                    color: tab.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    onClicked: root.selectedListId = tab.modelData.id
                                }

                                StyledText {
                                    id: tabLabel

                                    anchors.centerIn: parent
                                    text: tab.modelData.name
                                    color: tab.current ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                    font: Tokens.font.label.medium
                                }
                            }
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "add"
                            type: IconButton.Text
                            isRound: true
                            font: Tokens.font.icon.large
                            padding: Tokens.padding.extraSmall
                            onClicked: {
                                root.addingList = true;
                                listField.forceActiveFocus();
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: opacity > 0
                    opacity: root.addingList ? 1 : 0
                    spacing: Tokens.spacing.small

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    StyledTextField {
                        id: listField

                        Layout.fillWidth: true
                        placeholderText: Tr.tr("List name")
                        onAccepted: {
                            if (text.trim()) {
                                root.selectedListId = Todo.addList(text);
                                text = "";
                            }
                            root.addingList = false;
                        }
                    }

                    IconButton {
                        icon: "close"
                        type: IconButton.Text
                        isRound: true
                        font: Tokens.font.icon.small
                        onClicked: {
                            listField.text = "";
                            root.addingList = false;
                        }
                    }
                }
            }

            TodoRing {
                // Matches the height of the rows beside it so the two balance, but capped: the
                // header gains a row while a list is being added, and uncapped the ring grew with
                // it - taking width from the very rows that made it taller
                Layout.preferredWidth: Math.round(Math.min(Math.max(64, header.implicitHeight), 80))
                Layout.preferredHeight: Layout.preferredWidth
                doneCount: root.doneTasks
                overdueCount: root.overdueTasks
                todoCount: root.todoTasks
            }
        }

        // A done task sits struck through at the bottom until cleared by hand, deleted one at a
        // time, or swept away by the auto-clear setting. Deleting the list is only offered for
        // non-default lists.
        //
        // Under the header rather than in it, and a flow rather than a row: these two labels are
        // the widest things in the panel, and in a layout a button that cannot stretch makes its
        // own width a floor the whole column has to honour. Beside the ring they did not fit, so
        // every row in the column - the tasks, the add field - was laid out past the panel's
        // right edge and clipped there, and the ring lost its right side. Down here they have the
        // panel's full width, and a flow sets no floor: on a narrower panel still, the second
        // wraps under the first instead of pushing everything out of the panel
        Flow {
            Layout.fillWidth: true
            visible: root.currentTasks.some(t => t.done) || root.selectedListId !== Todo.defaultListId
            spacing: Tokens.spacing.small

            TextButton {
                type: TextButton.Text
                visible: root.currentTasks.some(t => t.done)
                text: Tr.tr("Clear completed")
                onClicked: Todo.clearCompleted(root.selectedListId)
            }

            TextButton {
                type: TextButton.Text
                visible: root.selectedListId !== Todo.defaultListId
                text: Tr.tr("Delete this list")
                onClicked: {
                    Todo.removeList(root.selectedListId);
                    root.selectedListId = Todo.defaultListId;
                }
            }
        }

        VerticalFadeFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 40
            contentHeight: taskList.implicitHeight
            clip: true

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Tokens.padding.large
                visible: root.currentTasks.length === 0
                horizontalAlignment: Text.AlignHCenter
                text: Tr.tr("Nothing here yet")
                color: Colours.palette.m3outline
            }

            // A plain Column (not a Layout) so completing a task can glide to its new spot at the
            // bottom instead of snapping there
            Column {
                id: taskList

                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.extraSmall

                move: Transition {
                    Anim {
                        properties: "y"
                        type: Anim.DefaultSpatial
                    }
                }

                // Positioners have no "remove" transition of their own (only add/move/populate),
                // so a deleted task just disappears; the others glide into its old spot via "move"
                add: Transition {
                    Anim {
                        property: "opacity"
                        from: 0
                        to: 1
                        type: Anim.FastEffects
                    }
                }

                Repeater {
                    id: taskRepeater

                    // Keyed by id, so an unrelated task changing (done, deadline, ...) doesn't
                    // destroy and recreate every other row's delegate - that churn is what left
                    // a freshly (re)created row's layer stuck on its first, pre-blend paint
                    // (looking flat and grey) until something else forced it to repaint
                    model: ScriptModel {
                        values: root.currentTasks
                        objectProp: "id"
                    }

                    // A grouped list like the settings pages and menus use: connected rows in one
                    // surface, rounded only at the very top and bottom, with the usual hover feedback
                    StyledRect {
                        id: rowBg

                        required property var modelData
                        required property int index

                        readonly property bool isFirst: index === 0
                        readonly property bool isLast: index === taskRepeater.count - 1

                        width: taskList.width
                        implicitHeight: row.implicitHeight + Tokens.padding.medium * 2
                        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                        clip: true
                        // Without this the translucent fill blends twice (itself over whatever's
                        // behind it, then that result blended again) until something forces a
                        // repaint, which is what left rows looking darker/greyed out until the
                        // list changed again - see ContentWindow.qml for the same fix elsewhere
                        layer.enabled: true

                        // Opening the rename field or the scheduling editor grows the row rather
                        // than snapping to its new height; the "move" transition above then
                        // carries the rows below it along smoothly too
                        Behavior on implicitHeight {
                            Anim {
                                type: Anim.DefaultSpatial
                            }
                        }
                        topLeftRadius: rowBg.isFirst ? Tokens.rounding.large : Tokens.rounding.extraSmall
                        topRightRadius: rowBg.isFirst ? Tokens.rounding.large : Tokens.rounding.extraSmall
                        bottomLeftRadius: rowBg.isLast ? Tokens.rounding.large : Tokens.rounding.extraSmall
                        bottomRightRadius: rowBg.isLast ? Tokens.rounding.large : Tokens.rounding.extraSmall

                        ColumnLayout {
                            id: row

                            property var modelData: rowBg.modelData

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Tokens.padding.medium
                            spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            IconButton {
                                id: doneBtn

                                Layout.alignment: Qt.AlignTop
                                icon: row.modelData.done ? "check_circle" : "radio_button_unchecked"
                                type: IconButton.Text
                                isRound: true
                                font: Tokens.font.icon.medium
                                inactiveOnColour: row.modelData.done ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                                onClicked: {
                                    Todo.toggleDone(row.modelData.id);
                                    checkPop.restart();
                                }

                                // A little pop when the task is checked off or restored, rather than
                                // the icon just swapping instantly
                                SequentialAnimation {
                                    id: checkPop

                                    Anim {
                                        target: doneBtn.label
                                        property: "scale"
                                        to: 1.35
                                        type: Anim.FastSpatial
                                    }
                                    Anim {
                                        target: doneBtn.label
                                        property: "scale"
                                        to: 1
                                        type: Anim.FastSpatial
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Tokens.spacing.extraSmall / 2

                                Loader {
                                    Layout.fillWidth: true
                                    active: root.editingId === row.modelData.id
                                    visible: active
                                    opacity: active ? 1 : 0

                                    Behavior on opacity {
                                        Anim {
                                            type: Anim.FastEffects
                                        }
                                    }

                                    sourceComponent: StyledTextField {
                                        text: row.modelData.text
                                        Component.onCompleted: {
                                            forceActiveFocus();
                                            selectAll();
                                        }
                                        onAccepted: {
                                            Todo.editTask(row.modelData.id, {
                                                text
                                            });
                                            root.editingId = "";
                                        }
                                        onActiveFocusChanged: {
                                            if (!activeFocus)
                                                root.editingId = "";
                                        }
                                    }
                                }

                                // The point of this whole feature: the task's text wraps onto
                                // further lines instead of being cut off after one
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.editingId !== row.modelData.id
                                    text: row.modelData.text
                                    wrapMode: Text.Wrap
                                    textFormat: Text.PlainText
                                    // A done task is struck through, which needs building a new font value
                                    // rather than setting both a whole font and one of its sub-properties
                                    font: Qt.font({
                                        family: Tokens.font.body.medium.family,
                                        pointSize: Tokens.font.body.medium.pointSize,
                                        weight: Tokens.font.body.medium.weight,
                                        strikeout: row.modelData.done
                                    })
                                    color: row.modelData.done ? Colours.palette.m3outline : Colours.palette.m3onSurface

                                    Behavior on color {
                                        CAnim {}
                                    }

                                    TapHandler {
                                        onTapped: {
                                            root.schedulingId = "";
                                            root.editingId = row.modelData.id;
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: row.modelData.deadline !== ""
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: "event"
                                        color: root.isOverdue(row.modelData) ? Colours.palette.m3error : Colours.palette.m3outline
                                        fontStyle: Tokens.font.icon.small
                                    }

                                    StyledText {
                                        text: root.formatDate(row.modelData.deadline)
                                        color: root.isOverdue(row.modelData) ? Colours.palette.m3error : Colours.palette.m3outline
                                        font: Tokens.font.label.small
                                    }
                                }

                                // Every reminder gets its own line: there can be more than one
                                Repeater {
                                    model: row.modelData.reminders

                                    RowLayout {
                                        id: reminderRow

                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: Tokens.spacing.small

                                        MaterialIcon {
                                            text: "notifications"
                                            color: Colours.palette.m3outline
                                            fontStyle: Tokens.font.icon.small
                                        }

                                        StyledText {
                                            text: root.formatDate(reminderRow.modelData.at)
                                            color: Colours.palette.m3outline
                                            font: Tokens.font.label.small
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: 0

                                IconButton {
                                    icon: "schedule"
                                    type: IconButton.Text
                                    isRound: true
                                    font: Tokens.font.icon.small
                                    onClicked: root.schedulingId = root.schedulingId === row.modelData.id ? "" : row.modelData.id
                                }

                                IconButton {
                                    icon: "delete"
                                    type: IconButton.Text
                                    isRound: true
                                    font: Tokens.font.icon.small
                                    inactiveOnColour: Colours.palette.m3error
                                    onClicked: Todo.removeTask(row.modelData.id)
                                }
                            }
                        }

                        Loader {
                            Layout.fillWidth: true
                            Layout.leftMargin: Tokens.padding.large
                            active: root.schedulingId === row.modelData.id
                            visible: active
                            opacity: active ? 1 : 0

                            Behavior on opacity {
                                Anim {
                                    type: Anim.FastEffects
                                }
                            }

                            sourceComponent: ColumnLayout {
                                id: editor

                                // "" nothing open, "deadline" the deadline picker, "new" a new
                                // reminder's picker
                                property string editingField: ""

                                spacing: Tokens.spacing.small

                                // Deadline
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Tokens.spacing.small

                                    TextButton {
                                        type: TextButton.Text
                                        text: row.modelData.deadline ? Tr.tr("Deadline: %1").arg(root.formatDate(row.modelData.deadline)) : Tr.tr("Set a deadline")
                                        onClicked: editor.editingField = editor.editingField === "deadline" ? "" : "deadline"
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    IconButton {
                                        visible: row.modelData.deadline !== ""
                                        icon: "close"
                                        type: IconButton.Text
                                        isRound: true
                                        font: Tokens.font.icon.small
                                        onClicked: Todo.editTask(row.modelData.id, {
                                            deadline: ""
                                        })
                                    }
                                }

                                Loader {
                                    Layout.fillWidth: true
                                    active: editor.editingField === "deadline"
                                    visible: active
                                    opacity: active ? 1 : 0

                                    Behavior on opacity {
                                        Anim {
                                            type: Anim.FastEffects
                                        }
                                    }

                                    sourceComponent: ColumnLayout {
                                        // Loader doesn't resize a loaded item to its own width by itself - without
                                        // this, the picker (and the button below it) just take their natural
                                        // width, which can run past the card's edge rather than wrapping to fit it
                                        width: parent.width
                                        spacing: Tokens.spacing.small

                                        DatePicker {
                                            id: deadlinePicker

                                            Layout.fillWidth: true
                                            initial: row.modelData.deadline ? new Date(row.modelData.deadline) : new Date()
                                        }

                                        TextButton {
                                            Layout.alignment: Qt.AlignRight
                                            type: TextButton.Filled
                                            text: Tr.tr("Set deadline")
                                            onClicked: {
                                                Todo.editTask(row.modelData.id, {
                                                    deadline: deadlinePicker.value.toISOString()
                                                });
                                                editor.editingField = "";
                                            }
                                        }
                                    }
                                }

                                // Reminders: any number of them, each its own alarm
                                Repeater {
                                    model: row.modelData.reminders

                                    RowLayout {
                                        id: reminderEditRow

                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: Tokens.spacing.small

                                        MaterialIcon {
                                            text: "notifications"
                                            color: Colours.palette.m3outline
                                            fontStyle: Tokens.font.icon.small
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root.formatDate(reminderEditRow.modelData.at)
                                            color: Colours.palette.m3onSurface
                                            font: Tokens.font.label.small
                                        }

                                        IconButton {
                                            icon: "close"
                                            type: IconButton.Text
                                            isRound: true
                                            font: Tokens.font.icon.small
                                            onClicked: Todo.removeReminder(row.modelData.id, reminderEditRow.index)
                                        }
                                    }
                                }

                                TextButton {
                                    id: addReminderBtn

                                    Layout.alignment: Qt.AlignLeft
                                    type: TextButton.Text
                                    text: Tr.tr("Add reminder")
                                    onClicked: reminderMenu.expanded = !reminderMenu.expanded

                                    Menu {
                                        id: reminderMenu

                                        attachTo: addReminderBtn
                                        thisSideX: Menu.Left
                                        attachSideX: Menu.Left
                                        items: {
                                            const list = [];
                                            if (row.modelData.deadline) {
                                                list.push(itemComp.createObject(reminderMenu, {
                                                            text: Tr.tr("At the deadline"),
                                                            icon: "event",
                                                            value: 0
                                                        }));
                                                for (const preset of root.reminderOffsets())
                                                    list.push(itemComp.createObject(reminderMenu, {
                                                                text: preset.label,
                                                                icon: "notifications",
                                                                value: preset.ms
                                                            }));
                                            }
                                            list.push(itemComp.createObject(reminderMenu, {
                                                        text: Tr.tr("Custom time…"),
                                                        icon: "edit_calendar",
                                                        value: -1
                                                    }));
                                            return list;
                                        }
                                        onItemSelected: item => {
                                            reminderMenu.expanded = false;
                                            if (item.value === -1) {
                                                editor.editingField = "new";
                                                return;
                                            }

                                            const at = new Date(Date.parse(row.modelData.deadline) - item.value);
                                            Todo.addReminder(row.modelData.id, at.toISOString());
                                        }

                                        Component {
                                            id: itemComp

                                            MenuItem {}
                                        }
                                    }
                                }

                                Loader {
                                    Layout.fillWidth: true
                                    active: editor.editingField === "new"
                                    visible: active
                                    opacity: active ? 1 : 0

                                    Behavior on opacity {
                                        Anim {
                                            type: Anim.FastEffects
                                        }
                                    }

                                    sourceComponent: ColumnLayout {
                                        // Loader doesn't resize a loaded item to its own width by itself - without
                                        // this, the picker (and the button below it) just take their natural
                                        // width, which can run past the card's edge rather than wrapping to fit it
                                        width: parent.width
                                        spacing: Tokens.spacing.small

                                        DatePicker {
                                            id: newReminderPicker

                                            Layout.fillWidth: true
                                            initial: row.modelData.deadline ? new Date(row.modelData.deadline) : new Date()
                                        }

                                        TextButton {
                                            Layout.alignment: Qt.AlignRight
                                            type: TextButton.Filled
                                            text: Tr.tr("Add reminder")
                                            onClicked: {
                                                Todo.addReminder(row.modelData.id, newReminderPicker.value.toISOString());
                                                editor.editingField = "";
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: addField

                Layout.fillWidth: true
                leadingIcon: "add"
                placeholderText: Tr.tr("Add a task")
                onAccepted: {
                    if (text.trim()) {
                        Todo.addTask(text, root.selectedListId);
                        text = "";
                    }
                }
            }
        }
    }

    // The list at a glance: an arc each for done, overdue and what is left, with the share that
    // is done in the middle. CircularProgress shows a single value against a track, which cannot
    // show three parts of a whole, so the arcs are drawn here instead.
    component TodoRing: Item {
        id: ring

        property int doneCount
        property int overdueCount
        property int todoCount

        readonly property int total: ring.doneCount + ring.overdueCount + ring.todoCount
        readonly property real diameter: Math.min(ring.width, ring.height)
        readonly property real strokeWidth: Math.max(4, Math.round(ring.diameter * 0.1))
        readonly property real radius: (ring.diameter - ring.strokeWidth) / 2 - 1
        // Ends are round, so the gap is sized to hold both caps without them meeting: an arc
        // length of the stroke width plus a couple of pixels, in degrees
        readonly property real gapAngle: ring.radius > 0 ? (ring.strokeWidth + 2) / ring.radius * (180 / Math.PI) : 0
        readonly property real doneAngle: ring.total > 0 ? 360 * ring.doneCount / ring.total : 0
        readonly property real overdueAngle: ring.total > 0 ? 360 * ring.overdueCount / ring.total : 0
        readonly property real todoAngle: ring.total > 0 ? 360 * ring.todoCount / ring.total : 0
        // A gap only where another arc follows, so a part that is the whole list still reads as
        // one unbroken ring
        readonly property real doneGap: ring.overdueAngle > 0 || ring.todoAngle > 0 ? ring.gapAngle : 0
        readonly property real overdueGap: ring.todoAngle > 0 ? ring.gapAngle : 0
        readonly property real todoGap: ring.doneAngle > 0 ? ring.gapAngle : 0

        Shape {
            anchors.fill: parent
            // The default renderer flattens arcs into short straight edges, which is what made
            // the ring look like a low resolution image scaled up; the curve renderer keeps them
            // smooth, and antialiasing keeps the edges from stepping
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            // Empty track, so a list with nothing in it still shows a ring rather than nothing
            ShapePath {
                fillColor: "transparent"
                strokeColor: Colours.palette.m3outlineVariant
                strokeWidth: ring.strokeWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.diameter / 2
                    centerY: ring.diameter / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: ring.doneAngle > 0 ? Colours.palette.m3primary : "transparent"
                strokeWidth: ring.strokeWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.diameter / 2
                    centerY: ring.diameter / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: -90
                    sweepAngle: Math.max(0.1, ring.doneAngle - Math.min(ring.doneGap, ring.doneAngle / 3))
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: ring.overdueAngle > 0 ? Colours.palette.m3error : "transparent"
                strokeWidth: ring.strokeWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.diameter / 2
                    centerY: ring.diameter / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: -90 + ring.doneAngle
                    sweepAngle: Math.max(0.1, ring.overdueAngle - Math.min(ring.overdueGap, ring.overdueAngle / 3))
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: ring.todoAngle > 0 ? Colours.palette.m3onSurfaceVariant : "transparent"
                strokeWidth: ring.strokeWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: ring.diameter / 2
                    centerY: ring.diameter / 2
                    radiusX: ring.radius
                    radiusY: ring.radius
                    startAngle: -90 + ring.doneAngle + ring.overdueAngle
                    sweepAngle: Math.max(0.1, ring.todoAngle - Math.min(ring.todoGap, ring.todoAngle / 3))
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: `${ring.total > 0 ? Math.round(100 * ring.doneCount / ring.total) : 0}%`
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.medium
        }
    }
}
