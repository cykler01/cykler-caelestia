pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property var lock

    spacing: Tokens.spacing.largeIncreased * 2

    WidgetColumn {
        side: "left"
        rootHeight: root.height
        lock: root.lock
    }

    Center {
        lock: root.lock
    }

    WidgetColumn {
        side: "right"
        rootHeight: root.height
        lock: root.lock
    }
}
