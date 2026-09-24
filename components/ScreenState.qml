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
    property bool notifPopout
    property bool overview

    // Which tab the notification popout is showing: 0 notifications, 1 media library.
    // Kept here rather than in the popout so it survives the popout closing, and so the
    // swipe gestures can move it without reaching into a window
    property int notifPopoutTab

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
