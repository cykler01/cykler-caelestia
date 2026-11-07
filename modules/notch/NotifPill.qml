pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// NOTE(fork): a notification as the notch shows it - the sender's picture (or the app's icon)
// beside one line of summary and one of body, which is as much as a pill across the top of the
// screen can carry. The rest of it - the actions, the full body - waits in the notification
// centre, where it would be anyway.
//
// It draws a snapshot held by services/NotchIsland.qml rather than the notification itself: a
// source rule can have the notification dropped as soon as it has no popup left, which with
// notifsTakeOver is the instant the island claims it.
RowLayout {
    id: root

    readonly property bool hasImage: NotchIsland.notifImage !== ""
    readonly property bool hasAppIcon: NotchIsland.notifAppIcon !== ""
    readonly property bool critical: NotchIsland.notifUrgency === NotificationUrgency.Critical
    readonly property int avatarSize: Tokens.padding.extraLarge
    // Wrapped lines would grow the pill down the screen, so both lines elide instead
    readonly property int textWidth: Math.max(160, Config.notch.maxTitleWidth)

    readonly property color onAvatar: root.critical ? Colours.palette.m3onError : Colours.palette.m3onSecondaryContainer
    readonly property string titleText: NotchIsland.notifSummary || NotchIsland.notifAppName
    // The message itself for a chat app; the app's name stands in when the notification is a bare
    // summary, and nothing at all when the summary was already the app's name
    readonly property string subText: {
        const body = NotchIsland.notifBody.replace(/\s*\n+\s*/g, " ").trim();
        if (body !== "")
            return body;
        return NotchIsland.notifSummary === "" ? "" : NotchIsland.notifAppName;
    }

    spacing: Tokens.spacing.medium

    StyledRect {
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: root.avatarSize
        implicitHeight: root.avatarSize
        radius: Tokens.rounding.full
        color: root.critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

        // The picture the notification came with, e.g. the avatar on a Discord message
        Loader {
            anchors.fill: parent

            asynchronous: true
            active: root.hasImage

            sourceComponent: ClipRect {
                radius: Tokens.rounding.full

                Image {
                    anchors.fill: parent

                    source: Qt.resolvedUrl(NotchIsland.notifImage)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: {
                        const size = root.avatarSize * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1);
                        return Qt.size(size, size);
                    }
                    cache: false
                    asynchronous: true
                }
            }
        }

        // The app's own icon: in the picture's place when there is none, and as a badge on it when
        // there is - the same arrangement as the corner popup
        Loader {
            anchors.horizontalCenter: root.hasImage ? undefined : parent.horizontalCenter
            anchors.verticalCenter: root.hasImage ? undefined : parent.verticalCenter
            anchors.right: root.hasImage ? parent.right : undefined
            anchors.bottom: root.hasImage ? parent.bottom : undefined

            asynchronous: true
            active: root.hasAppIcon
            width: root.hasImage ? Tokens.sizes.notifs.badge : root.avatarSize
            height: width

            sourceComponent: StyledRect {
                radius: Tokens.rounding.full
                color: !root.hasImage ? "transparent" : root.critical ? Colours.palette.m3error : Colours.palette.m3secondaryContainer

                ColouredIcon {
                    anchors.centerIn: parent

                    width: Math.round(parent.width * 0.6)
                    height: width
                    source: Quickshell.iconPath(NotchIsland.notifAppIcon)
                    colour: root.onAvatar
                    layer.enabled: NotchIsland.notifAppIcon.endsWith("symbolic")
                }
            }
        }

        // Nothing came with it at all
        MaterialIcon {
            anchors.centerIn: parent

            visible: !root.hasImage && !root.hasAppIcon
            text: "notifications"
            color: root.onAvatar
            fontStyle: Tokens.font.icon.small
        }
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignVCenter

        spacing: 0

        StyledText {
            Layout.maximumWidth: root.textWidth

            text: root.titleText
            color: Colours.palette.m3onSurface
            font: Tokens.font.label.large
            elide: Text.ElideRight
        }

        StyledText {
            Layout.maximumWidth: root.textWidth

            visible: text !== ""
            text: root.subText
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.label.small
            elide: Text.ElideRight
        }
    }
}
