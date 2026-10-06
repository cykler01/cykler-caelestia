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
    // An ambient fullscreen clock, not a lock - only ever shown on the one screen chosen in
    // Power & battery settings (general.standby.screen), see modules/standby/Standby.qml
    property bool standby

    // Asks the overview to turn its page (-1 back, 1 forward), for the swipe gestures
    signal overviewPageRequested(int delta)

    // Which tab the sidebar's top card is showing: 0 notifications, 1 media library, 2 to-do
    // (see modules/sidebar/Content.qml). Kept here so it survives the sidebar closing, and so
    // the swipe gestures can move it without reaching into a panel
    property int notifPopoutTab

    // Dashboard state
    property int dashboardTab

    property date dashboardDate: new Date()
}
