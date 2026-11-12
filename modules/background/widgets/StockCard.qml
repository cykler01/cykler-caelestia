pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Stocks: the selected tickers, as a watchlist, a spotlight with an intraday chart, or a compact board ---
WidgetCard {
    id: stock

    readonly property string style: stock.variant === "spotlight" || stock.variant === "compact" ? stock.variant : "watchlist"
    readonly property bool spotlight: stock.style === "spotlight"
    readonly property bool compact: stock.style === "compact"
    readonly property bool holdings: Stocks.holdingsMode
    property int spotlightIndex: 0
    readonly property var rows: {
        // Read through quotes so a refreshed result redraws the card
        void Stocks.quotes;
        return Stocks.symbols.map(symbol => Stocks.quotes[symbol]).filter(quote => quote !== undefined && quote !== null);
    }
    readonly property var feature: stock.rows.length > 0 ? stock.rows[stock.spotlightIndex % stock.rows.length] : null
    readonly property color accent: stock.tone(stock.feature?.change ?? 0)
    readonly property string message: {
        if (Stocks.symbols.length === 0)
            return Tr.tr("Set stock symbols in Settings");
        if (stock.rows.length > 0)
            return "";
        if (Stocks.error !== "")
            return Stocks.error;
        return Stocks.loading ? Tr.tr("Loading...") : Tr.tr("No quotes");
    }
    readonly property string dataWarning: Stocks.missingSymbols.length > 0 ? Tr.tr("Could not load data for %1. Check the ticker or try again.").arg(Stocks.missingSymbols.join(", ")) : ""

    function displayPrice(quote: var): real {
        const price = Number(quote?.price ?? NaN);
        const shares = Stocks.sharesFor(quote?.symbol ?? "");
        return stock.holdings && shares > 0 ? price * shares : price;
    }

    function formatPrice(value: var): string {
        return Stocks.formatPrice(value);
    }

    function formatPercent(value: var): string {
        return Stocks.formatPercent(value);
    }

    function tone(value: var): color {
        if (value === undefined || value === null || !Number.isFinite(Number(value)) || Math.abs(value) < 0.005)
            return Colours.palette.m3onSurfaceVariant;
        return value > 0 ? Colours.palette.m3tertiary : Colours.palette.m3error;
    }

    title: Tr.tr("Stocks")
    icon: "trending_up"

    Component.onCompleted: Stocks.refresh(false)
    onRowsChanged: if (stock.spotlightIndex >= stock.rows.length) stock.spotlightIndex = 0

    StyledText {
        Layout.fillWidth: true
        visible: stock.message !== ""
        wrapMode: Text.Wrap
        text: stock.message
        color: Stocks.error !== "" ? Colours.palette.m3error : Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    StyledText {
        Layout.fillWidth: true
        visible: stock.message === "" && stock.dataWarning !== ""
        wrapMode: Text.Wrap
        text: stock.dataWarning
        color: Colours.palette.m3error
        font: Tokens.font.label.small
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: stock.style === "watchlist" && stock.rows.length > 0
        clip: true
        spacing: Tokens.spacing.extraSmall
        model: stock.rows

        delegate: RowLayout {
            id: quoteRow

            required property var modelData

            width: ListView.view.width
            spacing: Tokens.spacing.small

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: quoteRow.modelData.symbol
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: stock.holdings && Stocks.sharesFor(quoteRow.modelData.symbol) > 0
                    elide: Text.ElideRight
                    text: Tr.tr("%1 shares").arg(Stocks.formatShares(Stocks.sharesFor(quoteRow.modelData.symbol)))
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }

            StyledText {
                text: stock.formatPrice(stock.displayPrice(quoteRow.modelData))
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            StyledText {
                Layout.preferredWidth: 58
                horizontalAlignment: Text.AlignRight
                text: stock.formatPercent(quoteRow.modelData.change)
                color: stock.tone(quoteRow.modelData.change)
                font: Tokens.font.label.small
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: stock.spotlight && stock.feature !== null
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        const shares = Stocks.sharesFor(stock.feature?.symbol ?? "");
                        const symbol = stock.feature?.symbol ?? "";
                        return stock.holdings && shares > 0 ? `${symbol} · ${Stocks.formatShares(shares)} shares` : symbol;
                    }
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: stock.formatPrice(stock.displayPrice(stock.feature))
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: stock.formatPercent(stock.feature?.change)
                    color: stock.accent
                    font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignRight
                    text: Tr.tr("Today")
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }
            }
        }

        StockChart {
            values: stock.feature?.spark ?? []
            accent: stock.accent
            visible: stock.feature !== null
        }

        RowLayout {
            Layout.fillWidth: true
            visible: stock.rows.length > 1
            spacing: Tokens.spacing.small
            uniformCellSizes: true

            Repeater {
                model: stock.rows.slice(1, 6)

                ColumnLayout {
                    id: other

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.maximumWidth: Number.POSITIVE_INFINITY
                    Layout.minimumWidth: 0
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: other.modelData.symbol
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: stock.formatPrice(other.modelData.price)
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: stock.formatPercent(other.modelData.change)
                        color: stock.tone(other.modelData.change)
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: stock.compact && stock.rows.length > 0
        columns: 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.medium

        Repeater {
            model: stock.rows.slice(0, 4)

            ColumnLayout {
                id: cell

                required property var modelData

                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Number.POSITIVE_INFINITY
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignTop
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: cell.modelData.symbol
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        text: stock.formatPrice(stock.displayPrice(cell.modelData))
                        color: Colours.palette.m3onSurface
                        font: Tokens.font.label.medium
                    }

                    StyledText {
                        text: stock.formatPercent(cell.modelData.change)
                        color: stock.tone(cell.modelData.change)
                        font: Tokens.font.label.small
                    }
                }
            }
        }
    }

    Timer {
        interval: Math.max(5000, Number(GlobalConfig.background.desktopWidgets.stockSpotlightInterval ?? 60000))
        repeat: true
        running: stock.spotlight && stock.rows.length > 1
        onTriggered: stock.spotlightIndex = (stock.spotlightIndex + 1) % stock.rows.length
    }

    Timer {
        interval: Stocks.ttl
        repeat: true
        running: Stocks.symbols.length > 0
        onTriggered: Stocks.refresh(true)
    }
}
