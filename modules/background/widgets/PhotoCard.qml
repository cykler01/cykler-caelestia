pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.background

// --- Photo: a picture from a folder, one at a time ---
WidgetCard {
    id: photo

    readonly property var files: images.entries
    // The photo showing, by path, so the card can find its place in the folder again after a rescan
    property string current

    readonly property int position: photo.files.findIndex(f => f.path === photo.current)

    function pick(): void {
        if (photo.files.length === 0) {
            photo.current = "";
            return;
        }

        photo.current = photo.files[Math.floor(Math.random() * photo.files.length)].path;
    }

    function step(delta: int): void {
        const n = photo.files.length;
        if (n === 0)
            return;

        // Stepping from a photo that has since left the folder starts again from the top
        const i = photo.position < 0 ? 0 : photo.position;
        photo.current = photo.files[(i + delta + n) % n].path;
    }

    title: Tr.tr("Pictures")
    icon: "photo"

    // A random photo to start with, and another whenever the one showing is no longer there
    Component.onCompleted: photo.pick()
    onFilesChanged: {
        if (photo.position < 0)
            photo.pick();
    }

    FileSystemModel {
        id: images

        path: GlobalConfig.background.desktopWidgets.photoDir
        recursive: true
        watchChanges: true
        filter: FileSystemModel.Images
    }

    // The photo area. The picture is scaled to fit and centred, its own corners rounded, and the
    // space around it left unpainted so the card's plate, tint and wallpaper blur show through
    // exactly as they do beside the header
    Item {
        id: frame

        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 100

        // How much the picture has to shrink to fit the area, so the rounded frame can be cut to
        // the picture rather than to the area
        readonly property real fit: pic.sourceSize.width > 0 && pic.sourceSize.height > 0 ? Math.min(width / pic.sourceSize.width, height / pic.sourceSize.height) : 0

        ClipRect {
            anchors.centerIn: parent
            width: Math.round(pic.sourceSize.width * frame.fit)
            height: Math.round(pic.sourceSize.height * frame.fit)
            radius: Tokens.rounding.large

            Image {
                id: pic

                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                source: photo.current !== "" ? Paths.absolutePath(photo.current) : ""
            }

            // Text buttons carry no plate, so nothing frames the arrows against the picture
            IconButton {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.spacing.small
                visible: photo.files.length > 1
                icon: "chevron_left"
                type: IconButton.Text
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: photo.step(-1)
            }

            IconButton {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tokens.spacing.small
                visible: photo.files.length > 1
                icon: "chevron_right"
                type: IconButton.Text
                inactiveOnColour: Colours.palette.m3onSurface
                onClicked: photo.step(1)
            }
        }

        StyledText {
            anchors.centerIn: parent
            width: parent.width - Tokens.padding.medium * 2
            visible: photo.files.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: Tr.tr("No photos in the folder")
            color: Colours.palette.m3outline
            font: Tokens.font.label.medium
            wrapMode: Text.Wrap
        }
    }
}
