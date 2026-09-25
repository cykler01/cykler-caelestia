pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Checks the repository this shell is built from and can pull, rebuild, install and restart it.
PageBase {
    id: root

    // Set when the user pressed Install with uncommitted changes and has to choose what to do with them
    property bool askingAboutChanges

    readonly property bool upToDate: ShellUpdater.checked && ShellUpdater.behind === 0

    title: Tr.tr("Updates")

    Component.onCompleted: ShellUpdater.check()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Status
        SectionHeader {
            first: true
            text: Tr.tr("Status")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: statusRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: statusRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: ShellUpdater.state === "error" ? "error" : ShellUpdater.state === "done" ? "check_circle" : ShellUpdater.busy ? "sync" : root.upToDate ? "check_circle" : ShellUpdater.behind > 0 ? "system_update" : "update"
                    color: ShellUpdater.state === "error" ? Colours.palette.m3error : root.upToDate || ShellUpdater.state === "done" ? Colours.palette.m3tertiary : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.extraLarge
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (ShellUpdater.state === "checking")
                                return Tr.tr("Checking for updates...");
                            if (ShellUpdater.state === "installing")
                                return Tr.tr("Updating...");
                            if (ShellUpdater.state === "done")
                                return Tr.tr("Updated. Restarting the shell...");
                            if (ShellUpdater.state === "error")
                                return Tr.tr("Something went wrong");
                            if (!ShellUpdater.checked)
                                return Tr.tr("Not checked yet");
                            if (ShellUpdater.behind === 0)
                                return Tr.tr("You are up to date");
                            return ShellUpdater.behind === 1 ? Tr.tr("1 update available") : Tr.tr("%1 updates available").arg(ShellUpdater.behind);
                        }
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: ShellUpdater.state === "error" ? ShellUpdater.errorText : ShellUpdater.state === "installing" ? ShellUpdater.currentStep : ShellUpdater.head ? Tr.tr("On %1 at %2, tracking %3").arg(ShellUpdater.localBranch).arg(ShellUpdater.head).arg(ShellUpdater.branch) : ShellUpdater.repoPath
                        color: ShellUpdater.state === "error" ? Colours.palette.m3error : Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.Wrap
                    }
                }

                TextButton {
                    text: Tr.tr("Check")
                    type: TextButton.Tonal
                    disabled: ShellUpdater.busy
                    onClicked: ShellUpdater.check()
                }

                TextButton {
                    text: Tr.tr("Install")
                    type: TextButton.Filled
                    disabled: ShellUpdater.busy || ShellUpdater.state === "done" || ShellUpdater.behind === 0 || !ShellUpdater.checked
                    onClicked: {
                        if (ShellUpdater.dirty)
                            root.askingAboutChanges = true;
                        else
                            ShellUpdater.install(false);
                    }
                }
            }
        }

        // Uncommitted changes: let the user choose
        ConnectedRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            first: true
            last: true
            visible: root.askingAboutChanges && ShellUpdater.dirty && !ShellUpdater.busy
            implicitHeight: visible ? changesColumn.implicitHeight + Tokens.padding.large * 2 : 0
            color: Colours.palette.m3errorContainer

            ColumnLayout {
                id: changesColumn

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("The checkout has uncommitted changes")
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: Tr.tr("They can be stashed while the update is pulled and built, then restored afterwards. If restoring them conflicts with the update they stay in the stash.")
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.label.medium
                }

                RowLayout {
                    spacing: Tokens.spacing.small

                    TextButton {
                        text: Tr.tr("Stash, update and restore")
                        type: TextButton.Filled
                        onClicked: {
                            root.askingAboutChanges = false;
                            ShellUpdater.install(true);
                        }
                    }

                    TextButton {
                        text: Tr.tr("Cancel")
                        type: TextButton.Tonal
                        onClicked: root.askingAboutChanges = false
                    }
                }
            }
        }

        // Warnings from the last install (e.g. stash could not be restored)
        Repeater {
            model: ShellUpdater.warnings

            StyledText {
                required property string modelData

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                wrapMode: Text.Wrap
                text: modelData
                color: Colours.palette.m3error
                font: Tokens.font.label.medium
            }
        }

        // New commits
        SectionHeader {
            visible: ShellUpdater.commits.length > 0
            text: Tr.tr("What's new")
        }

        Repeater {
            model: ShellUpdater.commits

            ConnectedRect {
                id: commitRow

                required property string modelData
                required property int index

                Layout.fillWidth: true
                first: index === 0
                last: index === ShellUpdater.commits.length - 1
                implicitHeight: commitText.implicitHeight + Tokens.padding.medium * 2

                StyledText {
                    id: commitText

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    verticalAlignment: Text.AlignVCenter
                    text: commitRow.modelData
                    font: Tokens.font.body.small
                    elide: Text.ElideRight
                }
            }
        }

        // Progress output while installing
        SectionHeader {
            visible: ShellUpdater.log.length > 0 && ShellUpdater.state !== "idle"
            text: Tr.tr("Output")
        }

        StyledText {
            Layout.fillWidth: true
            visible: ShellUpdater.log.length > 0 && ShellUpdater.state !== "idle"
            text: ShellUpdater.log.join("\n")
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.mono.small
        }

        // Settings
        SectionHeader {
            text: Tr.tr("Repository")
        }

        TextFieldRow {
            first: true
            label: Tr.tr("Checkout location")
            subtext: Tr.tr("The folder the shell was cloned to and built from (empty: ~/Documents/Github/cykler-caelestia)")
            value: GlobalConfig.services.repoPath
            onEditingFinished: v => GlobalConfig.services.repoPath = v.trim()
        }

        TextFieldRow {
            last: true
            label: Tr.tr("Branch")
            subtext: Tr.tr("The origin branch to check and pull")
            value: GlobalConfig.services.updateBranch
            onEditingFinished: v => GlobalConfig.services.updateBranch = v.trim() || "main"
        }
    }
}
