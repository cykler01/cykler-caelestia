pragma ComponentBehavior: Bound

import Caelestia.Config
import qs.components
import qs.services

// Just the notification dock's card chrome, pulled out so it's a uniform delegate alongside
// the other lock widgets (Resources, Battery, ...) instead of a one-off wrapper inline in Content.qml
StyledRect {
    id: root

    required property var lock

    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    NotifDock {
        lock: root.lock
    }
}
