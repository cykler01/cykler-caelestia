pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.background

// --- Progress: custom milestones as wide bars, rings, or a compact list ---
WidgetCard {
    id: progress

    readonly property string style: progress.variant === "rings" ? "rings" : progress.variant === "compact" ? "compact" : "bars"
    readonly property bool rings: progress.style === "rings"
    readonly property bool compact: progress.style === "compact"
    // The card is unloaded while windows cover the desktop, so it takes the time again when it
    // comes back instead of trusting a tick that happened before it went away.
    property double now: Date.now()
    readonly property var items: Milestones.evaluate(progress.now)
    readonly property bool empty: progress.items.length === 0
    readonly property string message: {
        if (progress.items.length > 0)
            return "";
        return Milestones.hasEntries ? Tr.tr("Check the milestone dates in Settings") : Tr.tr("Add a milestone in Settings");
    }

    title: Tr.tr("Progress")
    icon: "hourglass_top"

    StyledText {
        Layout.fillWidth: true
        visible: progress.message !== ""
        wrapMode: Text.Wrap
        text: progress.message
        color: Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: !progress.rings && !progress.compact && !progress.empty
        spacing: Tokens.spacing.medium

        Repeater {
            // Keyed to the configured entries rather than the per-tick evaluation, so changing the
            // time updates the values in place instead of recreating every row at zero.
            model: Milestones.entries

            ColumnLayout {
                id: milestone

                required property var modelData
                readonly property var info: Milestones.resolve(milestone.modelData, progress.now)

                visible: milestone.info !== null
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 38
                spacing: Tokens.spacing.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        text: milestone.info?.label ?? ""
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        text: milestone.info?.status ?? ""
                        color: milestone.info?.done ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }

                StyledProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    Layout.minimumHeight: 6
                    from: 0
                    to: 1
                    value: milestone.info?.fraction ?? 0
                    fgColour: milestone.info?.done ? Colours.palette.m3tertiary : Colours.palette.m3primary
                    bgColour: Colours.palette.m3surfaceContainerHighest

                    Behavior on value {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        elide: Text.ElideRight
                        text: milestone.info?.target ?? ""
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        text: `${milestone.info?.percent ?? 0}%`
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: progress.rings && !progress.empty
        columns: progress.items.length <= 1 ? 1 : 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small

        Repeater {
            model: Milestones.entries

            ColumnLayout {
                id: ring

                required property var modelData
                readonly property var info: Milestones.resolve(ring.modelData, progress.now)

                visible: ring.info !== null
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                spacing: Tokens.spacing.extraSmall

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 40

                    CircularProgress {
                        anchors.centerIn: parent
                        implicitSize: Math.max(24, Math.min(parent.width, parent.height))
                        strokeWidth: 7
                        value: ring.info?.fraction ?? 0
                        fgColour: ring.info?.done ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        bgColour: Colours.palette.m3surfaceContainerHighest

                        Behavior on clampedVal {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            text: `${ring.info?.percent ?? 0}%`
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.label.medium
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: ring.info?.label ?? ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: ring.info?.status ?? ""
                    color: ring.info?.done ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: progress.compact && !progress.empty
        spacing: Tokens.spacing.extraSmall

        Repeater {
            model: Milestones.entries

            RowLayout {
                id: compactRow

                required property var modelData
                readonly property var info: Milestones.resolve(compactRow.modelData, progress.now)

                visible: compactRow.info !== null
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 28
                spacing: Tokens.spacing.small

                Item {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26

                    CircularProgress {
                        anchors.fill: parent
                        implicitSize: 26
                        strokeWidth: 3
                        value: compactRow.info?.fraction ?? 0
                        fgColour: compactRow.info?.done ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        bgColour: Colours.palette.m3surfaceContainerHighest

                        Behavior on clampedVal {
                            Anim {
                                type: Anim.FastEffects
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: compactRow.info?.label ?? ""
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: compactRow.info?.status ?? ""
                        color: compactRow.info?.done ? Colours.palette.m3tertiary : Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }
                }

                StyledText {
                    text: `${compactRow.info?.percent ?? 0}%`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: progress.now = Date.now()
    }
}
