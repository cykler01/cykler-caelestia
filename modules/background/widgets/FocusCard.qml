pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import qs.modules.background

// --- Focus timer ---
WidgetCard {
    title: Tr.tr("Focus")
    icon: "timer"

    Pomodoro {
        Layout.fillWidth: true
    }
}
