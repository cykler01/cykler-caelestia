pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

// Checks the repository this shell is built from and can pull, rebuild, install and restart it,
// plus manages CachyOS, Hyprland, Caelestia, and Btrfs/Git restore points.
PageBase {
    id: root

    // Set when the user pressed Install with uncommitted changes and has to choose what to do with them
    property bool askingAboutChanges
    // Set when the user clicked a restore point so rollback requires explicit confirmation
    property var pendingRollback: null

    readonly property bool upToDate: ShellUpdater.checked && ShellUpdater.behind === 0

    // The backend reports commit dates as ISO strings; show them as a plain local date
    function formatDate(iso: string): string {
        if (!iso)
            return "";

        const date = new Date(iso);
        if (isNaN(date.getTime()))
            return "";

        return date.toLocaleDateString(Qt.locale(), "d MMM yyyy");
    }

    // NOTE(fork): a few paths on one line, with a count standing in for however many are left
    function fileList(files: list<string>): string {
        const shown = files.slice(0, 4);
        const rest = files.length - shown.length;
        if (rest > 0)
            // TRANSLATORS: %1 = a list of file paths, %2 = how many further files there are
            return Tr.tr("%1 and %2 more").arg(shown.join(", ")).arg(rest);
        return shown.join(", ");
    }

    title: Tr.tr("Updates")

    Component.onCompleted: {
        ShellUpdater.check();
        ShellUpdater.fetchBranches();
        SystemUpdater.check();
    }

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
                            ShellUpdater.install("no");
                    }
                }
            }
        }

        // How old this build is next to the newest update on the tracked branch
        SectionHeader {
            text: Tr.tr("Update dates")
        }

        InfoRow {
            first: true
            label: Tr.tr("Current update")
            subtext: Tr.tr("The commit this build is on")
            value: root.formatDate(ShellUpdater.currentDate) || "…"
        }

        InfoRow {
            last: true
            label: Tr.tr("Most recent update")
            subtext: Tr.tr("The newest commit on %1").arg(ShellUpdater.branch)
            value: root.formatDate(ShellUpdater.latestDate) || "…"
        }

        // --- SYSTEM & ECOSYSTEM UPDATES ---
        SectionHeader {
            text: Tr.tr("System & Ecosystem")
        }

        ConnectedRect {
            first: true
            Layout.fillWidth: true
            implicitHeight: allRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: allRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                MaterialIcon {
                    text: SystemUpdater.state === "error" ? "error" : SystemUpdater.busy ? "sync" : "system_update_alt"
                    color: SystemUpdater.state === "error" ? Colours.palette.m3error : Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: {
                            if (SystemUpdater.busy)
                                return SystemUpdater.currentStep || Tr.tr("Working...");
                            if (SystemUpdater.state === "error")
                                return SystemUpdater.canCheck ? Tr.tr("System update failed") : Tr.tr("Cannot check system updates");
                            if (!SystemUpdater.checked)
                                return Tr.tr("Not checked yet");
                            if (SystemUpdater.totalUpdates > 0)
                                return SystemUpdater.totalUpdates === 1 ? Tr.tr("1 system update available") : Tr.tr("%1 system updates available").arg(SystemUpdater.totalUpdates);
                            return Tr.tr("System & ecosystem up to date");
                        }
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: SystemUpdater.errorText || SystemUpdater.warningText || Tr.tr("CachyOS packages, Hyprland ecosystem & Caelestia CLI")
                        color: SystemUpdater.state === "error" || SystemUpdater.errorText ? Colours.palette.m3error : Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.Wrap
                    }
                }

                TextButton {
                    text: Tr.tr("Refresh")
                    type: TextButton.Tonal
                    disabled: SystemUpdater.busy
                    onClicked: SystemUpdater.check()
                }

                TextButton {
                    text: Tr.tr("Update All")
                    type: TextButton.Filled
                    disabled: SystemUpdater.busy || SystemUpdater.totalUpdates === 0
                    onClicked: SystemUpdater.update("all")
                }
            }
        }

        RowButton {
            icon: "terminal"
            text: Tr.tr("CachyOS & AUR Packages")
            subtext: SystemUpdater.cachyCount > 0 ? Tr.tr("%1 pending: %2").arg(SystemUpdater.cachyCount).arg(SystemUpdater.cachyItems.slice(0, 3).join(", ")) : Tr.tr("System kernel & packages up to date")
            trailingIcon: SystemUpdater.cachyCount > 0 ? "download" : "check"
            disabled: SystemUpdater.busy || SystemUpdater.cachyCount === 0
            onClicked: SystemUpdater.update("cachyos")
        }

        RowButton {
            icon: "window"
            text: Tr.tr("Hyprland Ecosystem")
            subtext: SystemUpdater.hyprCount > 0 ? SystemUpdater.hyprItems.join(", ") : Tr.tr("Compositor & portals up to date")
            trailingIcon: SystemUpdater.hyprCount > 0 ? "download" : "check"
            disabled: SystemUpdater.busy || SystemUpdater.hyprCount === 0
            onClicked: SystemUpdater.update("hyprland")
        }

        RowButton {
            last: true
            icon: "palette"
            text: Tr.tr("Caelestia Packages & CLI")
            subtext: SystemUpdater.caelestiaCount > 0 ? SystemUpdater.caelestiaItems.slice(0, 2).join(" · ") : Tr.tr("Up to date · click to check/sync caelestia-cli (shell repo is in Status above)")
            trailingIcon: SystemUpdater.caelestiaCount > 0 ? "download" : "sync"
            disabled: SystemUpdater.busy || !SystemUpdater.canCheck
            onClicked: SystemUpdater.update("caelestia")
        }

        // Live output from SystemUpdater while updating or rolling back
        SectionHeader {
            visible: SystemUpdater.log.length > 0 && SystemUpdater.state !== "idle"
            text: Tr.tr("System Update Output")
        }

        StyledText {
            Layout.fillWidth: true
            visible: SystemUpdater.log.length > 0 && SystemUpdater.state !== "idle"
            text: SystemUpdater.log.join(String.fromCharCode(10))
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.mono.small
        }

        // --- ROLLBACK & RESTORE POINTS ---
        SectionHeader {
            visible: SystemUpdater.history.length > 0
            text: Tr.tr("Rollback & Restore Points")
        }

        Repeater {
            model: SystemUpdater.history.slice(0, 5)

            RowButton {
                required property var modelData
                required property int index

                first: index === 0
                last: index === Math.min(SystemUpdater.history.length, 5) - 1
                icon: "history"
                text: `${modelData.note} (${modelData.timestamp})`
                subtext: modelData.snapper_id ? Tr.tr("Btrfs Snapshot #%1 · Shell %2").arg(modelData.snapper_id).arg(modelData.shell_head || modelData.cykler_head || "—") : Tr.tr("Config backup · Shell %1").arg(modelData.shell_head || modelData.cykler_head || "—")
                trailingIcon: "undo"
                disabled: SystemUpdater.busy
                onClicked: root.pendingRollback = modelData
            }
        }

        // Rollback confirmation banner
        ConnectedRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            first: true
            last: true
            visible: root.pendingRollback !== null && !SystemUpdater.busy
            implicitHeight: visible ? rollbackConfirmColumn.implicitHeight + Tokens.padding.large * 2 : 0
            color: Colours.palette.m3errorContainer

            ColumnLayout {
                id: rollbackConfirmColumn

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: root.pendingRollback ? Tr.tr("Roll back to %1 (%2)?").arg(root.pendingRollback.note).arg(root.pendingRollback.timestamp) : ""
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.title.small
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: root.pendingRollback?.snapper_id ? Tr.tr("This will restore Btrfs snapshot #%1 and any saved Caelestia configuration backup. A reboot will be required afterwards.").arg(root.pendingRollback.snapper_id) : Tr.tr("This will restore the saved ~/.config/caelestia backup from this restore point.")
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.label.medium
                }

                RowLayout {
                    spacing: Tokens.spacing.small

                    TextButton {
                        text: Tr.tr("Confirm Rollback")
                        type: TextButton.Filled
                        onClicked: {
                            const targetId = root.pendingRollback.id;
                            root.pendingRollback = null;
                            SystemUpdater.rollback(targetId);
                        }
                    }

                    TextButton {
                        text: Tr.tr("Cancel")
                        type: TextButton.Text
                        onClicked: root.pendingRollback = null
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

                // NOTE(fork): the check already worked out whether these would come back, by
                // merging them against the update in memory, so say which it is rather than
                // leaving it to be discovered half way through
                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: ShellUpdater.stashSafe ? Tr.tr("They can be stashed while the update is pulled and built, then put back afterwards. Nothing in them clashes with this update, so they will come back cleanly.") : Tr.tr("They can be stashed while the update is pulled and built, but putting them back will conflict: the update changes the same files. You can update anyway and leave them in the stash to sort out by hand.")
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: ShellUpdater.dirtyFiles.length > 0
                    wrapMode: Text.Wrap
                    // TRANSLATORS: %1 = a comma separated list of file paths
                    text: Tr.tr("Changed here: %1").arg(root.fileList(ShellUpdater.dirtyFiles))
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: ShellUpdater.riskFiles.length > 0
                    wrapMode: Text.Wrap
                    // TRANSLATORS: %1 = a comma separated list of file paths
                    text: Tr.tr("Would conflict: %1").arg(root.fileList(ShellUpdater.riskFiles))
                    color: Colours.palette.m3onErrorContainer
                    font: Tokens.font.label.small
                }

                RowLayout {
                    spacing: Tokens.spacing.small

                    TextButton {
                        text: ShellUpdater.stashSafe ? Tr.tr("Stash, update and restore") : Tr.tr("Try it anyway")
                        type: ShellUpdater.stashSafe ? TextButton.Filled : TextButton.Tonal
                        onClicked: {
                            root.askingAboutChanges = false;
                            ShellUpdater.install("stash");
                        }
                    }

                    // Nothing is deleted: the changes go to the stash and simply are not put back
                    TextButton {
                        text: Tr.tr("Update, keep changes stashed")
                        type: ShellUpdater.stashSafe ? TextButton.Tonal : TextButton.Filled
                        onClicked: {
                            root.askingAboutChanges = false;
                            ShellUpdater.install("overwrite");
                        }
                    }

                    TextButton {
                        text: Tr.tr("Cancel")
                        type: TextButton.Text
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

        ConnectedRect {
            first: true
            Layout.fillWidth: true
            implicitHeight: checkoutRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: checkoutRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Checkout location")
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Paths.shortenHome(ShellUpdater.repoPath)
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        elide: Text.ElideMiddle
                    }
                }

                TextButton {
                    text: Tr.tr("Browse")
                    type: TextButton.Tonal
                    onClicked: {
                        const home = Paths.home + "/";
                        const path = ShellUpdater.repoPath;
                        const rel = path.startsWith(home) ? path.slice(home.length).split("/").filter(x => x) : [];
                        repoDialog.cwd = ["Home", ...rel];
                        repoDialog.open();
                    }
                }
            }

            FileDialog {
                id: repoDialog

                title: Tr.tr("Select the shell's checkout folder")
                folderMode: true
                onAccepted: path => {
                    GlobalConfig.services.repoPath = path;
                    ShellUpdater.fetchBranches(); // the new checkout has its own branches
                }
            }
        }

        ComboBoxRow {
            last: true
            // SEARCH: git channel version update
            label: Tr.tr("Branch")
            subtext: ShellUpdater.branchesLoading ? Tr.tr("Loading branches...") : Tr.tr("The origin branch to check and pull; pick one or type your own")
            value: GlobalConfig.services.updateBranch
            placeholderText: "main"
            suggestions: ShellUpdater.branches
            suggestionIcon: "call_split"
            emptyText: ShellUpdater.branchesLoading ? Tr.tr("Loading branches...") : Tr.tr("No branches found")
            onOpened: ShellUpdater.fetchBranches() // pick up branches pushed since the last check
            onEditingFinished: v => GlobalConfig.services.updateBranch = v.trim() || "main"
        }

        // Reload the shell without updating it; restarting comes back to this page
        SectionHeader {
            text: Tr.tr("Shell")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: shellRow.implicitHeight + Tokens.padding.large * 2

            RowLayout {
                id: shellRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.large

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Restart the shell")
                        font: Tokens.font.body.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Stop unloads the shell; restart starts it again and opens Nexus back here")
                        color: Colours.palette.m3outline
                        font: Tokens.font.label.small
                        wrapMode: Text.Wrap
                    }
                }

                TextButton {
                    text: Tr.tr("Stop")
                    type: TextButton.Tonal
                    onClicked: ShellUpdater.kill()
                }

                TextButton {
                    text: Tr.tr("Restart")
                    type: TextButton.Filled
                    onClicked: ShellUpdater.restartAndReopen("updates")
                }
            }
        }
    }
}
