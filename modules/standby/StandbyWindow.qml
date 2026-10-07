pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.widgets
import qs.services
import qs.modules.lock.center as LockCenter

// One of these per connected screen (see Standby.qml) - only ever visible on whichever screen
// had focus when the standby keybind was pressed, via its own ScreenState.standby.
StyledWindow {
    id: root

    readonly property ScreenState screenState: ShellState.forScreen(screen)
    readonly property bool open: root.screenState?.standby ?? false

    // Same idea as the notch: local counts once it is actually playing, or once nothing
    // external is, and it still has a track loaded
    readonly property bool local: Music.playing || (Players.active?.isPlaying !== true && Music.hasTrack)
    readonly property bool hasMedia: root.local ? Music.hasTrack : Players.active !== null
    readonly property string trackTitle: root.local ? Music.title : Players.active?.trackTitle ?? ""
    readonly property string trackArtist: root.local ? Music.artist : Players.active?.trackArtist ?? ""

    // All screens, not just this one - a key press dismissing only the screen it landed on
    // would leave the "show on every screen" hold mode stuck on everywhere else
    function dismiss(): void {
        for (const s of Screens.screens)
            ShellState.forScreen(s).standby = false;
    }

    // MouseArea's cursorShape: Qt.BlankCursor never actually hid it on this Wayland setup -
    // Hyprland's own cursor:invisible config option does, reliably, so this drives that directly
    // instead of fighting Qt's per-surface Wayland cursor protocol. Reacts to open rather than
    // being called from whatever dismissed it, since that can be this window itself (a key
    // press) as well as the keybind or IPC that opened it.
    onOpenChanged: Hypr.extras.message(Hypr.usingLua ? `eval hl.config({ cursor = { invisible = ${root.open} } })` : `keyword cursor:invisible ${root.open ? 1 : 0}`)

    name: "standby"
    visible: root.open
    implicitWidth: screen?.width ?? 0
    implicitHeight: screen?.height ?? 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Rectangle {
        anchors.fill: parent
        color: "black"

        // A click anywhere dismisses it, the same as a key press. Also swallows the click so it
        // doesn't fall through to whatever's underneath
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.dismiss()
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.large

            focus: root.open
            Keys.onPressed: event => {
                event.accepted = true;
                root.dismiss();
            }

            LockCenter.Clock {
                Layout.alignment: Qt.AlignHCenter

                centerScale: 1
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: GlobalConfig.general.standby.showDate
                text: Time.format("dddd • d MMM").toUpperCase()
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.headline.small
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.medium
                visible: GlobalConfig.general.standby.showMusic && root.hasMedia
                spacing: Tokens.spacing.medium

                CoverArt {
                    implicitWidth: 56
                    implicitHeight: 56
                    source: root.local ? Music.coverPath : Players.getArtUrl(Players.active)
                    spinning: root.local ? Music.playing : (Players.active?.isPlaying ?? false)
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: root.trackTitle
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.title.small
                        elide: Text.ElideRight
                        Layout.maximumWidth: 400
                    }

                    StyledText {
                        visible: root.trackArtist !== ""
                        text: root.trackArtist
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                        Layout.maximumWidth: 400
                    }
                }
            }
        }
    }
}
