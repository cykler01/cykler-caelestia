pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.lock as Lock
import qs.modules.lock.center as LockCenter
import qs.modules.lock.layouts as LockLayouts

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
    // way the desktop widgets do for their own miniature of the screen, for the rare case
    // there's no screen yet
    property real screenHeight: 1080
    property real screenWidth: 1920

    // NOTE(fork): the split, sidebar and minimal layouts (Config.lock.layout) span the whole
    // screen rather than a card, so for those the real layout is drawn at the screen's full size
    // and scaled down instead - with lock null, which swaps the password field for a dummy
    readonly property string layoutId: Config.lock.layout ?? "card"
    readonly property bool cardLayout: !["split", "sidebar", "minimal"].includes(root.layoutId)
    readonly property real screenFactor: (root.width - root.framePadding * 2) / Math.max(1, root.screenWidth)
    readonly property real fullHeight: root.screenHeight * Tokens.sizes.lock.heightMult - Tokens.padding.extraLargeIncreased
    readonly property real fullWidth: root.fullHeight * Tokens.sizes.lock.ratio - Tokens.padding.extraLargeIncreased

    readonly property real factor: (root.width - root.framePadding * 2) / Math.max(1, root.fullWidth)

    implicitHeight: root.cardLayout ? root.fullHeight * root.factor + root.framePadding * 2 : root.screenHeight * root.screenFactor + root.framePadding * 2

    StyledRect {
        id: frame

        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.palette.m3shadow
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.4)
        clip: true

        Loader {
            x: root.framePadding
            y: root.framePadding
            width: root.screenWidth
            height: root.screenHeight
            scale: root.screenFactor
            transformOrigin: Item.TopLeft
            active: !root.cardLayout
            visible: active

            sourceComponent: root.layoutId === "split" ? splitPreview : root.layoutId === "sidebar" ? sidebarPreview : minimalPreview
        }

        Component {
            id: splitPreview

            LockLayouts.SplitLayout {
                lock: null
            }
        }

        Component {
            id: sidebarPreview

            LockLayouts.SidebarLayout {
                lock: null
            }
        }

        Component {
            id: minimalPreview

            LockLayouts.MinimalLayout {
                lock: null
            }
        }

        RowLayout {
            id: content

            visible: root.cardLayout
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

                // The real centre placeholder in digital mode, but the actual analogue dial
                // (dimmed like the placeholder, still non-interactive) in analogue mode - so the
                // preview reflects what the lock screen will actually show for either setting
                Loader {
                    asynchronous: true
                    active: Config.lock.analogueClock

                    sourceComponent: LockCenter.AnalogueClock {
                        centerScale: Math.min(1, root.screenHeight / 1440)
                        opacity: 0.35
                    }
                }

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "lock_clock"
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.35)
                    fontStyle: Tokens.font.icon.large
                    visible: !Config.lock.analogueClock
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
