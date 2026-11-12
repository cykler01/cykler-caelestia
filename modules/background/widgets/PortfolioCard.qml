pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.background

// --- Portfolio: the combined value of the shares entered for the stocks widget ---
WidgetCard {
    id: portfolio

    readonly property var shown: Stocks.holdings.slice(0, 4)
    readonly property color accent: portfolio.tone(Stocks.portfolioChange)
    readonly property string message: {
        if (!Stocks.hasHoldings)
            return Tr.tr("Set how many shares you own in Stocks settings");
        if (Stocks.holdings.length > 0)
            return "";
        if (Stocks.error !== "")
            return Stocks.error;
        return Stocks.loading ? Tr.tr("Loading...") : Tr.tr("No quotes");
    }

    function tone(value: var): color {
        if (value === undefined || value === null || !Number.isFinite(Number(value)) || Math.abs(value) < 0.005)
            return Colours.palette.m3onSurfaceVariant;
        return value > 0 ? Colours.palette.m3tertiary : Colours.palette.m3error;
    }

    function changeText(): string {
        const value = Stocks.portfolioChange;
        if (!Number.isFinite(value))
            return "—";
        return `${value >= 0 ? "+" : ""}${Stocks.formatPrice(value)}`;
    }

    function allocation(value: var): string {
        if (!(Stocks.portfolioValue > 0))
            return "—";
        return `${Math.round(Number(value) / Stocks.portfolioValue * 100)}%`;
    }

    title: Tr.tr("Portfolio")
    icon: "account_balance_wallet"

    Component.onCompleted: Stocks.refresh(false)

    StyledText {
        Layout.fillWidth: true
        visible: portfolio.message !== ""
        wrapMode: Text.Wrap
        text: portfolio.message
        color: Stocks.error !== "" ? Colours.palette.m3error : Colours.palette.m3outline
        font: Tokens.font.label.medium
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 0
        visible: portfolio.message === ""
        spacing: Tokens.spacing.extraSmall

        StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Stocks.formatPrice(Stocks.portfolioValue)
            color: Colours.palette.m3onSurface
            font: Tokens.font.headline.builders.medium.weight(Font.DemiBold).build()
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                text: portfolio.changeText()
                color: portfolio.accent
                font: Tokens.font.label.medium
            }

            StyledText {
                text: Stocks.formatPercent(Stocks.portfolioChangePercent)
                color: portfolio.accent
                font: Tokens.font.label.small
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: Tr.tr("Today")
                color: Colours.palette.m3outline
                font: Tokens.font.label.small
            }
        }

        StockChart {
            values: Stocks.portfolioSpark
            accent: portfolio.accent
            visible: Stocks.portfolioSpark.length > 1
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            Layout.bottomMargin: Tokens.spacing.extraSmall
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
            opacity: 0.5
        }

        Repeater {
            model: portfolio.shown

            RowLayout {
                id: holdingRow

                required property var modelData

                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    text: `${holdingRow.modelData.symbol} · ${Stocks.formatShares(holdingRow.modelData.shares)}`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }

                StyledText {
                    text: portfolio.allocation(holdingRow.modelData.value)
                    color: Colours.palette.m3outline
                    font: Tokens.font.label.small
                }

                StyledText {
                    Layout.preferredWidth: 76
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: Stocks.formatPrice(holdingRow.modelData.value)
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.label.small
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Stocks.holdings.length > portfolio.shown.length
            text: Tr.tr("+%1 more").arg(Stocks.holdings.length - portfolio.shown.length)
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }

    Timer {
        interval: Stocks.ttl
        repeat: true
        running: Stocks.symbols.length > 0
        onTriggered: Stocks.refresh(true)
    }
}
