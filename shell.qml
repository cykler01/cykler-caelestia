//@ pragma Env QS_CRASHREPORT_URL=https://github.com/caelestia-dots/shell/issues/new?template=crash.yml
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import "modules"
import "modules/drawers"
import "modules/background"
import "modules/areapicker"
import "modules/notifpopout"
import "modules/overview"
import "modules/polkit"
import "modules/todopopout"
import "modules/notepadpopout"
import "modules/lock"
import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.services
import qs.modules.areapicker
import qs.modules.background
import qs.modules.drawers
import qs.modules.lock
import qs.daemons

ShellRoot {
    id: root

    settings.watchFiles: false

    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily
        Notifs;
        NotchIsland;
        // NOTE(fork): nothing else holds a reference to the alarms until the timer panel is opened,
        // and a singleton nobody has asked for is never built - which would leave every alarm
        // waiting on someone to go and look at it before it could ring
        Alarms;
        Players;
        Brightness;
        Weather.reload();

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Modules

    // Scales continuous (trackpad) scroll deltas for every scrollable in the shell
    ScrollGain {}

    ServiceLoader {}
    // Asks for privileged actions in the shell's own prompt; see modules/polkit
    Polkit {}

    Background {}
    Drawers {}
    AreaPicker {}
    NotifPopout {}
    Overview {}
    TodoPopout {}
    NotepadPopout {}
    Lock {
        id: lock
    }

    // Daemons
    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
    WallpaperRotator {}
    MonitorIdentifier {
        id: monitorIdentifier
    }
}
