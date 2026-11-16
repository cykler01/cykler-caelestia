pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// NOTE(fork): one entry so far - the scheduling rule that stops ananicy running the shell as a
// background daemon. See services/Scheduling.qml for what it reads and what it runs.
PageBase {
    id: root

    // Only worth showing once the check has actually run
    readonly property bool conflictVisible: Scheduling.checked && Scheduling.conflict !== ""

    // Running fast already, but not because of this rule - something else set it, so it will not
    // survive a restart. Worth saying, rather than calling the shell a background daemon when the
    // priority plainly says otherwise
    readonly property bool fastButUnruled: Scheduling.available && !Scheduling.ruleInstalled && Scheduling.nice <= Scheduling.targetNice

    readonly property string headline: {
        if (!Scheduling.checked)
            return Tr.tr("Checking…");
        if (!Scheduling.available)
            return Tr.tr("Nothing to fix here");
        if (Scheduling.pendingRestart)
            return Tr.tr("Applied, waiting on a restart");
        if (Scheduling.applied)
            return Tr.tr("Applied");
        if (root.fastButUnruled)
            return Tr.tr("Set by something else");
        return Tr.tr("Not applied");
    }

    readonly property string explanation: {
        if (!Scheduling.checked)
            return Tr.tr("Reading the scheduling rules.");
        if (!Scheduling.available)
            return Tr.tr("ananicy is not installed, so nothing is renicing the shell. The shell runs at the priority it was started with.");
        if (Scheduling.pendingRestart)
            return Tr.tr("The rule is in place, but ananicy never revisits a process it has already classified. The shell picks it up the next time it starts, or straight away if you apply it again.");
        if (Scheduling.applied)
            return Tr.tr("The shell is scheduled as a desktop shell rather than a background daemon.");
        if (root.fastButUnruled)
            // TRANSLATORS: %1 = a nice value, e.g. -6
            return Tr.tr("The shell is already running at nice %1, but no rule of ours is in place, so it will go back to whatever ananicy says the next time it starts.").arg(Scheduling.nice);
        return Tr.tr("The shell is being scheduled as a background daemon, so it loses the CPU to ordinary applications and drops frames while scrolling.");
    }

    readonly property string statusIcon: {
        if (!Scheduling.checked)
            return "sync";
        if (!Scheduling.available)
            return "info";
        if (Scheduling.pendingRestart)
            return "restart_alt";
        if (Scheduling.applied)
            return "check_circle";
        if (root.fastButUnruled)
            return "help";
        return "speed";
    }

    readonly property color statusColour: {
        if (!Scheduling.checked || !Scheduling.available)
            return Colours.palette.m3onSurfaceVariant;
        if (Scheduling.applied)
            return Colours.palette.m3tertiary;
        if (Scheduling.pendingRestart || root.fastButUnruled)
            return Colours.palette.m3primary;
        return Colours.palette.m3error;
    }

    title: Tr.tr("Plugins")

    Component.onCompleted: Scheduling.refresh()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Background daemon fix")
        }

        // Status
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: statusRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: root.statusIcon
                    color: root.statusColour
                    fontStyle: Tokens.font.icon.extraLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: root.headline
                        color: root.statusColour
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: root.explanation
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.medium
                    }
                }
            }
        }

        InfoRow {
            label: Tr.tr("Shell priority")
            subtext: Tr.tr("What the running shell is scheduled at now")
            // TRANSLATORS: %1 = a nice value, e.g. -6
            value: Scheduling.checked ? Tr.tr("nice %1").arg(Scheduling.nice) : "…"
        }

        InfoRow {
            label: Tr.tr("Rule file")
            subtext: "/etc/ananicy.d/99-cykler-caelestia.rules"
            value: Scheduling.ruleInstalled ? Tr.tr("Installed") : Tr.tr("Not installed")
        }

        InfoRow {
            last: !root.conflictVisible
            label: Tr.tr("Scheduler")
            subtext: Tr.tr("The daemon that applies the rule")
            value: Scheduling.available ? (Scheduling.serviceActive ? Scheduling.service : Tr.tr("%1 (stopped)").arg(Scheduling.service)) : Tr.tr("None")
        }

        // Another rule naming "qs" would fight ours, and ananicy does not define which wins
        InfoRow {
            last: true
            visible: root.conflictVisible
            label: Tr.tr("Conflicting rule")
            subtext: Scheduling.conflict
            value: Tr.tr("May win")
            icon: "warning"
            iconColour: Colours.palette.m3error
        }

        // Actions
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            TextButton {
                text: Scheduling.pendingRestart ? Tr.tr("Apply again") : Tr.tr("Apply the fix")
                type: TextButton.Filled
                disabled: Scheduling.busy || !Scheduling.available || Scheduling.applied
                onClicked: Scheduling.apply()
            }

            TextButton {
                text: Tr.tr("Remove")
                type: TextButton.Tonal
                disabled: Scheduling.busy || !Scheduling.ruleInstalled
                onClicked: Scheduling.remove()
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                visible: Scheduling.busy
                text: Tr.tr("Working…")
                color: Colours.palette.m3outline
                font: Tokens.font.label.medium
            }
        }

        // Error
        ConnectedRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            first: true
            last: true
            visible: Scheduling.errorText !== ""
            implicitHeight: visible ? errorText.implicitHeight + Tokens.padding.large * 2 : 0
            color: Colours.palette.m3errorContainer

            StyledText {
                id: errorText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large

                wrapMode: Text.Wrap
                text: Scheduling.errorText
                color: Colours.palette.m3onErrorContainer
                font: Tokens.font.label.medium
            }
        }

        SectionHeader {
            text: Tr.tr("What it changes")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: aboutColumn.implicitHeight + Tokens.padding.large * 2

            ColumnLayout {
                id: aboutColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Tokens.padding.large

                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: Tr.tr("The stock ananicy rulesets classify the quickshell binary as a background service and give it nice 10. That is a fair call where quickshell only draws a bar. Here it is the whole desktop shell, so it loses wakeup latency to every ordinary application and misses frames while scrolling or opening a panel.")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    // TRANSLATORS: %1 = a nice value, e.g. -6
                    text: Tr.tr("This writes a rule that asks for nice %1 instead, the same as plasmashell gets in those rulesets, and renices the running shell so the change lands without a restart.").arg(Scheduling.targetNice)
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                }
            }
        }
    }
}
