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
    readonly property var rows: {
        // Read through quotes so a refreshed result redraws the card
        void Stocks.quotes;
        return Stocks.symbols.map(symbol => Stocks.quotes[symbol]).filter(quote => quote !== undefined && quote !== null);
    }
    readonly property var feature: stock.rows[0] ?? null
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

    function formatPrice(value: var): string {
        if (value === undefined || value === null || !Number.isFinite(Number(value)))
            return "—";

        const fixed = Number(value).toFixed(Number(value) < 1 ? 4 : 2);
        const parts = fixed.split(".");
        return parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",") + "." + parts[1];
    }

    function formatPercent(value: var): string {
        if (value === undefined || value === null || !Number.isFinite(Number(value)))
            return "—";
        return `${value >= 0 ? "+" : ""}${Number(value).toFixed(2)}%`;
    }

    function tone(value: var): color {
        if (value === undefined || value === null || !Number.isFinite(Number(value)) || Math.abs(value) < 0.005)
            return Colours.palette.m3onSurfaceVariant;
        return value > 0 ? Colours.palette.m3tertiary : Colours.palette.m3error;
    }

    title: Tr.tr("Stocks")
    icon: "trending_up"

    Component.onCompleted: Stocks.refresh(false)

    StyledText {
        Layout.fillWidth: true
        visible: stock.message !== ""
        wrapMode: Text.Wrap
        text: stock.message
        color: Stocks.error !== "" ? Colours.palette.m3error : Colours.palette.m3outline
        font: Tokens.font.label.medium
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

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: quoteRow.modelData.symbol
                color: Colours.palette.m3onSurface
                font: Tokens.font.label.medium
            }

            StyledText {
                text: stock.formatPrice(quoteRow.modelData.price)
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
                    text: stock.feature?.symbol ?? ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: stock.formatPrice(stock.feature?.price)
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

        Canvas {
            id: chart

            property var values: stock.feature?.spark ?? []

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 34
            Layout.preferredHeight: 46
            visible: stock.feature !== null

            onValuesChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: {
                if (visible)
                    requestPaint();
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                const values = chart.values;
                if (values.length < 2)
                    return;

                let min = Number.POSITIVE_INFINITY;
                let max = Number.NEGATIVE_INFINITY;
                for (const value of values) {
                    min = Math.min(min, value);
                    max = Math.max(max, value);
                }
                if (max - min < 0.000001) {
                    min -= 1;
                    max += 1;
                }

                const pad = 3;
                const step = (width - pad * 2) / (values.length - 1);
                const y = value => height - pad - (value - min) / (max - min) * (height - pad * 2);

                ctx.beginPath();
                values.forEach((value, index) => {
                    if (index === 0)
                        ctx.moveTo(pad, y(value));
                    else
                        ctx.lineTo(pad + index * step, y(value));
                });
                ctx.lineTo(width - pad, height);
                ctx.lineTo(pad, height);
                ctx.closePath();
                ctx.fillStyle = Qt.alpha(stock.accent, 0.12);
                ctx.fill();

                ctx.beginPath();
                values.forEach((value, index) => {
                    if (index === 0)
                        ctx.moveTo(pad, y(value));
                    else
                        ctx.lineTo(pad + index * step, y(value));
                });
                ctx.strokeStyle = stock.accent;
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.stroke();
            }
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
                        text: stock.formatPrice(cell.modelData.price)
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
        interval: Stocks.ttl
        repeat: true
        running: Stocks.symbols.length > 0
        onTriggered: Stocks.refresh(true)
    }
}
