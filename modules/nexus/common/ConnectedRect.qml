import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    // The name the settings search knows this row by, so a result can scroll to it
    // and flash it. Blank on the rects used purely as backgrounds.
    property string searchLabel

    property bool first
    property bool last

    color: Colours.tPalette.m3surfaceContainer
    topLeftRadius: first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    topRightRadius: first ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomLeftRadius: last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
    bottomRightRadius: last ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
}
