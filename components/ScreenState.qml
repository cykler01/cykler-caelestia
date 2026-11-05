import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool utilities
    property bool sidebar
    property bool overview

    // The phone whose storage the sidebar is browsing, empty while its tabs are showing. The file
    // explorer takes the card over rather than having a panel of its own (see
    // modules/notifpopout/Content.qml), and only for as long as the sidebar stays open
    property string phoneBrowseDevice

    // The timer panel is showing in the sidebar in place of its tabs, opened from the timer button in the
    // utilities panel (see modules/notifpopout/Content.qml). Cleared as the sidebar closes, so it does not
    // greet the next open
    property bool timerPane

    // The dino game is up in place of the sidebar's empty notification dock, started with space
    // (see modules/notifpopout/Content.qml). Cleared as the sidebar closes, and kept here so the
    // drawer knows to take the keyboard for it
    property bool dinoGame

    // The desktop's widget layout is being rearranged: the cards are draggable and snap to the grid
    property bool widgetEdit

    // Asks the overview to turn its page (-1 back, 1 forward), for the swipe gestures
    signal overviewPageRequested(int delta)

    // Which tab the sidebar's top card is showing: 0 notifications, 1 media library, 2 to-do,
    // 3 notepad, 4 AI chat when it is enabled (see modules/sidebar/Content.qml). Kept here so it
    // survives the sidebar closing, and so the swipe gestures can move it without reaching into
    // a panel
    property int notifPopoutTab

    // Dashboard state
    property int dashboardTab

    property date dashboardDate: new Date()
}
