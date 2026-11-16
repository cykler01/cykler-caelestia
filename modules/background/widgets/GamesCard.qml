pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.misc
import qs.services
import qs.modules.background

// --- Game library: the games installed through Steam, the last one played first ---
//
// The list comes from services/GameLibrary.qml, which reads Steam's own files and only does so while a
// card like this one is up. Clicking a game starts it through Steam.
WidgetCard {
    id: games

    // The featured style is a picture first, so it runs to the card's edges without the header
    readonly property bool featured: games.variant === "featured"
    readonly property var list: GameLibrary.games

    title: games.featured ? "" : Tr.tr("Game library")
    icon: games.featured ? "" : "sports_esports"
    padding: games.featured && games.list.length > 0 ? 0 : Tokens.padding.largeIncreased

    Ref {
        service: GameLibrary
    }

    // No Steam, an empty library, or the first scan still out: one quiet message in the middle of the card
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: games.list.length === 0
        spacing: Tokens.spacing.small

        Item {
            Layout.fillHeight: true
        }

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: GameLibrary.scanned && !GameLibrary.steamFound ? "videogame_asset_off" : "sports_esports"
            color: Colours.palette.m3outline
            fontStyle: Tokens.font.icon.large
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: {
                if (!GameLibrary.scanned)
                    return Tr.tr("Looking for games...");
                return GameLibrary.steamFound ? Tr.tr("No games installed") : Tr.tr("Steam isn't installed");
            }
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.title.small
        }

        StyledText {
            Layout.fillWidth: true
            visible: GameLibrary.scanned
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: GameLibrary.steamFound ? Tr.tr("Games you install through Steam show up here") : Tr.tr("Install Steam and your games show up here")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Item {
            Layout.fillHeight: true
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: games.list.length > 0
        visible: active

        sourceComponent: {
            if (games.variant === "list")
                return listStyle;
            if (games.featured)
                return featuredStyle;
            return shelfStyle;
        }
    }

    Component {
        id: shelfStyle

        GamesShelf {
            games: games.list
        }
    }

    Component {
        id: listStyle

        GamesList {
            games: games.list
        }
    }

    Component {
        id: featuredStyle

        GamesFeatured {
            games: games.list
            radius: games.radius
        }
    }
}
