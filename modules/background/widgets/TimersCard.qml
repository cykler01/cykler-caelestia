pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.background

// --- Timers & alarms: the shell's countdown as a ring, the stopwatch with its laps, or the next
// alarm with a switch for it. All three drive the same services as the timer panel, so a timer
// started here shows in the bar and the panel, and keeps going when the desktop is covered ---
WidgetCard {
    id: root

    readonly property string style: root.variant === "" ? "countdown" : root.variant

    // The alarm the card is about: the one ringing, else the next one due, else the earliest in the
    // day of those switched off, so there is still a switch to turn one back on with
    readonly property var alarm: {
        if (Alarms.ringingAlarm)
            return Alarms.ringingAlarm;
        if (Alarms.nextAlarm)
            return Alarms.nextAlarm;
        const all = [...Alarms.alarms].sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
        return all[0] ?? null;
    }

    title: ""
    icon: "timer"

    // Countdown: a ring of what is left, with start and pause under it, and a few lengths to start
    // straight away while nothing is running
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.style === "countdown"
        visible: active

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.medium

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CircularProgress {
                    id: ring

                    anchors.centerIn: parent
                    implicitSize: Math.min(parent.width, parent.height)
                    strokeWidth: Tokens.padding.small
                    // Full while idle, so the ring reads as "this much" rather than as empty
                    value: CountdownTimer.active ? 1 - CountdownTimer.progress : 1
                    fgColour: CountdownTimer.finished ? Colours.palette.m3error : CountdownTimer.running ? Colours.palette.m3primary : Colours.palette.m3secondary
                    bgColour: Colours.palette.m3surfaceContainerHighest
                    // A gentle wave while it counts down, which is the shell's way of saying "live"
                    wavy: CountdownTimer.running && PowerSaving.animations
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: CountdownTimer.finished ? "0:00" : CountdownTimer.active ? CountdownTimer.display : CountdownTimer.durationDisplay
                        color: CountdownTimer.finished ? Colours.palette.m3error : Colours.palette.m3onSurface
                        font: Tokens.font.clock.size(Math.round(Tokens.font.headline.medium.pointSize * (CountdownTimer.remaining >= 3600 ? 0.75 : 1))).weight(Font.DemiBold).build()
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            if (CountdownTimer.finished)
                                return Tr.tr("Time's up");
                            if (CountdownTimer.running)
                                return Tr.tr("Ends %1").arg(Qt.formatTime(new Date(CountdownTimer.endAt), Units.twelveHourClock ? "h:mm AP" : "HH:mm"));
                            if (CountdownTimer.active)
                                return Tr.tr("Paused");
                            return Tr.tr("Timer");
                        }
                        color: CountdownTimer.finished ? Colours.palette.m3error : Colours.palette.m3outline
                        font: Tokens.font.label.medium
                    }
                }
            }

            // Idle: a few lengths that start as soon as they are picked, and play for the one set
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: !CountdownTimer.active
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: [1, 5, 10]

                    TextButton {
                        required property int modelData

                        // TRANSLATORS: a quick-start timer length in minutes, e.g. "5m"
                        text: Tr.tr("%1m").arg(modelData)
                        type: TextButton.Tonal
                        horizontalPadding: Tokens.padding.small
                        onClicked: CountdownTimer.start(modelData * 60)
                    }
                }

                IconButton {
                    icon: "play_arrow"
                    type: IconButton.Filled
                    onClicked: CountdownTimer.start(0)
                }
            }

            // Running, paused or rung: start over, and pause or carry on
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                visible: CountdownTimer.active
                spacing: Tokens.spacing.small

                IconButton {
                    icon: CountdownTimer.finished ? "close" : "restart_alt"
                    type: IconButton.Tonal
                    onClicked: CountdownTimer.finished ? CountdownTimer.dismiss() : CountdownTimer.reset()
                }

                IconButton {
                    icon: CountdownTimer.finished ? "replay" : CountdownTimer.running ? "pause" : "play_arrow"
                    type: IconButton.Filled
                    onClicked: CountdownTimer.toggle()
                }
            }
        }
    }

    // Stopwatch: the reading and its buttons on the left, the last few laps on the right
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.style === "stopwatch"
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                // Hundredths only while animations are on: with them off the reading is redrawn
                // once a second like everything else
                RowLayout {
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: "timer"
                        fill: Stopwatch.running ? 1 : 0
                        color: Stopwatch.running ? Colours.palette.m3primary : Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.small
                    }

                    StyledText {
                        text: Stopwatch.running ? Tr.tr("Running") : Stopwatch.active ? Tr.tr("Paused") : Tr.tr("Stopwatch")
                        color: Stopwatch.running ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    verticalAlignment: Text.AlignVCenter
                    // Shrinks to fit rather than cutting off, for a run that has gone past the hour
                    fontSizeMode: Text.HorizontalFit
                    minimumPointSize: Tokens.font.label.small.pointSize
                    text: PowerSaving.animations ? Stopwatch.display : Stopwatch.shortDisplay
                    color: Stopwatch.running ? Colours.palette.m3onSurface : Stopwatch.active ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3outline
                    font: Tokens.font.clock.size(Math.round(Tokens.font.headline.medium.pointSize * 1.3)).weight(Font.DemiBold).build()
                }

                RowLayout {
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: Stopwatch.running ? "pause" : "play_arrow"
                        type: IconButton.Filled
                        onClicked: Stopwatch.toggle()
                    }

                    IconButton {
                        icon: "flag"
                        type: IconButton.Tonal
                        disabled: !Stopwatch.running
                        onClicked: Stopwatch.lap()
                    }

                    IconButton {
                        icon: "restart_alt"
                        type: IconButton.Text
                        disabled: !Stopwatch.active || Stopwatch.running
                        onClicked: Stopwatch.reset()
                    }
                }
            }

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: lapsCol.implicitWidth + Tokens.padding.small * 2
                Layout.minimumWidth: parent.width * 0.38
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainerHigh

                ColumnLayout {
                    id: lapsCol

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Tokens.padding.small
                    visible: Stopwatch.laps.length > 0
                    spacing: 2

                    Repeater {
                        // Newest first, as many as fit
                        model: Stopwatch.laps.slice(0, 4)

                        RowLayout {
                            id: lapRow

                            required property var modelData

                            readonly property color tint: lapRow.modelData.index === Stopwatch.fastestLap ? Colours.palette.m3primary : lapRow.modelData.index === Stopwatch.slowestLap ? Colours.palette.m3error : Colours.palette.m3onSurface

                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            StyledText {
                                text: Tr.tr("Lap %1").arg(lapRow.modelData.index)
                                color: Colours.palette.m3outline
                                font: Tokens.font.label.small
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: Stopwatch.format(lapRow.modelData.split)
                                color: lapRow.tint
                                font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: Stopwatch.laps.length === 0
                    text: Tr.tr("No laps yet")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }
    }

    // Alarm: the next one due with how long until it goes, and a switch for it. Snooze and dismiss
    // take the switch's place while it rings
    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.style === "alarm"
        visible: active

        sourceComponent: RowLayout {
            spacing: Tokens.spacing.medium

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: height
                radius: Tokens.rounding.full
                color: Alarms.ringing ? Colours.palette.m3errorContainer : root.alarm?.enabled ? Colours.palette.m3tertiaryContainer : Colours.palette.m3surfaceContainerHigh

                MaterialIcon {
                    anchors.centerIn: parent
                    text: !root.alarm ? "alarm_add" : Alarms.ringing ? "alarm_on" : root.alarm.enabled ? "alarm" : "alarm_off"
                    fill: root.alarm?.enabled ? 1 : 0
                    color: Alarms.ringing ? Colours.palette.m3onErrorContainer : root.alarm?.enabled ? Colours.palette.m3onTertiaryContainer : Colours.palette.m3outline
                    fontStyle: Tokens.font.icon.large
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: root.alarm ? Alarms.timeText(root.alarm) : Tr.tr("No alarms")
                    color: root.alarm?.enabled || !root.alarm ? Colours.palette.m3onSurface : Colours.palette.m3outline
                    font: root.alarm ? Tokens.font.clock.size(Tokens.font.headline.medium.pointSize).weight(Font.DemiBold).build() : Tokens.font.title.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        if (!root.alarm)
                            return Tr.tr("Add one for the next hour");
                        if (Alarms.ringing)
                            return root.alarm.label || Tr.tr("Ringing");
                        const when = root.alarm.enabled ? Alarms.untilText(root.alarm.nextAt, Time.minutes) : Tr.tr("Off");
                        return root.alarm.label ? `${when} · ${root.alarm.label}` : when;
                    }
                    color: Alarms.ringing ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }

            StyledSwitch {
                visible: !!root.alarm && !Alarms.ringing
                checked: root.alarm?.enabled ?? false
                onToggled: Alarms.setEnabled(root.alarm.id, checked)
            }

            IconButton {
                visible: !root.alarm
                icon: "add"
                type: IconButton.Tonal
                onClicked: Alarms.add()
            }

            TextButton {
                visible: Alarms.ringing
                text: Tr.tr("Snooze")
                type: TextButton.Tonal
                onClicked: Alarms.snooze()
            }

            IconButton {
                visible: Alarms.ringing
                icon: "alarm_off"
                type: IconButton.Filled
                onClicked: Alarms.dismiss()
            }
        }
    }
}
