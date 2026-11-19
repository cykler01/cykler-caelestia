pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.misc
import qs.components.widgets
import qs.services

// The home page's events card: what is coming up from GNOME Calendar, a heading for each day.
// It takes whatever height its row or column gives it and lists as many as fit there, rather
// than setting a height of its own
Item {
    id: root

    // More than any card is tall enough for; the rest are clipped off the bottom
    readonly property var groups: CalendarEvents.grouped(12)

    anchors.fill: parent
    anchors.margins: Tokens.padding.large

    Ref {
        service: CalendarEvents
    }

    ColumnLayout {
        anchors.fill: parent
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

            IconButton {
                icon: "open_in_new"
                type: IconButton.Text
                isRound: true
                padding: Tokens.padding.extraSmall
                font: Tokens.font.icon.small
                onClicked: CalendarEvents.openApp()
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
                    return Tr.tr("Install evolution-data-server to see your GNOME Calendar events");
                if (!CalendarEvents.enabled)
                    return Tr.tr("Calendar events are turned off in the dashboard settings");
                if (!CalendarEvents.loaded)
                    return Tr.tr("Reading your calendars…");
                return Tr.tr("Nothing in the next %1 days").arg(CalendarEvents.lookahead);
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: CalendarEvents.ready ? root.groups : []

                    ColumnLayout {
                        id: group

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.topMargin: index > 0 ? Tokens.spacing.small : 0
                        spacing: 0

                        StyledText {
                            Layout.leftMargin: Tokens.padding.small
                            text: CalendarEvents.dayLabel(group.modelData.day)
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.label.builders.medium.weight(Font.Medium).build()
                        }

                        Repeater {
                            model: group.modelData.events

                            EventRow {
                                required property var modelData

                                Layout.fillWidth: true
                                event: modelData
                                day: group.modelData.day
                                relative: true
                            }
                        }
                    }
                }
            }
        }
    }
}
