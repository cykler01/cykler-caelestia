import QtQuick

// the lock's glance chips: the wi-fi it is on and what is left in the battery,
// read off sysfs, the one place a greeter can see them. local reads need the
// greeter's QML_XHR_ALLOW_FILE_READ=1 (install-theme.sh); without it the
// machine's name stands in. the network's own name and its signal are not in
// sysfs at all, so they come from /run/caelestia-sddm/net.conf, which
// caelestia-sddm-net.timer keeps current; without that the chip knows only
// that wi-fi is up. the keymap joins when there is more than one. one
// connected group like the lock's, round at its ends and tight in between
Row {
    id: chips

    // where the net probe leaves what sysfs cannot say
    readonly property string netState: "/run/caelestia-sddm/net.conf"
    // a name older than this is from some other place, or some other day
    readonly property int netStaleMs: 300000

    property bool readable: true
    property string batPath: ""
    property string acPath: ""
    property bool hasBattery: false
    property int batteryPercent: 0
    property bool charging: false
    readonly property bool batteryLow: chips.hasBattery && !chips.charging && chips.batteryPercent <= 15
    property bool netKnown: false
    property bool ethernet: false
    property bool wifiUp: false
    // what the probe saw, when it is both there and recent
    property string ssid: ""
    // 0..1 of the link, or -1 for a link nobody has measured
    property real signalLevel: -1
    readonly property bool sysShown: chips.hasBattery || chips.netKnown
    // which chips show, in order, so each knows whether it closes the group
    readonly property var shown: {
        var s = [];
        if (chips.hasBattery)
            s.push("bat");

        if (chips.netKnown)
            s.push("net");

        if (!chips.sysShown && sddm.hostName !== "")
            s.push("host");

        if (chips.canCycle)
            s.push("kbd");

        return s;
    }

    // "" for a file that is not there; a refusal turns the polling off
    function read(path) {
        try {
            var x = new XMLHttpRequest();
            x.open("GET", "file://" + path, false);
            x.send();
            return String(x.responseText || "").trim();
        } catch (e) {
            chips.readable = false;
            return "";
        }
    }

    // the probe's ini, by hand: a name may hold an = of its own, so only the
    // first one separates
    function readNet() {
        var out = {};
        for (const line of chips.read(chips.netState).split("\n")) {
            const at = line.indexOf("=");
            if (at <= 0 || line[0] === "#" || line[0] === "[")
                continue;

            out[line.substring(0, at).trim()] = line.substring(at + 1).trim();
        }
        return out;
    }

    function poll() {
        if (chips.batPath === "") {
            for (const n of ["BAT0", "BAT1", "BAT2", "BATT", "BATC", "CMB0"]) {
                if (chips.read("/sys/class/power_supply/" + n + "/type") === "Battery") {
                    chips.batPath = "/sys/class/power_supply/" + n;
                    break;
                }
            }
        }
        if (chips.acPath === "") {
            for (const n of ["AC", "ACAD", "AC0", "ADP0", "ADP1"]) {
                if (chips.read("/sys/class/power_supply/" + n + "/type") === "Mains") {
                    chips.acPath = "/sys/class/power_supply/" + n;
                    break;
                }
            }
        }
        if (!chips.readable)
            return ;

        if (chips.batPath !== "") {
            const cap = parseInt(chips.read(chips.batPath + "/capacity"));
            const st = chips.read(chips.batPath + "/status");
            chips.hasBattery = !isNaN(cap);
            chips.batteryPercent = isNaN(cap) ? 0 : Math.max(0, Math.min(100, cap));
            // what upower calls charging or fully charged, as the lock reads it:
            // held at its limit on mains power is fully charged to upower
            const mains = chips.acPath !== "" && chips.read(chips.acPath + "/online") === "1";
            chips.charging = st === "Charging" || st === "Full" || (st === "Not charging" && mains);
        }
        var any = false, eth = false, wifi = false, wlan = "";
        for (const line of chips.read("/proc/net/dev").split("\n").slice(2)) {
            const name = line.split(":")[0].trim();
            if (name === "" || name === "lo")
                continue;

            any = true;
            if (chips.read("/sys/class/net/" + name + "/operstate") !== "up")
                continue;

            if (chips.read("/sys/class/net/" + name + "/uevent").indexOf("DEVTYPE=wlan") !== -1) {
                wifi = true;
                wlan = name;
            } else if (/^(en|eth)/.test(name)) {
                eth = true;
            }
        }
        chips.netKnown = any;
        chips.ethernet = eth;
        chips.wifiUp = wifi;

        // the name and the signal, if the probe is installed and has run lately
        // for the interface sysfs says is actually up
        var name = "", level = -1;
        if (wifi) {
            const n = chips.readNet();
            const at = parseInt(n.at);
            const fresh = !isNaN(at) && Date.now() - at * 1000 < chips.netStaleMs;
            if (fresh && n.state === "up" && (n.iface === undefined || n.iface === "" || n.iface === wlan)) {
                name = n.ssid || "";
                const pct = parseInt(n.signal);
                if (!isNaN(pct))
                    level = Math.max(0, Math.min(100, pct)) / 100;

            }
        }
        chips.ssid = name;
        chips.signalLevel = level;
    }

    readonly property var layouts: keyboard.layouts || []
    readonly property bool canCycle: chips.layouts.length > 1
    readonly property string layoutName: {
        var l = chips.layouts[keyboard.currentLayout];
        if (!l)
            return "";

        return l.longName !== undefined && l.longName !== "" ? l.longName : String(l.shortName || "").toUpperCase();
    }

    spacing: Theme.dp(3)

    Timer {
        running: chips.readable && chips.visible
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: chips.poll()
    }

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property string trail: ""
        property string glyph: ""
        // 0..1 fills the glyph from the bottom up, as a meter; -1 draws it whole
        property real level: -1
        property color tone: Theme.subtext
        property bool interactive: false
        property bool lead: false
        property bool tail: false

        signal activated()

        implicitWidth: row.implicitWidth + Theme.dp(32)
        implicitHeight: Theme.dp(40)
        color: Theme.card
        topLeftRadius: chip.lead ? height / 2 : Theme.shapeSm
        bottomLeftRadius: chip.lead ? height / 2 : Theme.shapeSm
        topRightRadius: chip.tail ? height / 2 : Theme.shapeSm
        bottomRightRadius: chip.tail ? height / 2 : Theme.shapeSm

        Rectangle {
            anchors.fill: parent
            topLeftRadius: parent.topLeftRadius
            bottomLeftRadius: parent.bottomLeftRadius
            topRightRadius: parent.topRightRadius
            bottomRightRadius: parent.bottomRightRadius
            color: Theme.text
            opacity: tap.pressed ? Theme.statePressed : (hover.hovered ? Theme.stateHover : 0)

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.ms(120)
                }

            }

        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Theme.dp(9)

            // the glyph, or the same glyph twice: a faint whole one with the
            // measured part of it laid over the top. a layer, because clip
            // alone does not hold a Shape in under the software renderer
            Item {
                id: mark

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: Theme.dp(18)
                implicitHeight: Theme.dp(18)
                visible: chip.glyph !== ""

                Glyph {
                    anchors.fill: parent
                    name: chip.glyph
                    size: Theme.dp(18)
                    color: chip.level >= 0 ? Theme.alpha(chip.tone, 0.3) : chip.tone
                }

                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    // the dot at the foot of the arcs is the floor: an empty
                    // meter is still a wi-fi symbol
                    height: Math.round(parent.height * (0.3 + 0.7 * Math.max(0, Math.min(1, chip.level))))
                    clip: true
                    layer.enabled: true
                    visible: chip.level >= 0

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.ms(320)
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.easeEmphasizedDecel
                        }

                    }

                    Glyph {
                        anchors.bottom: parent.bottom
                        width: mark.width
                        height: mark.height
                        name: chip.glyph
                        size: Theme.dp(18)
                        color: chip.tone
                    }

                }

            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // a network may be named anything at all, so it elides
                width: Math.min(implicitWidth, Theme.dp(170))
                text: chip.label
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
                visible: chip.label !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.trail
                color: Theme.subtextDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 420, 0)
                visible: chip.trail !== ""
            }

        }

        HoverHandler {
            id: hover

            // a pointer handler ignores Item.enabled unless told to
            enabled: chip.interactive && chip.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            id: tap

            enabled: chip.interactive
            onTapped: chip.activated()
        }

    }

    Chip {
        lead: chips.shown[0] === "bat"
        tail: chips.shown[chips.shown.length - 1] === "bat"
        visible: chips.hasBattery
        // the battery symbol that matches the level, in eighths like the bar's
        glyph: {
            if (chips.charging)
                return "battery_charging_full";

            const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar", "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
            return steps[Math.max(0, Math.min(7, Math.floor(chips.batteryPercent / 100 * 8)))];
        }
        label: chips.batteryPercent + "%"
        tone: chips.batteryLow ? Theme.error : (chips.charging ? Theme.success : Theme.subtext)
    }

    // the wi-fi: its name where the probe can see it, and the arcs filled to
    // the strength of the link. a machine on a cable says so instead
    Chip {
        lead: chips.shown[0] === "net"
        tail: chips.shown[chips.shown.length - 1] === "net"
        visible: chips.netKnown
        glyph: chips.wifiUp ? "signal" : (chips.ethernet ? "ethernet" : "wifiOff")
        level: chips.wifiUp ? chips.signalLevel : -1
        label: chips.wifiUp ? (chips.ssid !== "" ? chips.ssid : "Wi-Fi") : (chips.ethernet ? "Ethernet" : "Offline")
        trail: chips.wifiUp && chips.signalLevel >= 0 ? Math.round(chips.signalLevel * 100) + "%" : ""
        tone: (chips.ethernet || chips.wifiUp) ? Theme.accent : Theme.subtextDim
    }

    Chip {
        lead: chips.shown[0] === "host"
        tail: chips.shown[chips.shown.length - 1] === "host"
        glyph: "host"
        label: sddm.hostName
        visible: chips.shown.indexOf("host") !== -1
    }

    // one tap per layout, round and round
    Chip {
        lead: chips.shown[0] === "kbd"
        tail: true
        glyph: "keyboard"
        label: chips.layoutName
        interactive: true
        visible: chips.canCycle
        onActivated: keyboard.currentLayout = (keyboard.currentLayout + 1) % chips.layouts.length
    }

}
