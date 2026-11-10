import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent

    // Payload for the workspace window preview: the window to show and the icon it was opened from,
    // which is what tells the pointer moving away from the icon where the panel it belongs to is
    property var windowPreviewClient
    property Item windowPreviewTrigger

    signal detachRequested(mode: string)
}
