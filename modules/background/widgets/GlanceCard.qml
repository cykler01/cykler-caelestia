pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.background
import qs.modules.launcher.services

// --- At a glance: the date, the weather and the next thing coming up, either as one line or as a
// small card with a greeting ---
WidgetCard {
    id: root

    readonly property bool line: root.variant !== "card"
    readonly property date now: Time.date

    // The same four parts of the day, and the same custom wording, as the lock screen's greeting
    readonly property string period: {
        const h = Time.hours;
        if (h >= 5 && h < 12)
            return "morning";
        if (h >= 12 && h < 17)
            return "afternoon";
        if (h >= 17 && h < 21)
            return "evening";
        return "night";
    }
    readonly property string greeting: LockGreeting.textFor(root.period) || ({
            morning: Tr.tr("Good morning"),
            afternoon: Tr.tr("Good afternoon"),
            evening: Tr.tr("Good evening"),
            night: Tr.tr("Good night")
        })[root.period]

    // The one thing most worth knowing about next, as an icon and a line of text. Something already
    // under way - a countdown, or a stopwatch left running - comes before anything scheduled; of
    // the scheduled things, whichever of the next alarm and the next task deadline is sooner
    readonly property var next: {
        void Todo.revision;
        const nowMs = root.now.getTime();

        if (CountdownTimer.finished)
            return {
                icon: "timer",
                text: Tr.tr("Timer finished"),
                urgent: true
            };
        if (CountdownTimer.active)
            return {
                icon: "timer",
                text: CountdownTimer.running ? Tr.tr("Timer · %1 left").arg(CountdownTimer.display) : Tr.tr("Timer paused · %1 left").arg(CountdownTimer.display),
                urgent: false
            };
        if (Stopwatch.running)
            return {
                icon: "avg_pace",
                text: Tr.tr("Stopwatch running"),
                urgent: false
            };

        const alarm = Alarms.nextAlarm;
        const task = Todo.tasks.filter(t => !t.done && t.deadline && new Date(t.deadline).getTime() >= nowMs).sort((a, b) => new Date(a.deadline) - new Date(b.deadline))[0];

        if (alarm && (!task || alarm.nextAt <= new Date(task.deadline).getTime()))
            return {
                icon: "alarm",
                text: `${alarm.label || Tr.tr("Alarm")} · ${Alarms.timeText(alarm)}, ${Alarms.untilText(alarm.nextAt, Time.minutes)}`,
                urgent: false
            };
        if (task)
            return {
                icon: "task_alt",
                text: `${task.text} · ${root.whenText(new Date(task.deadline))}`,
                urgent: false
            };
        return {
            icon: "check_circle",
            text: Tr.tr("Nothing coming up"),
            urgent: false
        };
    }

    // "today 15:00", "tomorrow", "Thu 19"
    function whenText(d: date): string {
        const today = new Date(root.now.getFullYear(), root.now.getMonth(), root.now.getDate());
        const diff = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
        const timed = d.getHours() !== 0 || d.getMinutes() !== 0;
        const time = Qt.formatTime(d, Units.twelveHourClock ? "h:mm AP" : "HH:mm");
        if (diff === 0)
            return timed ? Tr.tr("today %1").arg(time) : Tr.tr("today");
        if (diff === 1)
            return timed ? Tr.tr("tomorrow %1").arg(time) : Tr.tr("tomorrow");
        return Qt.formatDate(d, "ddd d");
    }

    title: ""
    icon: "today"
    // A little tighter than other cards: both styles are short, and the text wants the height
    padding: Tokens.padding.large

    // The card is created again each time the desktop is uncovered, so only fetch when there is nothing to show
    Component.onCompleted: {
        if (!Weather.cc)
            Weather.reload();
    }

    // Line: date, weather and what's next, one after the other
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.line
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.medium

            StyledText {
                text: Qt.formatDate(root.now, "ddd d MMM")
                color: Colours.palette.m3onSurface
                font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
            }

            Divider {}

            RowLayout {
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: Weather.icon
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.medium
                }

                StyledText {
                    text: Weather.temp
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.small
                }
            }

            Divider {}

            NextUp {
                Layout.fillWidth: true
            }
        }
    }

    // Card: a greeting with the date under it and what's next under that, the weather to the right
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: !root.line
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.large

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: SysInfo.user ? `${root.greeting}, ${SysInfo.user}` : root.greeting
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: Qt.formatDate(root.now, "dddd d MMMM")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledRect {
                    Layout.maximumWidth: parent.width
                    implicitWidth: nextChip.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: nextChip.implicitHeight + Tokens.padding.extraSmall * 2
                    radius: Tokens.rounding.full
                    color: root.next.urgent ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer

                    NextUp {
                        id: nextChip

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.rightMargin: Tokens.padding.medium
                        onContainer: true
                    }
                }
            }

            ColumnLayout {
                spacing: 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.icon
                    color: Colours.palette.m3secondary
                    fontStyle: Tokens.font.icon.extraLarge
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Weather.temp
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                }
            }
        }
    }

component Divider: StyledRect {
    implicitWidth: Tokens.padding.extraSmall
    implicitHeight: Tokens.padding.extraSmall
    radius: Tokens.rounding.full
    color: Colours.palette.m3outline
}

component NextUp: RowLayout {
    id: nextUp

    // Drawn on the card's chip rather than on the card itself, which changes the colours it needs
    property bool onContainer

    readonly property color tint: root.next.urgent ? (nextUp.onContainer ? Colours.palette.m3onErrorContainer : Colours.palette.m3error) : nextUp.onContainer ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3primary

    spacing: Tokens.spacing.extraSmall

    MaterialIcon {
        text: root.next.icon
        color: nextUp.tint
        fontStyle: Tokens.font.icon.small
    }

    StyledText {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        elide: Text.ElideRight
        text: root.next.text
        color: nextUp.onContainer ? nextUp.tint : Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }
}
}
