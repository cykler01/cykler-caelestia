import QtQuick
import Caelestia.Config
import qs.services

ColorAnimation {
    duration: PowerSaving.animations ? Tokens.anim.durations.expressiveSlowEffects : 0
    easing: Tokens.anim.expressiveSlowEffects
}
