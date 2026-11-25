pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.misc
import qs.services
import qs.modules.background

// --- Claude limits: how much of the rolling 5-hour window and of the week the signed-in Claude
// account has used, and when each starts over. Bars side by side with the reset countdown, or two
// rings. Read from Claude Code's sign-in by services/ClaudeLimits.qml; clicking refreshes ---
WidgetCard {
    id: root

    readonly property bool rings: root.variant === "rings"

    readonly property string note: {
        if (ClaudeLimits.error === "signed-out")
            return Tr.tr("Sign in to Claude Code to see your limits");
        if (ClaudeLimits.error === "expired")
            return Tr.tr("Sign-in expired. Open Claude Code to renew it");
        if (ClaudeLimits.error !== "" && !ClaudeLimits.loaded)
            return Tr.tr("Couldn't reach Claude. Retrying in a few minutes");
        if (!ClaudeLimits.loaded)
            return Tr.tr("Reading your usage…");
        return "";
    }

    readonly property var windows: [
        {
            name: Tr.tr("5-hour"),
            data: ClaudeLimits.fiveHour
        },
        {
            name: Tr.tr("Weekly"),
            data: ClaudeLimits.weekly
        }
    ]

    // Amber past three quarters, red once it is all but gone
    function colourFor(used: real): color {
        if (used >= 90)
            return Colours.palette.m3error;
        if (used >= 75)
            return Colours.light ? "#b06000" : "#fdd663";
        return Colours.palette.m3primary;
    }

    title: ClaudeLimits.plan ? Tr.tr("Claude %1").arg(ClaudeLimits.planName()) : Tr.tr("Claude limits")
    icon: "data_usage"
    padding: Tokens.padding.largeIncreased

    onClicked: ClaudeLimits.refresh()

    Ref {
        service: ClaudeLimits
    }

    // Bars: one row per window, the label and percentage over a gauge, and the time left under it
    Repeater {
        model: !root.rings && ClaudeLimits.loaded ? root.windows : []

        ColumnLayout {
            id: row

            required property var modelData
            readonly property real used: row.modelData.data?.used ?? 0
            readonly property color colour: root.colourFor(row.used)

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: row.modelData.name
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.builders.medium.weight(Font.Medium).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: row.modelData.data ? Tr.tr("resets in %1").arg(ClaudeLimits.untilLabel(row.modelData.data.resetsAt)) : Tr.tr("No reading")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }

                StyledText {
                    text: `${Math.round(row.used)}%`
                    color: row.used >= 75 ? row.colour : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.builders.medium.weight(Font.DemiBold).build()
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                StyledRect {
                    width: row.used > 0 ? Math.max(height, parent.width * row.used / 100) : 0
                    height: parent.height
                    radius: Tokens.rounding.full
                    color: row.colour

                    Behavior on width {
                        Anim {
                            type: Anim.DefaultSpatial
                        }
                    }
                }
            }
        }
    }

    // Rings: the two windows as circles, the percentage inside and the reset time under each
    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.rings && ClaudeLimits.loaded
        spacing: Tokens.spacing.large

        Repeater {
            model: root.rings && ClaudeLimits.loaded ? root.windows : []

            ColumnLayout {
                id: ring

                required property var modelData
                readonly property real used: ring.modelData.data?.used ?? 0
                readonly property color colour: root.colourFor(ring.used)

                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                CircularProgress {
                    Layout.alignment: Qt.AlignHCenter
                    implicitSize: 84
                    strokeWidth: 8
                    value: ring.used / 100
                    fgColour: ring.colour
                    bgColour: Colours.palette.m3surfaceContainerHighest

                    Behavior on clampedVal {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: `${Math.round(ring.used)}%`
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.builders.small.weight(Font.DemiBold).build()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: ring.modelData.name
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.builders.medium.weight(Font.Medium).build()
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: ring.modelData.data ? Tr.tr("Resets %1").arg(ClaudeLimits.resetLabel(ring.modelData.data.resetsAt)) : Tr.tr("No reading")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // Only in place of the numbers: once there is a reading, a failed refresh keeps showing it
        visible: !ClaudeLimits.loaded
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.Wrap
        text: root.note
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }
}
