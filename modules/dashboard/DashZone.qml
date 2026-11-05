pragma ComponentBehavior: Bound

import "dash"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services

// One of the home page's four places - the top row, the bottom row, or a full-height column to
// either side of them - holding whichever cards are assigned to it, in the order the settings
// editor (Nexus > Panels > Dashboard > Widgets) put them in.
//
// The rows size themselves the way the fixed grid this page used to be did: the cards with a
// height of their own (the weather and the calendar) set how tall their row is, and everything
// else in it stretches to match. A card with no height of its own still asks for a minimum, so
// a row holding only those does not collapse.
//
// With `editing` set it is also the settings page's editor: the same real cards, with a grab
// handle over each, an empty drop area where a place has nothing in it, and a caret showing
// where a dragged card would land. `editController` is the DashPreview driving that (see
// modules/nexus/common/DashPreview.qml); everything here is inert without one.
Item {
    id: zone

    required property string zoneId
    // Full-height columns stack their cards; the rows lay them out left to right
    required property bool vertical
    required property ScreenState screenState
    required property FileDialog facePicker

    // Set by the settings preview, never on the real page
    property bool editing: false
    property var editController: null
    // How far down the preview has scaled the page, so the controls drawn over each card can be
    // scaled back up and stay their proper size
    property real editScale: 1

    // Ids this page knows how to render - anything else in the config (a card removed from the
    // code, say) is skipped rather than falling through the DelegateChooser below
    readonly property var knownIds: ["weather", "clock", "profile", "calendar", "resources", "media"]

    // Every entry's enabled/zone is read here so this is worked out again whenever one changes,
    // the same trick the lock screen's WidgetColumn uses
    readonly property var items: {
        const entries = Config.dashboard.widgets.values;
        for (const e of entries)
            void [e.enabled, e.zone];
        return entries.filter(e => e.enabled && e.zone === zone.zoneId && zone.knownIds.includes(e.id));
    }

    readonly property bool empty: zone.items.length === 0

    // What an empty place takes up while editing, so there is something to drop onto
    readonly property real emptyWidth: Tokens.sizes.dashboard.dateTimeWidth
    readonly property real emptyHeight: Tokens.sizes.dashboard.homeProfileMinHeight

    // How much height this zone needs: the tallest card in a row, or all of them stacked in a
    // column. Read off the cards rather than the config so one that hides itself asks for
    // nothing, and so the ones sized by their own content are measured rather than guessed
    readonly property real naturalHeight: {
        if (zone.empty)
            return zone.editing ? zone.emptyHeight : 0;

        let total = 0;
        let tallest = 0;
        let count = 0;
        for (const card of zone.cards()) {
            total += card.cardHeight;
            tallest = Math.max(tallest, card.cardHeight);
            ++count;
        }
        return zone.vertical ? total + Math.max(0, count - 1) * grid.rowSpacing : tallest;
    }

    // Where the caret sits when a dragged card would land here, along whichever axis this zone
    // runs; -1 when it would not
    readonly property int dropIndex: zone.editController && zone.editController.dropZone === zone.zoneId ? zone.editController.dropIndex : -1

    readonly property real caretPos: {
        const cards = zone.cards();
        if (zone.dropIndex < 0)
            return 0;
        if (cards.length === 0)
            return (zone.vertical ? zone.height : zone.width) / 2;
        if (zone.dropIndex >= cards.length) {
            const last = cards[cards.length - 1];
            return zone.vertical ? last.y + last.height : last.x + last.width;
        }
        const card = cards[zone.dropIndex];
        return zone.vertical ? card.y : card.x;
    }

    // The card items, in the order they are laid out
    function cards(): var {
        const found = [];
        for (const child of grid.children) {
            const it = child as Item;
            if (it && it.visible && it.cardHeight !== undefined)
                found.push(it);
        }
        return found;
    }

    // How many cards a drop at `pt` (this zone's coordinates) falls after. Only the axis the
    // zone runs along matters, since a zone is one card across
    function insertIndexAt(pt: point): int {
        const cards = zone.cards();
        const p = zone.vertical ? pt.y : pt.x;
        for (let i = 0; i < cards.length; i++) {
            const card = cards[i];
            const centre = zone.vertical ? card.y + card.height / 2 : card.x + card.width / 2;
            if (p < centre)
                return i;
        }
        return cards.length;
    }

    implicitWidth: zone.empty && zone.editing ? (zone.vertical ? zone.emptyWidth : 0) : grid.implicitWidth
    implicitHeight: zone.empty && zone.editing ? zone.emptyHeight : grid.implicitHeight

    // Stands in for a place with nothing in it, so a card can be dragged into one
    StyledRect {
        anchors.fill: parent
        visible: zone.editing && zone.empty

        radius: Tokens.rounding.extraLarge
        color: zone.dropIndex >= 0 ? Qt.alpha(Colours.palette.m3primary, 0.15) : Qt.alpha(Colours.palette.m3surfaceContainer, 0.4)
        border.width: 2
        border.color: zone.dropIndex >= 0 ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outlineVariant, 0.8)

        Behavior on color {
            CAnim {}
        }

        Behavior on border.color {
            CAnim {}
        }

        // Scaled back up so it reads at the preview's size rather than the page's
        MaterialIcon {
            anchors.centerIn: parent

            scale: 1 / Math.max(0.01, zone.editScale)
            text: "add"
            color: zone.dropIndex >= 0 ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.8)
            fontStyle: Tokens.font.icon.small
        }
    }

    GridLayout {
        id: grid

        anchors.fill: parent

        flow: zone.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        columns: zone.vertical ? 1 : Math.max(1, zone.items.length)
        rows: zone.vertical ? Math.max(1, zone.items.length) : 1
        rowSpacing: Tokens.spacing.medium
        columnSpacing: Tokens.spacing.medium

        Repeater {
            model: zone.items

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "weather"

                    delegate: Card {
                        required property var modelData

                        cardId: "weather"
                        cardHeight: weather.implicitHeight

                        Layout.preferredWidth: Tokens.sizes.dashboard.weatherWidth

                        SmallWeather {
                            id: weather
                        }
                    }
                }

                DelegateChoice {
                    roleValue: "clock"

                    delegate: Card {
                        required property var modelData

                        cardId: "clock"
                        // The stacked readout clips below a certain height, and unlike the
                        // weather or calendar the card never sets its row's height - so this is
                        // a floor it asks for, not the height it takes
                        cardHeight: Math.max(Tokens.sizes.dashboard.homeClockMinHeight, dateTime.implicitHeight)

                        Layout.preferredWidth: dateTime.implicitWidth

                        DateTime {
                            id: dateTime
                        }
                    }
                }

                DelegateChoice {
                    roleValue: "profile"

                    delegate: Card {
                        required property var modelData

                        cardId: "profile"
                        cardHeight: Tokens.sizes.dashboard.homeProfileMinHeight

                        Layout.fillWidth: true
                        Layout.preferredWidth: Tokens.sizes.dashboard.userWidth

                        User {
                            screenState: zone.screenState
                            facePicker: zone.facePicker
                        }
                    }
                }

                DelegateChoice {
                    roleValue: "calendar"

                    delegate: Card {
                        required property var modelData

                        cardId: "calendar"
                        cardHeight: calendar.implicitHeight

                        Layout.fillWidth: true
                        Layout.preferredWidth: Tokens.sizes.dashboard.calendarWidth

                        Calendar {
                            id: calendar

                            screenState: zone.screenState
                        }
                    }
                }

                DelegateChoice {
                    roleValue: "resources"

                    delegate: Card {
                        required property var modelData

                        cardId: "resources"
                        cardHeight: Tokens.sizes.dashboard.homeResourcesMinHeight

                        // The rings scale with the height they are given, so the card is as wide
                        // as whatever row it landed in makes it
                        Layout.preferredWidth: resources.implicitWidth

                        Resources {
                            id: resources
                        }
                    }
                }

                DelegateChoice {
                    roleValue: "media"

                    delegate: Card {
                        required property var modelData

                        cardId: "media"
                        cardHeight: Tokens.sizes.dashboard.homeMediaMinHeight

                        Layout.preferredWidth: media.implicitWidth

                        Media {
                            id: media
                        }
                    }
                }
            }
        }
    }

    // Where a dragged card would land, drawn over the gap it would go into
    StyledRect {
        visible: zone.dropIndex >= 0 && !zone.empty

        x: zone.vertical ? 0 : zone.caretPos - width / 2
        y: zone.vertical ? zone.caretPos - height / 2 : 0
        implicitWidth: zone.vertical ? zone.width : 6
        implicitHeight: zone.vertical ? 6 : zone.height

        radius: Tokens.rounding.full
        color: Colours.palette.m3primary

        Behavior on x {
            Anim {}
        }

        Behavior on y {
            Anim {}
        }
    }

    // Every card on the page is the same shape: one rounded surface, filling the height its
    // zone gives it. `cardHeight` is what it asks for when nothing else decides that
    component Card: StyledRect {
        id: card

        required property real cardHeight
        required property string cardId

        readonly property bool dragged: zone.editController?.draggingId === card.cardId

        Layout.fillHeight: true

        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
        // The card stays where it is while it is dragged; this and the caret are what say it is
        // being moved, rather than tearing the preview's layout apart mid-drag
        opacity: card.dragged ? 0.4 : 1

        Behavior on opacity {
            Anim {}
        }

        // Everything below only exists in the settings preview
        StyledRect {
            id: grab

            anchors.fill: parent
            visible: zone.editing
            z: 10

            radius: card.radius
            color: grabMouse.containsMouse || card.dragged ? Qt.alpha(Colours.palette.m3primary, 0.12) : "transparent"
            border.width: grabMouse.containsMouse || card.dragged ? 2 : 0
            border.color: Colours.palette.m3primary

            Behavior on color {
                CAnim {}
            }

            MouseArea {
                id: grabMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: card.dragged ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                // The preview sits in the settings page's scroll view, which would otherwise
                // take any drag with a vertical component and scroll the page with it
                preventStealing: true

                onPressed: e => zone.editController?.beginDrag(card.cardId, grabMouse, e.x, e.y)
                onPositionChanged: e => {
                    if (grabMouse.pressed)
                        zone.editController?.moveDrag(grabMouse, e.x, e.y);
                }
                onReleased: zone.editController?.endDrag()
                onCanceled: zone.editController?.cancelDrag()
            }

            // Only on the card under the pointer: six of these at once buries the preview it
            // is meant to be sitting on top of. Scaled back up so it stays a normal-sized
            // button however far down the preview has shrunk the page
            IconButton {
                id: removeButton

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.padding.small

                scale: 1 / Math.max(0.01, zone.editScale)
                transformOrigin: Item.TopRight
                opacity: grabMouse.containsMouse && !card.dragged ? 1 : 0
                visible: removeButton.opacity > 0

                type: IconButton.Tonal
                icon: "close"
                font: Tokens.font.icon.small
                isRound: true
                inactiveColour: Colours.palette.m3surfaceContainerHighest
                inactiveOnColour: Colours.palette.m3onSurfaceVariant
                onClicked: zone.editController?.removeCard(card.cardId)

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
            }
        }
    }
}
