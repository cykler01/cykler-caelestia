pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

// NOTE(fork): alarms - a time of day rather than a length (see services/Alarms.qml). A row per
// alarm, carrying only its time and its switch until it is tapped: the days it repeats on and the
// button that throws it away are folded away inside the row, and open out when it is.
Item {
    id: root

    // Which row is open, if any. One at a time, so the list stays a list
    property string openId: ""

    // Monday first, in the numbers JavaScript counts weekdays with
    readonly property var weekOrder: [1, 2, 3, 4, 5, 6, 0]

    // The narrow single-letter name of a weekday, from the locale rather than a list written here
    function dayLetter(day: int): string {
        return Qt.locale().standaloneDayName(day, Locale.NarrowFormat);
    }

    function toggleOpen(id: string): void {
        root.openId = root.openId === id ? "" : id;
    }

    ColumnLayout {
        anchors.fill: parent

        spacing: Tokens.spacing.medium

        // The one that is going off, over everything else until it is dealt with
        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small

            implicitHeight: ringingLayout.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.large
            color: Colours.palette.m3errorContainer
            scale: Alarms.ringing ? 1 : 0.9
            opacity: Alarms.ringing ? 1 : 0
            visible: opacity > 0.01
            Layout.preferredHeight: Alarms.ringing ? implicitHeight : 0

            Behavior on scale {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on Layout.preferredHeight {
                Anim {
                    type: Anim.DefaultSpatial
                }
            }

            ColumnLayout {
                id: ringingLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.large
                anchors.rightMargin: Tokens.padding.large

                spacing: Tokens.spacing.small

                RowLayout {
                    Layout.fillWidth: true

                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "alarm"
                        color: Colours.palette.m3onErrorContainer
                        fontStyle: Tokens.font.icon.medium
                    }

                    StyledText {
                        Layout.fillWidth: true

                        text: Alarms.ringingAlarm ? (Alarms.ringingAlarm.label || Alarms.timeText(Alarms.ringingAlarm)) : ""
                        color: Colours.palette.m3onErrorContainer
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: Tokens.spacing.small

                    TextButton {
                        Layout.fillWidth: true

                        // TRANSLATORS: %1 = a number of minutes
                        text: Tr.tr("Snooze %1 min").arg(Alarms.snoozeMinutes)
                        type: TextButton.Tonal
                        onClicked: Alarms.snooze()
                    }

                    TextButton {
                        Layout.fillWidth: true

                        text: Tr.tr("Dismiss")
                        type: TextButton.Filled
                        onClicked: Alarms.dismiss()
                    }
                }
            }
        }

        // What is coming, which is the one thing worth saying before the list itself
        StyledText {
            Layout.fillWidth: true

            horizontalAlignment: Text.AlignHCenter
            // How long is left is worked out from the clock, which nothing here would otherwise
            // notice moving, so the minute is read as well to give the binding something to follow
            text: Alarms.nextAlarm ? Tr.tr("Next at %1 · %2").arg(Alarms.timeText(Alarms.nextAlarm)).arg(Alarms.untilText(Alarms.nextAlarm.nextAt, Time.minutes)) : Alarms.alarms.length > 0 ? Tr.tr("All alarms are off") : Tr.tr("No alarms yet")
            animate: true
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.medium
            wrapMode: Text.WordWrap
        }

        VerticalFadeListView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            spacing: Tokens.spacing.extraSmall
            model: Alarms.alarms

            delegate: AlarmRow {}
        }

        IconTextButton {
            Layout.fillWidth: true

            icon: "add_alarm"
            text: Tr.tr("Add alarm")
            type: IconTextButton.Tonal
            isRound: true
            shapeMorph: true
            verticalPadding: Tokens.padding.medium
            onClicked: root.openId = Alarms.add()
        }
    }

    component AlarmRow: StyledRect {
        id: row

        required property var modelData

        readonly property bool open: root.openId === row.modelData.id
        readonly property bool isNext: Alarms.nextAlarm?.id === row.modelData.id

        anchors.left: ListView.view?.contentItem?.left ?? undefined
        anchors.right: ListView.view?.contentItem?.right ?? undefined

        implicitHeight: (row.open ? openLayout.implicitHeight : headRow.implicitHeight) + Tokens.padding.medium * 2
        radius: Tokens.rounding.large
        color: row.isNext && row.modelData.enabled ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh
        clip: true

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        // Tapping anywhere that is not the switch or a day opens the row out
        StateLayer {
            radius: parent.radius

            onClicked: root.toggleOpen(row.modelData.id)
        }

        ColumnLayout {
            id: openLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Tokens.padding.large
            anchors.rightMargin: Tokens.padding.medium
            anchors.topMargin: Tokens.padding.medium

            spacing: Tokens.spacing.small

            RowLayout {
                id: headRow

                Layout.fillWidth: true

                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 0

                    StyledText {
                        opacity: timeEntry.activeFocus ? 0 : 1
                        text: Alarms.timeText(row.modelData)
                        color: row.modelData.enabled ? Colours.palette.m3onSurface : Colours.palette.m3outline
                        font: Tokens.font.clock.size(Tokens.font.title.small.pointSize).weight(Font.Bold).build()
                    }

                    StyledText {
                        Layout.fillWidth: true

                        visible: text !== ""
                        text: row.modelData.label || (row.modelData.days.length > 0 ? row.modelData.days.length === 7 ? Tr.tr("Every day") : row.modelData.days.map(d => root.dayLetter(d)).join(" ") : Tr.tr("Once"))
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                StyledSwitch {
                    checked: row.modelData.enabled
                    onToggled: Alarms.setEnabled(row.modelData.id, checked)
                }
            }

            // Folded away until the row is open
            ColumnLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Tokens.padding.medium

                opacity: row.open ? 1 : 0
                visible: opacity > 0.01
                spacing: Tokens.spacing.small

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.weekOrder

                        StyledRect {
                            id: day

                            required property int modelData

                            readonly property bool on: row.modelData.days.includes(day.modelData)

                            Layout.fillWidth: true

                            implicitHeight: dayLabel.implicitHeight + Tokens.padding.small
                            radius: Tokens.rounding.full
                            color: day.on ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                            StateLayer {
                                radius: parent.radius
                                color: day.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface

                                onClicked: Alarms.toggleDay(row.modelData.id, day.modelData)
                            }

                            StyledText {
                                id: dayLabel

                                anchors.centerIn: parent

                                text: root.dayLetter(day.modelData)
                                color: day.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: Tokens.spacing.small

                    StyledTextField {
                        id: timeEntry

                        Layout.preferredWidth: 90

                        placeholderText: Tr.trCtx("Time", "an alarm's time of day")
                        type: StyledTextField.Filled
                        verticalPadding: Tokens.padding.small
                        validator: RegularExpressionValidator {
                            regularExpression: /[0-9:]{0,5}/
                        }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                text = `${row.modelData.hour}:${row.modelData.minute.toString().padStart(2, "0")}`;
                                selectAll();
                            } else {
                                const parsed = Alarms.parseTime(text);
                                if (parsed)
                                    Alarms.setTime(row.modelData.id, parsed.hour, parsed.minute);
                            }
                        }

                        onAccepted: timeEntry.focus = false
                    }

                    StyledTextField {
                        id: labelEntry

                        Layout.fillWidth: true

                        placeholderText: Tr.trCtx("Label", "an alarm's name")
                        type: StyledTextField.Filled
                        verticalPadding: Tokens.padding.small
                        text: row.modelData.label

                        onEditingFinished: Alarms.setLabel(row.modelData.id, labelEntry.text)
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: Alarms.remove(row.modelData.id)
                    }
                }
            }
        }
    }
}
