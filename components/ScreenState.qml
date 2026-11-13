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

    // Text to put in the launcher's search field as it opens, for the things that want the launcher
    // in one of its modes rather than on apps - press and hold on the wallpaper, which opens it on
    // the wallpaper switcher. The launcher clears this as it takes it (see modules/launcher/Content.qml),
    // so it is a request, not a setting
    property string launcherSearchRequest

    // Which tab the sidebar's top card is showing, as one of the enabled tab keys (see
    // services/SidebarTabs.qml). Kept as a key rather than an index so turning a tab off doesn't
    // make the remembered position point at whichever tab took its place. Kept here so it
    // survives the sidebar closing, and so the swipe gestures can move it without reaching into
    // a panel
    property string notifPopoutTabKey: "notifications"

    // Dashboard state
    property int dashboardTab

    property date dashboardDate: new Date()

    // Asks the overview to turn its page (-1 back, 1 forward), for the swipe gestures
    signal overviewPageRequested(int delta)
}
