import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledText {
    // Lets the settings search tell the headers apart from the rows under them when
    // it walks a page looking for the row a result points at
    readonly property bool isSectionHeader: true

    property bool first

    Layout.fillWidth: true
    Layout.topMargin: first ? 0 : Tokens.spacing.largeIncreased - ((parent as ColumnLayout).spacing ?? 0)
    Layout.bottomMargin: Tokens.spacing.extraSmall
    Layout.leftMargin: Tokens.padding.small

    color: Colours.palette.m3onSurfaceVariant
    font: Tokens.font.label.medium
    elide: Text.ElideRight
}
