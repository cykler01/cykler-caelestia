import QtQuick

// the lock's glance chips: battery, network and bluetooth, read off sysfs,
// the one place a greeter can see them. local reads need the greeter's
// QML_XHR_ALLOW_FILE_READ=1 (install-theme.sh); without it the machine's name
// stands in. the keymap joins when there is more than one. one connected
// group like the lock's, round at its ends and tight in between
Row {
    id: chips

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
    // -1 no adapter, 0 off, 1 on
    property int btState: -1
    readonly property bool sysShown: chips.hasBattery || chips.netKnown || chips.btState >= 0
    // which chips show, in order, so each knows whether it closes the group
    readonly property var shown: {
        var s = [];
        if (chips.hasBattery)
            s.push("bat");

        if (chips.netKnown)
            s.push("net");

        if (chips.btState >= 0)
            s.push("bt");

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
        var any = false, eth = false, wifi = false;
        for (const line of chips.read("/proc/net/dev").split("\n").slice(2)) {
            const name = line.split(":")[0].trim();
            if (name === "" || name === "lo")
                continue;

            any = true;
            if (chips.read("/sys/class/net/" + name + "/operstate") !== "up")
                continue;

            if (chips.read("/sys/class/net/" + name + "/uevent").indexOf("DEVTYPE=wlan") !== -1)
                wifi = true;
            else if (/^(en|eth)/.test(name))
                eth = true;
        }
        chips.netKnown = any;
        chips.ethernet = eth;
        chips.wifiUp = wifi;
        var bt = -1;
        for (var i = 0; i < 32; i++) {
            if (chips.read("/sys/class/rfkill/rfkill" + i + "/type") === "bluetooth")
                bt = Math.max(bt, chips.read("/sys/class/rfkill/rfkill" + i + "/state") === "1" ? 1 : 0);

        }
        chips.btState = bt;
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
        property string glyph: ""
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

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: chip.glyph
                size: Theme.dp(18)
                color: chip.tone
                visible: chip.glyph !== ""
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabelLg
                font.variableAxes: Theme.axes(Theme.fontLabelLg, 520, 0)
                font.weight: Font.Medium
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

    // sysfs has no network name, so wi-fi is only ever "Wi-Fi"
    Chip {
        lead: chips.shown[0] === "net"
        tail: chips.shown[chips.shown.length - 1] === "net"
        visible: chips.netKnown
        glyph: chips.ethernet ? "ethernet" : (chips.wifiUp ? "wifi" : "wifiOff")
        label: chips.ethernet ? "Ethernet" : (chips.wifiUp ? "Wi-Fi" : "Offline")
        tone: (chips.ethernet || chips.wifiUp) ? Theme.accent : Theme.subtextDim
    }

    // rfkill: whether the radio is on, not what is paired to it
    Chip {
        lead: chips.shown[0] === "bt"
        tail: chips.shown[chips.shown.length - 1] === "bt"
        visible: chips.btState >= 0
        glyph: chips.btState === 1 ? "bluetooth" : "bluetoothOff"
        label: chips.btState === 1 ? "Bluetooth on" : "Bluetooth off"
        tone: Theme.subtextDim
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
