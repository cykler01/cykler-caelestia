import QtQuick
import Caelestia.Config
import qs.components
import qs.modules.lock.canvas

// Text set from the options every text-like element shares (ElementCatalog.textOptions): size,
// weight, colour, alignment, capitals, monospace and letter spacing
StyledText {
    id: root

    property real s: 1
    property var opts: ({})
    property var lock: null
    property string content

    readonly property var builders: {
        const f = root.opts.mono ? Tokens.font.mono : ({
                label: Tokens.font.label,
                body: Tokens.font.body,
                title: Tokens.font.title,
                headline: Tokens.font.headline,
                display: Tokens.font.headline
            })[root.opts.size] ?? Tokens.font.title;
        return f.builders;
    }
    readonly property real sizeFactor: root.opts.size === "display" ? 2.6 : 1
    readonly property int fontWeight: ({
            regular: Font.Normal,
            medium: Font.Medium,
            bold: Font.Bold
        })[root.opts.weight] ?? Font.Medium

    text: root.opts.uppercase ? root.content.toUpperCase() : root.content
    color: ElementCatalog.colour(root.opts.colour)
    horizontalAlignment: root.opts.align === "right" ? Text.AlignRight : root.opts.align === "center" ? Text.AlignHCenter : Text.AlignLeft
    font: root.builders.large.scale(root.s * root.sizeFactor).letterSpacing((root.opts.spacing ?? 0) * root.s).weight(root.fontWeight).build()
}
