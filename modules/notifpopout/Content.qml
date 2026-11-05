import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.aichatpopout as AiChatPopout
import qs.modules.notepadpopout as NotepadPopout
import qs.modules.sidebar as Sidebar
import qs.modules.todopopout as TodoPopout
import qs.modules.utilities as Utilities
import qs.modules.dashboard.media

// Sits on the drawers window's frame (see Wrapper.qml), so there is no background of its own: the panel's
// morphing blob is the surface, and the content rests on it in the same containers the sidebar uses.
//
// Five tabs, moved between with the same swipe that opens the popout: the notification dock, the
// local music library, the to-do list, the notepad and, when turned on in the settings, the AI
// chat, so they all sit in the one panel that swipe already reaches rather than each needing a
// window of its own. The dino game is not a tab:
// with nothing to read, the notification dock turns into it on space, and turns back when it is
// closed.
Item {
    id: root

    required property ScreenState screenState
    required property var props
    // Whether the popout is on screen (or animating out): the local player controls, which follow the playback
    // position many times a second, are only built then
    property bool shown: true

    // 0 notifications, 1 media library, 2 to-do, 3 notepad, 4 AI chat (when enabled). Lives on
    // the screen state so closing the popout doesn't send it back to the first tab
    readonly property int tab: root.screenState.notifPopoutTab
    // The AI chat is optional, so the tab only exists while it is turned on
    readonly property bool aiChatEnabled: Config.sidebar.aiChat ?? false
    // The library walks the music folder, so it is only built the first time the tab is
    // actually opened, and kept afterwards rather than rebuilt on every switch back.
    // Seeded from the tab so a config reload on the library tab doesn't sit empty
    property bool libraryLoaded: root.tab === 1
    // Where the tab switch is, in tabs: follows the tab through an animation, and is what
    // everything that moves between the panes below reads
    property real tabPos: root.tab
    // How many notifications are up, which is what makes the dino game reachable: it is the
    // reward for an empty dock, not something to play over the things waiting to be read
    readonly property int notifCount: Notifs.list.reduce((acc, n) => n.closed ? acc : acc + 1, 0)
    // The dino game is up in place of the empty notification dock, started with space and put
    // away again by its close button. On the screen state so the drawer knows to take the keys
    readonly property bool dinoShown: root.screenState.dinoGame && Config.sidebar.dinoGame

    // The phone whose storage is being browsed, if any. The file explorer takes the card over
    // rather than sitting in the utilities panel (see modules/utilities/cards/PhoneShare.qml),
    // so closing it returns to the tab that was on show
    readonly property string browsingDevice: root.screenState.phoneBrowseDevice
    readonly property bool browsing: root.browsingDevice !== ""
    // Empty until the mount state for that phone is known, so the browser is not built for a
    // storage root that does not exist yet
    readonly property string browsingRoot: KdeConnect.storageRoot(root.browsingDevice)

    // The timer, reached from the timer button in the utilities panel: it takes the card over rather than being
    // another tab, since it is not one of the things the tab bar is for
    readonly property bool timerShown: root.screenState.timerPane

    function showTab(index: int): void {
        root.screenState.notifPopoutTab = index;
    }

    // Turning the chat off while it is on show, or a remembered tab left over from before,
    // leaves the tab bar with no tab it can accept
    function closeHiddenTab(): void {
        if (!root.aiChatEnabled && root.tab === 4)
            root.showTab(0);
    }

    Component.onCompleted: root.closeHiddenTab()
    onAiChatEnabledChanged: root.closeHiddenTab()

    onTabChanged: {
        if (root.tab === 1)
            root.libraryLoaded = true;
        if (root.tab !== 0)
            root.screenState.dinoGame = false;
    }

    // Closing the sidebar puts the tabs back, so neither the timer panel nor a run in the
    // notification dock greets the next open
    onShownChanged: {
        if (!root.shown) {
            root.screenState.timerPane = false;
            root.screenState.dinoGame = false;
        }
    }

    Behavior on tabPos {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Connections {
        // Unmounting or unplugging leaves nothing to browse, so fall back to the tabs
        function onMountsChanged(): void {
            if (root.browsing && !KdeConnect.isMounted(root.browsingDevice))
                root.screenState.phoneBrowseDevice = "";
        }

        target: KdeConnect
    }

    // Space starts the dino game while the dock has nothing to read. A window shortcut rather than
    // a key handler on the dock, because the to-do tab keeps the window's focus item and a key
    // handler on the dock never gets the focus it would need to see the press
    Shortcut {
        enabled: Config.sidebar.dinoGame && root.tab === 0 && root.shown && root.notifCount === 0 && !root.dinoShown
        sequence: "Space"

        onActivated: root.screenState.dinoGame = true
    }

    StyledRect {
        anchors.fill: parent
        visible: root.browsing

        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerLow

        Loader {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            active: root.browsing && root.browsingRoot !== ""

            sourceComponent: Utilities.PhoneBrowser {
                deviceId: root.browsingDevice
                deviceName: KdeConnect.devices.find(d => d.id === root.browsingDevice)?.name ?? ""
                rootPath: root.browsingRoot
                open: root.browsing

                onCloseRequested: root.screenState.phoneBrowseDevice = ""
            }
        }
    }

    StyledRect {
        anchors.fill: parent
        visible: root.timerShown

        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainerLow

        TimerPane {
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.medium

        visible: !root.browsing && !root.timerShown
        enabled: !root.browsing && !root.timerShown

        SegmentedBar {
            Layout.fillWidth: true
            // Icon-only: four full labels ("Notifications" is a long word) don't fit this
            // panel's width without the icon and text squeezing into each other
            compact: true

            model: {
                const tabs = [{
                    icon: "notifications",
                    text: Tr.tr("Notifications")
                }, {
                    icon: "library_music",
                    text: Tr.tr("Music")
                }, {
                    icon: "checklist",
                    text: Tr.tr("To-do")
                }, {
                    icon: "edit_note",
                    text: Tr.tr("Notepad")
                }];
                if (root.aiChatEnabled)
                    tabs.push({
                        icon: "forum",
                        text: Tr.tr("AI chat")
                    });
                return tabs;
            }
            currentIndex: root.tab
            onActivated: index => root.showTab(index)
        }

        // The panes sit side by side and slide past each other, fading as they go, so switching
        // reads as moving along rather than as one thing replacing another
        Item {
            id: panes

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledRect {
                id: notifPane

                readonly property real offset: 0 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                Sidebar.NotifDock {
                    anchors.fill: parent
                    // Nothing of the dock is left showing behind the game: not its heading, and
                    // not the picture and line that say there is nothing to read
                    visible: !root.dinoShown

                    props: root.props
                    screenState: root.screenState
                }

                // Only built while it is being played, so an idle dock costs nothing and every
                // run starts from the top
                Loader {
                    anchors.fill: parent
                    active: root.dinoShown

                    sourceComponent: DinoGame {
                        live: root.tab === 0 && root.shown
                        best: root.props.dinoBest ?? 0
                        onBestBeaten: score => root.props.dinoBest = score
                        onExit: root.screenState.dinoGame = false
                    }
                }
            }

            StyledRect {
                id: libraryPane

                readonly property real offset: 1 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                Loader {
                    anchors.fill: parent
                    active: root.libraryLoaded

                    sourceComponent: LibraryBrowser {
                        // Sits straight on the container, like the notification cards do
                        color: "transparent"
                    }
                }
            }

            StyledRect {
                id: todoPane

                readonly property real offset: 2 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                TodoPopout.Content {
                    anchors.fill: parent

                    open: root.tab === 2
                    screenState: root.screenState
                }
            }

            StyledRect {
                id: notepadPane

                readonly property real offset: 3 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                NotepadPopout.Content {
                    anchors.fill: parent

                    open: root.tab === 3
                    screenState: root.screenState
                }
            }

            StyledRect {
                id: aiChatPane

                readonly property real offset: 4 - root.tabPos

                x: offset * panes.width * 0.6
                width: panes.width
                height: panes.height
                opacity: 1 - Math.min(1, Math.abs(offset))
                visible: opacity > 0
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerLow

                // Optional, so none of the chat is built while the tab is off
                Loader {
                    anchors.fill: parent
                    active: root.aiChatEnabled

                    sourceComponent: AiChatPopout.Content {
                        open: root.tab === 4
                        screenState: root.screenState
                    }
                }
            }
        }

        // Controls for the in-shell player alone, under the library. The media tab's own
        // controls follow whichever MPRIS player is active; these keep driving the local
        // queue while you are picking from it, and while anything else is playing. They grow in
        // and out with the tab rather than popping the panes' height about, and shrink away again
        // moving on to the to-do or notepad tab.
        Loader {
            id: localControls

            // 1 right on the music tab, fading out towards either neighbour
            readonly property real nearMusic: Math.max(0, 1 - Math.abs(root.tabPos - 1))

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.medium
            Layout.rightMargin: Tokens.padding.medium
            Layout.preferredHeight: (item ? item.implicitHeight : 64) * nearMusic
            visible: nearMusic > 0.01
            opacity: nearMusic
            clip: true
            active: root.shown && (root.tab === 1 || nearMusic > 0.01)

            sourceComponent: LocalControls {}
        }
    }
}
