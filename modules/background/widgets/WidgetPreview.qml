pragma ComponentBehavior: Bound

import "../../../utils/widgetgrid.js" as WidgetGrid
import QtQuick
import qs.utils

// One widget, drawn for real, so the Add-widget picker can show what you are about to put on the
// desktop instead of only naming it.
//
// This is the genuine card from widgets/, not a mock-up of one: it reads the same services and draws
// the same layout, so a preview cannot drift from what actually lands on the desktop. Its data is live
// too - the real forecast, the real month, the real CPU load.
//
// The card is laid out at desktop width and then scaled down to fit, rather than being given the
// preview's width directly: a card squeezed into 150px reflows into something the desktop never shows,
// which would make the preview a liar in exactly the way it is here to prevent.
Item {
    id: root

    // Which widget, and which of its styles: ids from utils/WidgetCatalog.qml
    required property string kind
    required property string variant

    // Cells, taken from the catalog so a preview is the shape the card will actually be
    readonly property int cells: WidgetCatalog.heightFor(root.kind, root.variant)

    // The size the card is built at before scaling: what it would get in a single grid column
    readonly property real cardWidth: WidgetGrid.cardCells * WidgetGrid.unit - WidgetGrid.gap
    readonly property real cardHeight: root.cells * WidgetGrid.unit - WidgetGrid.gap

    readonly property real scaleFactor: Math.min(width / root.cardWidth, height / root.cardHeight)

    // So a caller only has to pick a width: the height then keeps the card's real proportions, and a
    // tall widget reads as taller than a short one in the picker just as it will on the desktop
    implicitWidth: root.cardWidth
    implicitHeight: width > 0 ? root.cardHeight * (width / root.cardWidth) : root.cardHeight

    clip: true

    Loader {
        id: card

        // Centred on the preview, then scaled about that same centre
        x: (root.width - root.cardWidth) / 2
        y: (root.height - root.cardHeight) / 2
        width: root.cardWidth
        height: root.cardHeight

        transform: Scale {
            origin.x: card.width / 2
            origin.y: card.height / 2
            xScale: root.scaleFactor
            yScale: root.scaleFactor
        }

        sourceComponent: {
            switch (root.kind) {
            case "calendar":
                return calendarCard;
            case "clock":
                return clockCard;
            case "weather":
                return weatherCard;
            case "pomodoro":
                return focusCard;
            case "resources":
                return systemCard;
            case "network":
                return networkCard;
            case "media":
                return mediaCard;
            case "lyrics":
                return lyricsCard;
            case "battery":
                return batteryCard;
            case "bluetooth":
                return bluetoothCard;
            case "fetch":
                return fetchCard;
            case "visualiser":
                return visualiserCard;
            case "sticky":
                return stickyCard;
            case "photo":
                return photoCard;
            case "github":
                return contributionsCard;
            case "stocks":
                return root.variant === "portfolio" ? portfolioCard : stockCard;
            case "portfolio":
                return portfolioCard;
            case "progress":
                return progressCard;
            case "todo":
                return todoCard;
            default:
                return null;
            }
        }
    }

    // Nothing in a preview is clickable: the card is there to be looked at, and the row or tile around
    // it owns the press. Without this a preview's own buttons - the media card's play button, the todo
    // card's checkboxes - would swallow the click that is meant to add the widget
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: mouse => mouse.accepted = false
    }

    // Each card below is the real widget, told which style to draw and given no grid host, so it lays
    // itself out at the size above rather than from a cell it does not have
    Component {
        id: calendarCard

        CalendarCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: clockCard

        ClockCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: weatherCard

        WeatherCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: focusCard

        FocusCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: systemCard

        SystemCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: networkCard

        NetworkCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: mediaCard

        MediaCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: lyricsCard

        LyricsCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: batteryCard

        BatteryCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: bluetoothCard

        BluetoothBatteryCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: fetchCard

        FetchCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: visualiserCard

        VisualiserCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: stickyCard

        StickyCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: photoCard

        PhotoCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: contributionsCard

        ContributionsCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: stockCard

        StockCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: portfolioCard

        PortfolioCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: progressCard

        ProgressCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }

    Component {
        id: todoCard

        TodoCard {
            variant: root.variant
            widgetId: root.kind
            entryIndex: -1
        }
    }
}
