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
import "modules/todopopout"
import "modules/notepadpopout"
import "modules/lock"
import "modules/standby"
import QtQuick
import Quickshell
import Caelestia
import qs.services

ShellRoot {
    id: root

    settings.watchFiles: false

    Binding {
        target: ShellState
        property: "shellRoot"
        value: root
    }

    // Scales continuous (trackpad) scroll deltas for every scrollable in the shell
    ScrollGain {}

    GSFLoader {}
    ServiceLoader {}

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
    Standby {}

    Shortcuts {}
    BatteryMonitor {}
    IdleMonitors {
        lock: lock
    }
    MonitorIdentifier {
        id: monitorIdentifier
    }
}
