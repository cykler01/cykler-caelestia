import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.lock.center
import qs.modules.lock.canvas

// NOTE(fork): "Good morning, Name". Two styles: the original pill, worded as set under Nexus >
// Lock screen > Greeting and scaled as a whole; or plain text in the element's own wording, styled
// like any other text on the lock (size, weight, colour, alignment and the rest), with the name
// taken from the account (login, full or first name) or a nickname, optionally in the accent
// colour, and optionally the time of day's icon in front.
//
// The pill is the default, so layouts saved before the text style existed look as they did; a
// greeting added from the editor starts out as text (ElementCatalog.create)
Item {
    id: root

    property real s: 1

    property var opts: ({})

    property var lock: null

    readonly property bool pill: (root.opts.style ?? "pill") === "pill"

    // Who's being greeted: a nickname if one's set, otherwise the account's name as asked for
    readonly property string name: {
        const nick = (root.opts.nickname ?? "").trim();
        if (nick !== "")
            return nick;
        const full = SysInfo.realName !== "" ? SysInfo.realName : SysInfo.user;
        if (root.opts.name === "full")
            return full;
        if (root.opts.name === "first")
            return full.split(/\s+/)[0];
        return SysInfo.user;
    }

    readonly property string wording: (root.opts.wording ?? "").trim() !== "" ? root.opts.wording : "{greeting}, {name}"

    // The wording with its tokens filled in, as styled text: everything put in capitals here if
    // asked (TextBlock would put the markup in capitals too) and escaped, then the name put in, in
    // the accent colour if asked
    readonly property string rich: {
        const caps = t => root.opts.uppercase ? t.toUpperCase() : t;
        const esc = t => caps(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const who = root.opts.accentName ? `<font color="${Colours.palette.m3primary}">${esc(root.name)}</font>` : esc(root.name);
        return esc(root.wording).replace(/\{GREETING\}|\{greeting\}/g, esc(pillGreeting.periodGreeting)).replace(/\{(name|user|NAME|USER)\}/g, who);
    }
    // The size the text is drawn at, for the icon beside it
    readonly property real textPoints: label.font.pointSize > 0 ? label.font.pointSize : label.font.pixelSize * 0.75

    implicitWidth: root.pill ? pillGreeting.implicitWidth * root.s : row.implicitWidth
    implicitHeight: root.pill ? pillGreeting.implicitHeight * root.s : row.implicitHeight

    // The original pill. Kept even in the text style, which borrows its time of day and wording
    Greeting {
        id: pillGreeting

        visible: root.pill
        scale: root.s
        transformOrigin: Item.TopLeft
    }

    Row {
        id: row

        visible: !root.pill
        spacing: root.textPoints * 0.4

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.opts.icon
            text: pillGreeting.periodIcon
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.size(Math.max(1, root.textPoints)).build()
        }

        TextBlock {
            id: label

            s: root.s
            opts: Object.assign({}, root.opts, {
                uppercase: false
            })
            textFormat: Text.StyledText
            content: root.rich
        }
    }
}
