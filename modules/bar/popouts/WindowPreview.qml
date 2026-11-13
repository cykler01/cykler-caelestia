pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils

// Live preview of a single window, shown by the workspace window icons when the
// window actions are enabled. Sized by the popout it is loaded into.
Item {
    id: root

    required property var client

    // Drawn at the window's own shape and within a box that fits a popout, rather than in a fixed
    // 320x200 frame: a capture that does not fill its frame is letterboxed against the card, which
    // reads as an unstyled strip beside the window rather than as a framed preview
    readonly property var ipcSize: root.client?.lastIpcObject?.size ?? []
    readonly property real windowAspect: ipcSize.length === 2 && Number(ipcSize[1]) > 0 && Number(ipcSize[0]) > 0 ? Number(ipcSize[0]) / Number(ipcSize[1]) : 16 / 9
    readonly property real previewWidth: Math.round(Math.min(320, 260 * root.windowAspect))
    readonly property real previewHeight: Math.round(root.previewWidth / root.windowAspect)

    implicitWidth: root.previewWidth
    implicitHeight: child.implicitHeight

    Column {
        id: child

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.previewWidth
        spacing: Tokens.spacing.medium

        // The same header the active window popout gives its preview, so hovering an icon says which
        // window it belongs to the way the rest of the shell does
        RowLayout {
            width: parent.width
            spacing: Tokens.spacing.medium

            IconImage {
                asynchronous: true
                Layout.alignment: Qt.AlignVCenter
                implicitSize: details.implicitHeight
                source: Icons.getAppIcon(root.client?.lastIpcObject.class ?? "", "image-missing")
            }

            ColumnLayout {
                id: details

                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    text: root.client?.title ?? ""
                    font: Tokens.font.body.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.client?.lastIpcObject.class ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        // The capture sits in the card the overview draws its windows in: the same surface, hairline
        // outline and rounding, so a preview does not look like a bare screenshot dropped into a popout
        ClippingRectangle {
            id: frame

            width: root.previewWidth
            height: root.previewHeight
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainerHighest
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3outline, 0.5)

            ScreencopyView {
                id: screencopy

                anchors.fill: parent
                captureSource: root.client?.wayland ?? null
                live: root.client !== null
                constraintSize: Qt.size(frame.width, frame.height)
            }

            Loader {
                anchors.centerIn: parent
                active: !screencopy.hasContent

                sourceComponent: StyledText {
                    text: Tr.tr("Preview unavailable")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
