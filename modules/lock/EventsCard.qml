pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.misc
import qs.components.widgets
import qs.services

// What is coming up from GNOME Calendar, the next few events under a heading for each day. Sized
// to its content like the battery and network cards. Nothing here opens anything: the screen is
// locked, and GNOME Calendar would only start behind it
StyledRect {
    id: root

    // Enough to read the day ahead without the card taking over its column
    readonly property int rows: 4
    readonly property var groups: CalendarEvents.grouped(rows)

    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    Ref {
        service: CalendarEvents
    }

    ColumnLayout {
        id: col

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "event"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.small
            }

            StyledText {
                Layout.fillWidth: true
                text: Tr.tr("Coming up")
                elide: Text.ElideRight
                color: Colours.palette.m3primary
                font: Tokens.font.title.small
            }

            // How many are on today, the one figure worth having before unlocking
            StyledText {
                visible: CalendarEvents.ready && CalendarEvents.today.length > 0
                text: Tr.trN("%n today", "%n today", CalendarEvents.today.length)
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.label.medium
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: !CalendarEvents.ready || root.groups.length === 0
            wrapMode: Text.Wrap
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
            text: {
                if (!CalendarEvents.available)
                    return Tr.tr("GNOME Calendar's events are not available");
                if (!CalendarEvents.enabled)
                    return Tr.tr("Calendar events are turned off");
                if (!CalendarEvents.loaded)
                    return Tr.tr("Reading your calendars…");
                return Tr.tr("Nothing coming up");
            }
        }

        Repeater {
            model: CalendarEvents.ready ? root.groups : []

            ColumnLayout {
                id: group

                required property var modelData

                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.leftMargin: Tokens.padding.small
                    text: CalendarEvents.dayLabel(group.modelData.day)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.builders.small.weight(Font.Medium).build()
                }

                Repeater {
                    model: group.modelData.events

                    EventRow {
                        required property var modelData

                        Layout.fillWidth: true
                        event: modelData
                        day: group.modelData.day
                        relative: true
                        interactive: false
                    }
                }
            }
        }
    }
}
