import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// A pill button for the editor's bar and sheets: an icon, optionally a label. tone picks the
// colours: "tonal" (default), "primary", "error" or "plain"; checked shows it as switched on
StyledRect {
    id: root

    property string icon
    property string text
    property string tone: "tonal"
    property bool checked: false
    property bool disabled: false

    readonly property color fill: {
        // Switched on is the tonal fill, so a toggle never outshouts the one primary button (Save)
        if (root.checked)
            return Colours.palette.m3secondaryContainer;
        switch (root.tone) {
        case "primary":
            return Colours.palette.m3primary;
        case "error":
            return Colours.palette.m3error;
        case "plain":
            return "transparent";
        default:
            return Colours.palette.m3secondaryContainer;
        }
    }
    readonly property color onFill: {
        if (root.checked)
            return Colours.palette.m3onSecondaryContainer;
        if (root.tone === "primary")
            return Colours.palette.m3onPrimary;
        if (root.tone === "error")
            return Colours.palette.m3onError;
        if (root.tone === "plain")
            return Colours.palette.m3onSurface;
        return Colours.palette.m3onSecondaryContainer;
    }

    signal activated

    implicitWidth: row.implicitWidth + (root.text !== "" ? Tokens.padding.large * 2 : Tokens.padding.small * 2)
    implicitHeight: 40
    radius: Tokens.rounding.full
    color: root.fill
    opacity: root.disabled ? 0.4 : 1

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            visible: root.icon !== ""
            text: root.icon
            color: root.onFill
            fontStyle: Tokens.font.icon.small
        }

        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.onFill
            font: Tokens.font.label.large
        }
    }

    StateLayer {
        radius: root.radius
        color: root.onFill
        disabled: root.disabled
        onClicked: root.activated()
    }
}
