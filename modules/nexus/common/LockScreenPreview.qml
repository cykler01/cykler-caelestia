pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock as Lock

// A live, read-only miniature of the actual lock screen - the real widgets (weather, fetch,
// media, ...), rendered with WidgetColumn.qml (the exact same component Content.qml itself uses),
// scaled down to fit the settings page. Not an abstract mock-up of what the lock screen might
// look like - this *is* the real thing, just smaller, so it updates live as entries are
// reordered/resized/hidden below it.
//
// Deliberately non-interactive: an invisible MouseArea on top eats every click so nothing in
// here can accidentally fire a real action (session buttons, media transport, notification
// swipes) while someone's just trying to preview a layout.
Item {
    id: root

    readonly property real framePadding: Tokens.padding.large

    // The real monitor's height, same as LockSurface.qml uses to size Content - without this the
    // preview's proportions (and therefore which widgets show their extra detail/forecast/etc)
    // wouldn't match what actually ends up on the real lock screen. Falls back to 1080 the same
    // way WidgetGridEditor.qml does for its own miniature of the desktop, for the rare case
    // there's no screen yet
    property real screenHeight: 1080
    readonly property real fullHeight: root.screenHeight * Tokens.sizes.lock.heightMult - Tokens.padding.extraLargeIncreased
    readonly property real fullWidth: root.fullHeight * Tokens.sizes.lock.ratio - Tokens.padding.extraLargeIncreased

    readonly property real factor: (root.width - root.framePadding * 2) / Math.max(1, root.fullWidth)

    implicitHeight: root.fullHeight * root.factor + root.framePadding * 2

    StyledRect {
        id: frame

        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3shadow
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        clip: true

        RowLayout {
            id: content

            x: root.framePadding
            y: root.framePadding
            width: root.fullWidth
            height: root.fullHeight
            scale: root.factor
            transformOrigin: Item.TopLeft

            spacing: Tokens.spacing.largeIncreased * 2

            Lock.WidgetColumn {
                side: "left"
                rootHeight: content.height
                lock: null
            }

            ColumnLayout {
                // Matches Center.qml's own width exactly (same token, same centerScale formula)
                // - without reserving the same real width here, the two widget columns beside it
                // would end up wider than they really are, throwing off font/logo/colour-count
                // decisions that key off each widget's actual pixel width
                Layout.preferredWidth: Tokens.sizes.lock.centerWidth * Math.min(1, root.screenHeight / 1440)
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "lock_clock"
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.35)
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: 64
                    text: qsTr("Clock stays here")
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.35)
                    font: Tokens.font.label.small
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            Lock.WidgetColumn {
                side: "right"
                rootHeight: content.height
                lock: null
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
    }
}
