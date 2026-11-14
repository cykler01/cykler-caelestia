pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// NOTE(fork): what the bar's download ring has no room for. Hovering the ring opens this where the
// countdown's own panel opens: what is downloading, how far it has got and how fast, which the
// notch's bubble says too but the bar had no way to. Nothing here controls the download - it is a
// browser's or Steam's transfer - so there is no button to offer, only the figures.
ColumnLayout {
    id: root

    readonly property var item: Downloads.primary
    readonly property bool steam: (root.item.kind ?? "") === "steam"
    readonly property real progress: root.item.progress ?? -1
    readonly property bool known: root.progress >= 0
    readonly property int others: Math.max(0, Downloads.count - 1)

    // A file name can be any length at all, so it gets a budget and elides rather than stretching
    // the popout across the screen
    readonly property int nameWidth: 240

    readonly property string name: root.item.name || (root.steam ? Tr.tr("Steam download") : Tr.tr("Download"))
    // How far along, and how fast. A source with no total to go on can still say what has arrived
    readonly property string status: {
        const parts = [];
        if (root.known)
            parts.push(Strings.percentOne(root.progress));
        else if ((root.item.done ?? 0) > 0)
            parts.push(Strings.bytes(root.item.done));

        const speed = root.item.speed ?? 0;
        if (speed > 0)
            // TRANSLATORS: %1 = a size such as 2.4 MB, making a rate such as "2.4 MB/s"
            parts.push(Tr.trCtx("%1/s", "a transfer rate").arg(Strings.bytes(speed)));

        // TRANSLATORS: separates the parts of a download's status, e.g. "63% · 2.4 MB/s"
        return parts.join(Tr.trCtx(" · ", "separates status fields"));
    }

    spacing: Tokens.spacing.small

    StyledText {
        text: root.steam ? Tr.tr("Steam download") : Tr.tr("Download")
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.medium
    }

    StyledText {
        Layout.maximumWidth: root.nameWidth
        text: root.name
        color: Colours.palette.m3onSurface
        font: Tokens.font.label.large
        elide: Text.ElideRight
    }

    StyledProgressBar {
        id: bar

        Layout.fillWidth: true
        Layout.preferredWidth: 180
        Layout.topMargin: Tokens.spacing.extraSmall
        // An unknown total has no proportion to fill, so the bar sits empty rather than pretending
        // to be part way through
        value: root.known ? root.progress : 0
        fgColour: Colours.palette.m3primary
    }

    StyledText {
        text: root.status
        visible: text !== ""
        color: Colours.palette.m3onSurfaceVariant
        font: Tokens.font.label.small
    }

    StyledText {
        Layout.topMargin: Tokens.spacing.extraSmall
        visible: root.others > 0
        text: Tr.trCtx("%1 more downloading", "how many other downloads are running").arg(root.others)
        color: Colours.palette.m3outline
        font: Tokens.font.label.small
    }
}
