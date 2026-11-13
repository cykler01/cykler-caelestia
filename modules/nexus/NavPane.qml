import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus
import qs.modules.nexus.navpane

ColumnLayout {
    id: root

    required property NexusState nState

    spacing: Tokens.spacing.large

    SearchBar {
        id: searchField

        Layout.fillWidth: true

        placeholderText: Tr.tr("Search settings")
        font: Tokens.font.body.large

        bg.color: Colours.tPalette.m3surfaceContainerLowest
        bg.border.color: Colours.palette.m3outlineVariant
        searchIcon.fontStyle: Tokens.font.icon.medium
        searchIcon.anchors.leftMargin: Tokens.padding.largeIncreased
        clearIcon.font: Tokens.font.icon.medium
        clearIcon.padding: Tokens.padding.extraSmall

        // Drawn above the list, so it stays a glass header rather than getting hidden
        // behind items that scroll up past it
        z: 1

        // Escape backs out of the search: it empties the field, which puts the page list
        // back, and hands the focus over. With nothing typed there is nothing to back out
        // of, so the press is left for whatever else wants it
        Keys.onEscapePressed: event => {
            if (!searchField.text) {
                event.accepted = false;
                return;
            }

            searchField.text = "";
            searchField.focus = false;
        }

        Behavior on bg.border.color {
            CAnim {}
        }

        Binding {
            target: root.nState
            property: "searchOpen"
            value: searchField.text.length > 0
        }

        Binding {
            target: root.nState
            property: "searchQuery"
            value: searchField.text
        }
    }

    NavLocations {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: -topMargin
        Layout.bottomMargin: -bottomMargin
        nState: root.nState
    }

}
