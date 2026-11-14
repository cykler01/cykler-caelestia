import "installer"
import QtQuick
import Quickshell
import Quickshell.Io

// the graphical installer, opened by ./install.sh --gui. its switches become
// install.sh's own flags and the run is runner.py's, so it asks exactly what
// the terminal would
//
//   qs -p ./installer.qml
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")

    // each switch is a flag when it is off, so the default run passes nothing
    // what the build makes. these are always the same, so they live here
    readonly property var baseChoices: [{
        "flag": "--install-deps false",
        "icon": "package_2",
        "label": "Dependencies",
        "sub": "Qt, quickshell, the fonts and the CLI tools"
    }, {
        "flag": "--repo-only",
        "icon": "deployed_code",
        "label": "AUR packages",
        "sub": "quickshell-git, caelestia-cli and the fonts",
        "needs": "--install-deps false",
        "needsText": "Comes with the dependencies"
    }, {
        "module": "shell",
        "icon": "dashboard",
        "label": "The shell",
        "sub": "The QML: bar, notch, launcher, dashboard, lock"
    }, {
        "module": "plugin",
        "icon": "extension",
        "label": "The plugin",
        "sub": "The C++ side: images, audio, config, shaders"
    }, {
        "module": "extras",
        "icon": "build",
        "label": "Extras",
        "sub": "The version helper the shell reports itself with"
    }]

    // the add-ons come from install.sh itself (--list-addons), so adding one
    // there puts a switch here with no second list to keep in step. none of
    // them is on until it is picked: each writes somewhere the shell's own
    // install would not touch
    property var addons: []

    readonly property var choices: root.baseChoices.concat(root.addons)

    readonly property var addonIcons: ({
            "login-screen": "login"
        })

    // what install.sh was given besides --gui
    readonly property var given: (Quickshell.env("CYKLER_INSTALL_ARGS") || "").split(" ").filter(a => a !== "")

    // the flags of whatever was switched off, starting from the command line
    property var off: root.baseChoices.filter(c => !!c.flag && (c.off === true || root.given.join(" ").indexOf(c.flag) !== -1)).map(c => c.flag)
    // the add-ons picked, seeded from whatever --with was already given
    property var addonsOn: {
        const out = [];
        for (let i = 0; i < root.given.length; i++) {
            const a = root.given[i];
            let list = "";
            if (a.startsWith("--with="))
                list = a.slice(7);
            else if (a === "--with" && i + 1 < root.given.length)
                list = root.given[i + 1];
            else if (a === "--login-screen")
                list = "login-screen";
            list.split(",").filter(n => n !== "").forEach(n => out.indexOf(n) === -1 && out.push(n));
        }
        return out;
    }
    // modules start on; switching one off drops it from --modules
    property var modsOff: []

    // quickshell-git, which the stable quickshell cannot stand in for
    property bool qsGit: true
    // an AUR build of the same shell, which has to go first
    property string conflict: ""
    // the sddm theme in use now, "" when sddm names none
    property string sddmTheme: ""
    // the desktop this opened on, when it is not Hyprland
    readonly property string desktop: Quickshell.env("XDG_CURRENT_DESKTOP") || ""
    readonly property string elsewhere: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ? "" : (root.desktop.split(":").pop() || "another desktop")

    readonly property bool running: Install.phase !== ""

    function locked(c): bool {
        return !!c.needs && root.off.indexOf(c.needs) !== -1;
    }

    function isOn(c): bool {
        if (c.module)
            return root.modsOff.indexOf(c.module) === -1;
        if (c.addon)
            return root.addonsOn.indexOf(c.addon) !== -1;
        return root.off.indexOf(c.flag) === -1 && !root.locked(c);
    }

    function toggle(c): void {
        if (c.module) {
            root.modsOff = root.modsOff.indexOf(c.module) === -1 ? root.modsOff.concat([c.module]) : root.modsOff.filter(m => m !== c.module);
            return;
        }
        if (c.addon) {
            root.addonsOn = root.addonsOn.indexOf(c.addon) === -1 ? root.addonsOn.concat([c.addon]) : root.addonsOn.filter(a => a !== c.addon);
            return;
        }
        root.off = root.off.indexOf(c.flag) === -1 ? root.off.concat([c.flag]) : root.off.filter(f => f !== c.flag);
    }

    function subOf(c): string {
        if (c.addon === "login-screen")
            return root.sddmTheme === "" ? "Installs the sddm theme, from your next login" : root.sddmTheme === "cykler-caelestia" ? "Updates the sddm theme you already have" : "Replaces " + root.sddmTheme + " as your login screen";
        if (c.flag === "--repo-only" && !root.qsGit && root.isOn(c))
            return "Installs quickshell-git, which the shell needs";
        if (c.module === "plugin" && !root.isOn(c))
            return "Without it the shell will not start";
        return c.sub;
    }

    // the switches as install.sh's own flags; anything else from the command
    // line (-y and friends) rides along
    function install(): void {
        const mine = root.choices.filter(c => !!c.flag).map(c => c.flag).concat(root.choices.filter(c => !!c.onFlag).map(c => c.onFlag));
        let args = root.given.join(" ");
        mine.forEach(f => args = args.replace(f, ""));
        let out = args.split(" ").filter(a => a !== "");
        // the add-ons are settled here, so whatever the command line said about
        // them is dropped rather than fighting the switches
        const kept = [];
        for (let i = 0; i < out.length; i++) {
            const a = out[i];
            if (a === "--with" || a === "--without") {
                i++;
                continue;
            }
            if (a.startsWith("--with=") || a.startsWith("--without=") || a === "--login-screen" || a === "--no-login-screen")
                continue;
            kept.push(a);
        }
        out = kept;
        if (root.addonsOn.length > 0) {
            out.push("--with");
            out.push(root.addonsOn.join(","));
        }
        root.choices.forEach(c => {
            if (!c.flag)
                return;
            if (root.isOn(c)) {
                if (c.onFlag)
                    out.push(c.onFlag);
                return;
            }
            c.flag.split(" ").forEach(part => out.push(part));
        });
        if (root.modsOff.length > 0) {
            const on = root.choices.filter(c => !!c.module && root.isOn(c)).map(c => c.module);
            out.push("--modules");
            out.push(on.join(";"));
        }
        Install.start(out);
    }

    // the shell starts the way the session would start it
    function leave(start: bool): void {
        if (start && root.elsewhere !== "") {
            Quickshell.execDetached(["sh", "-c", "loginctl terminate-session \"${XDG_SESSION_ID:-auto}\""]);
            return;
        }
        if (start)
            Quickshell.execDetached(["caelestia", "shell", "-d"]);
        Qt.quit();
    }

    // the run outlives the window, but a question waits for an answer
    function windowClosed(): void {
        if (Install.running)
            Quickshell.execDetached(["sh", "-c", "command -v notify-send >/dev/null && notify-send -a Caelestia \"$1\" \"$2\"", "sh", "Caelestia is still installing", "Open the installer again (./install.sh --gui) to see it. If it asks something, it waits there for your answer."]);
        Qt.quit();
    }

    // the add-ons install.sh knows about: name, label, summary, what it writes
    Process {
        running: true
        command: ["sh", "-c", "cd \"$1\" && ./install.sh --list-addons", "sh", Install.src]

        stdout: StdioCollector {
            onStreamFinished: {
                root.addons = this.text.split("\n").filter(l => l.indexOf("\t") !== -1).map(l => {
                    const f = l.split("\t");
                    return {
                        "addon": f[0],
                        "icon": root.addonIcons[f[0]] ?? "add_circle",
                        "label": f[1],
                        "sub": f[2],
                        "paths": f[3]
                    };
                });
            }
        }
    }

    // the same tests install.sh makes, so the switches can say what will happen
    Process {
        running: true
        command: ["sh", "-c", "pacman -Qq quickshell-git >/dev/null 2>&1 && echo qsgit; for p in caelestia-shell caelestia-shell-git; do pacman -Qq \"$p\" >/dev/null 2>&1 && echo \"conflict:$p\"; done; t=\"\"; for f in /etc/sddm.conf /etc/sddm.conf.d/*.conf; do [ -f \"$f\" ] || continue; l=$(sed -n '/^\\[Theme\\]/,/^\\[/s/^[[:space:]]*Current=//p' \"$f\" | tail -1); [ -n \"$l\" ] && t=$l; done; [ -n \"$t\" ] && echo \"sddm:$t\""]

        stdout: StdioCollector {
            onStreamFinished: {
                const got = this.text.split("\n");
                root.qsGit = got.indexOf("qsgit") !== -1;
                root.conflict = (got.find(l => l.startsWith("conflict:")) || "").slice(9);
                root.sddmTheme = (got.find(l => l.startsWith("sddm:")) || "").slice(5).trim();
            }
        }
    }

    FloatingWindow {
        id: win

        title: "Install cykler-caelestia"
        implicitHeight: welcome.implicitHeight + Theme.dp(64)
        implicitWidth: Math.min(side.width + Theme.dp(44) + Math.round((win.implicitHeight - Theme.dp(32) - tour.footHeight) * 16 / 9), (win.screen ? win.screen.width : 1920) - Theme.dp(80))
        // one size: Hyprland floats a window that cannot be resized
        minimumSize: Qt.size(win.implicitWidth, win.implicitHeight)
        maximumSize: Qt.size(win.implicitWidth, win.implicitHeight)
        color: Theme.bg
        onClosed: root.windowClosed()

        FontLoader {
            source: Qt.resolvedUrl("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
        }

        Tour {
            id: tour

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: side.left
            anchors.margins: Theme.dp(16)
            anchors.leftMargin: Theme.dp(28)
            anchors.rightMargin: Theme.dp(4)
        }

        Item {
            id: side

            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Theme.dp(470)
            focus: true
            Keys.onEscapePressed: {
                if (root.running)
                    card.dismiss();
                else
                    Qt.quit();
            }

            // a taste of the shell: the whole window goes light or dark
            IconButton {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Theme.dp(28)
                z: 1
                icon: Theme.isLight ? "dark_mode" : "light_mode"
                tooltip: Theme.isLight ? "Dark mode" : "Light mode"
                onClicked: Theme.mode = Theme.isLight ? "dark" : "light"
            }

            // the choices, until Install
            Column {
                id: welcome

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.dp(32)
                spacing: Theme.dp(6)
                opacity: root.running ? 0 : 1
                visible: opacity > 0
                enabled: !root.running

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durShort
                    }
                }

                Row {
                    spacing: Theme.dp(14)

                    Logo {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dp(46)
                        height: Theme.dp(46)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "cykler-caelestia"
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontHeadlineLg
                        font.variableAxes: Theme.axes(Theme.fontHeadlineLg, 560, 0)
                        font.weight: Font.DemiBold
                    }
                }

                Item {
                    width: 1
                    height: Theme.dp(4)
                }

                Text {
                    width: parent.width
                    text: root.conflict !== "" ? root.conflict + " is installed and provides the same shell. The installer removes it first, and asks before it does." : "Pick what comes with it. The installer asks before anything big, and nothing here cannot be run again."
                    color: root.conflict !== "" ? Theme.error : Theme.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBodyMd
                    lineHeight: 1.35
                    wrapMode: Text.WordWrap
                }

                Item {
                    width: 1
                    height: Theme.dp(12)
                }

                Column {
                    width: parent.width
                    // tight enough that the rows read as one group, not five tiles
                    spacing: Theme.dp(3)

                Repeater {
                    model: root.choices

                    Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool locked: root.locked(modelData)

                        readonly property int tight: Theme.dp(6)
                        readonly property int round: Theme.dp(20)

                        width: parent.width
                        height: Theme.dp(54)
                        // only the group's outer corners are rounded: every row
                        // taking all four made the strip read as loose tiles
                        topLeftRadius: index === 0 ? round : tight
                        topRightRadius: index === 0 ? round : tight
                        bottomLeftRadius: index === root.choices.length - 1 ? round : tight
                        bottomRightRadius: index === root.choices.length - 1 ? round : tight
                        color: rowArea.containsMouse && !row.locked ? Theme.bgHigh : Theme.bgTile
                        opacity: row.locked ? 0.5 : 1

                        MouseArea {
                            id: rowArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.locked ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                if (!row.locked)
                                    root.toggle(row.modelData);
                            }
                        }

                        Icon {
                            id: rowIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Theme.dp(18)
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon
                            size: Theme.dp(20)
                            color: root.isOn(row.modelData) ? Theme.accent : Theme.subtextDim
                        }

                        Column {
                            anchors.left: rowIcon.right
                            anchors.leftMargin: Theme.dp(14)
                            anchors.right: sw.left
                            anchors.rightMargin: Theme.dp(12)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.dp(2)

                            Text {
                                text: row.modelData.label
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodyLg
                                font.variableAxes: Theme.axes(Theme.fontBodyLg, 480, 0)
                            }

                            Text {
                                width: parent.width
                                text: !row.locked ? root.subOf(row.modelData) : row.modelData.needsText
                                color: row.modelData.module === "plugin" && !root.isOn(row.modelData) ? Theme.error : Theme.subtextDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBodySm
                                elide: Text.ElideRight
                            }
                        }

                        Switch {
                            id: sw

                            anchors.right: parent.right
                            anchors.rightMargin: Theme.dp(16)
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.isOn(row.modelData)
                            disabled: row.locked
                            onToggled: root.toggle(row.modelData)
                        }
                    }
                }
                }

                Item {
                    width: parent.width
                    height: Theme.dp(64)

                    Row {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        spacing: Theme.dp(8)

                        Button {
                            text: "Quit"
                            variant: "text"
                            onClicked: Qt.quit()
                        }

                        Button {
                            text: "Install"
                            variant: "filled"
                            icon: "download"
                            onClicked: root.install()
                        }
                    }
                }
            }

            // from the password on
            InstallCard {
                id: card

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                shown: root.running
                elsewhere: root.elsewhere
                onLeave: start => root.leave(start)
            }
        }
    }
}
