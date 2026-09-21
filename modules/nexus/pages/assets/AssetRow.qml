import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

// NOTE(fork): a single editable caelestia asset, e.g. the logo or the session screen gif.
//
// Choosing a file copies it into the shell's data directory and points the option at that
// copy, the same way the profile picture is changed. The shell's own assets are never
// written to (they can be read only, e.g. under /etc/xdg), and the copy means the asset
// survives the original file being moved or deleted.
//
// Setting targetPath makes the row manage that file directly instead of a config option.
// The profile picture is the one asset that works this way: it lives at ~/.face and isn't
// an option, so the chosen file replaces it in place.
ConnectedRect {
    id: root

    required property string label
    required property string subtext

    // Path of the file to manage directly, instead of a config option
    property string targetPath
    // Name of the option, also used as the name of the copied file
    property string option
    // The option's current value, and the value it falls back to
    property string value
    property string defaultValue
    // What the option currently resolves to, shown as the preview
    property url previewSource
    // Applies the path of the copy to the option, and restores the option's default
    property var write
    property var reset

    // Animated assets are previewed with an animated image
    property bool previewAnimated
    property list<string> filters: Images.validImageExtensions
    // Shown in place of the preview when there is no image to show. Assets the shell
    // always ships with are missing rather than unset, but a profile picture can simply
    // not be there yet, so it gets a friendlier icon.
    property string fallbackIcon: "broken_image"

    // Whether the managed file is there. Checked on disk rather than read off the preview,
    // which can't tell a missing file apart from one it failed to decode.
    property bool filePresent
    // Bumped when the managed file changes, so the preview isn't served from Qt's cache
    property int revision

    readonly property bool fileManaged: root.targetPath !== ""
    readonly property string targetDir: root.targetPath.slice(0, root.targetPath.lastIndexOf("/"))
    readonly property bool customized: root.fileManaged ? root.filePresent : root.value !== root.defaultValue
    // The preview is loaded through a throwaway query so a replaced file is shown again
    readonly property url preview: {
        const source = root.fileManaged ? Qt.resolvedUrl(root.targetPath) : root.previewSource;
        return root.revision > 0 ? `${source}?v=${root.revision}` : source;
    }
    readonly property string sourceLabel: {
        if (root.fileManaged)
            return root.filePresent ? Paths.shortenHome(root.targetPath) : Tr.tr("None");

        if (root.value === root.defaultValue)
            return Tr.tr("Shell default");
        if (!root.value)
            return Tr.tr("None");
        return Paths.shortenHome(root.value);
    }
    // Covers both the missing (empty path) and unreadable cases. Only the image in use
    // is given a source, so there is only ever one status to look at.
    readonly property bool previewFailed: {
        const status = root.previewAnimated ? animatedPreview.status : staticPreview.status;
        return status === Image.Error || status === Image.Null;
    }

    // Looks for the managed file, which a QML image can't do on its own.
    function checkFile(): void {
        if (root.fileManaged)
            checkProcess.running = true;
    }

    // Copies the chosen file into the shell's data directory and points the option at it.
    // The copy keeps the option's name so repeat uploads reuse the same file. A managed
    // file is replaced in place instead, keeping its path.
    function choose(source: string): void {
        const dot = source.lastIndexOf(".");
        const ext = dot > source.lastIndexOf("/") ? source.slice(dot).toLowerCase() : "";
        const target = root.fileManaged ? root.targetPath : `${Paths.assetsdir}/${root.option}${ext}`;
        const dir = root.fileManaged ? root.targetDir : Paths.assetsdir;

        if (source === target)
            return;

        // A copy left by an earlier upload of this option, if any, is replaced by this one
        const previous = root.value.startsWith(`${Paths.assetsdir}/`) ? root.value : "";

        copyProcess.previous = root.fileManaged ? "" : previous;
        copyProcess.source = source;
        copyProcess.copyTarget = target;
        copyProcess.command = ["sh", "-c", "mkdir -p \"$1\" && cp -- \"$2\" \"$3\"", "sh", dir, source, target];
        copyProcess.running = true;
    }

    // Restores the option's default, dropping the copy if that's what it points at.
    function resetAsset(): void {
        if (root.fileManaged) {
            if (!CUtils.deleteFile(Qt.resolvedUrl(root.targetPath))) {
                Toaster.toast(Tr.tr("Failed to reset asset"), Paths.shortenHome(root.targetPath), "error", Toast.Error);
                return;
            }

            root.filePresent = false;
            root.revision++;
            Toaster.toast(Tr.tr("Asset reset"), Tr.tr("Using the shell's default image again"), "settings_backup_restore", Toast.Info);
            return;
        }

        if (root.value.startsWith(`${Paths.assetsdir}/`))
            CUtils.deleteFile(Qt.resolvedUrl(root.value));

        root.reset();
        Toaster.toast(Tr.tr("Asset reset"), Tr.tr("Using the shell's default image again"), "settings_backup_restore", Toast.Info);
    }

    Layout.fillWidth: true
    implicitHeight: rowLayout.implicitHeight + rowLayout.anchors.margins * 2

    onTargetPathChanged: root.checkFile()
    Component.onCompleted: root.checkFile()

    Process {
        id: checkProcess

        // `test` isn't always a binary of its own, so let sh find it.
        command: ["sh", "-c", "test -f \"$1\"", "sh", root.targetPath]
        onExited: code => { // qmllint disable signal-handler-parameters
            root.filePresent = code === 0;
        }
    }

    Process {
        id: copyProcess

        property string source
        property string copyTarget
        // The copy this option had before, removed once the new one has landed
        property string previous

        // The data directory isn't guaranteed to exist, so it's created as part of the copy
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0) {
                Toaster.toast(Tr.tr("Failed to set asset"), Paths.shortenHome(copyProcess.source), "error", Toast.Error);
                return;
            }

            if (copyProcess.previous)
                CUtils.deleteFile(Qt.resolvedUrl(copyProcess.previous));

            if (root.fileManaged) {
                root.filePresent = true;
                root.revision++;
            } else {
                root.write(copyProcess.copyTarget);
            }

            Toaster.toast(Tr.tr("Asset updated"), Paths.shortenHome(copyProcess.copyTarget), "image", Toast.Success);
        }
    }

    FileDialog {
        id: dialog

        title: Tr.tr("Choose an image")
        filterLabel: Tr.tr("Image files")
        filters: root.filters
        onAccepted: path => root.choose(path)
    }

    RowLayout {
        id: rowLayout

        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        anchors.leftMargin: Tokens.padding.largeIncreased
        anchors.rightMargin: Tokens.padding.largeIncreased
        spacing: Tokens.spacing.medium

        StyledClippingRect {
            implicitWidth: Tokens.padding.extraExtraLarge
            implicitHeight: Tokens.padding.extraExtraLarge
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerHigh

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: dialog.open()
            }

            Image {
                id: staticPreview

                anchors.fill: parent
                visible: !root.previewAnimated
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(Tokens.padding.extraExtraLarge * 2, Tokens.padding.extraExtraLarge * 2)
                source: root.previewAnimated ? "" : root.preview
            }

            AnimatedImage {
                id: animatedPreview

                anchors.fill: parent
                visible: root.previewAnimated
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: root.previewAnimated ? root.preview : ""
            }

            MaterialIcon {
                anchors.centerIn: parent
                visible: root.previewFailed
                text: root.fallbackIcon
                color: Colours.palette.m3outline
                fontStyle: Tokens.font.icon.medium
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.label
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.subtext
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                text: root.sourceLabel
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
                elide: Text.ElideRight
            }
        }

        IconButton {
            icon: "folder_open"
            type: IconButton.Tonal
            onClicked: dialog.open()
        }

        IconButton {
            visible: root.customized
            icon: "restart_alt"
            type: IconButton.Tonal
            onClicked: root.resetAsset()
        }
    }
}
