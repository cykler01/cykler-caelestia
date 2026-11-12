pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Settings for the stocks cards: the watchlist, how many shares are held, and whether a card shows
// prices or the value of those shares. The portfolio widget totals whatever is entered here.
PageBase {
    id: root

    readonly property var widgetsConfig: GlobalConfig.background.desktopWidgets
    readonly property int valueModeIndex: String(root.widgetsConfig.stockValueMode ?? "relative") === "holdings" ? 1 : 0
    readonly property list<MenuItem> valueModes: [
        MenuItem {
            text: Tr.tr("Relative price")
        },
        MenuItem {
            text: Tr.tr("Holdings value")
        }
    ]

    property string query: ""
    property string addError: ""
    property string pendingSymbol: ""

    function setShares(symbol: string, text: string): void {
        const value = Number(String(text ?? "").replace(",", "."));
        Stocks.setShares(symbol, Number.isFinite(value) && value > 0 ? value : 0);
    }

    function addStock(symbol: string): void {
        const clean = Stocks.normaliseSymbols([symbol])[0] ?? "";
        if (clean === "") {
            root.addError = Tr.tr("Enter a ticker or pick a company from the results");
            return;
        }
        if (Stocks.symbols.includes(clean)) {
            root.addError = Tr.tr("%1 is already in the list").arg(clean);
            return;
        }
        if (Stocks.symbols.length >= Stocks.maxSymbols) {
            root.addError = Tr.tr("You can watch up to %1 stocks").arg(Stocks.maxSymbols);
            return;
        }

        GlobalConfig.background.desktopWidgets.stockSymbols = [...Stocks.symbols, clean];
        root.addError = "";
        root.pendingSymbol = "";
        root.query = "";
        searchInput.clear();
        Stocks.clearSearch();
    }

    function removeStock(symbol: string): void {
        GlobalConfig.background.desktopWidgets.stockSymbols = Stocks.symbols.filter(item => item !== symbol);
        Stocks.setShares(symbol, 0);
    }

    // The Add button accepts a ticker only when the search has an exact match. A company name still
    // autocompletes by clicking one of the results below, so "apple" cannot accidentally add a futures
    // contract or the wrong exchange's listing.
    function requestAdd(): void {
        root.addError = "";
        const raw = root.query.trim();
        if (raw === "")
            return;

        const symbol = raw.toUpperCase();
        if (!/^[A-Z0-9.^=\-]{1,12}$/.test(symbol)) {
            root.addError = Tr.tr("Pick a company from the results, or enter a ticker");
            return;
        }
        if (Stocks.symbols.includes(symbol)) {
            root.addError = Tr.tr("%1 is already in the list").arg(symbol);
            return;
        }
        if (Stocks.symbols.length >= Stocks.maxSymbols) {
            root.addError = Tr.tr("You can watch up to %1 stocks").arg(Stocks.maxSymbols);
            return;
        }

        const match = Stocks.searchResults.find(result => result.symbol === symbol);
        if (match) {
            root.addStock(match.symbol);
            return;
        }

        root.pendingSymbol = symbol;
        if (!Stocks.searching)
            Stocks.search(symbol);
    }

    function resolvePending(): void {
        if (root.pendingSymbol === "" || Stocks.searching)
            return;

        const symbol = root.pendingSymbol;
        root.pendingSymbol = "";
        const match = Stocks.searchResults.find(result => result.symbol === symbol);
        if (match)
            root.addStock(match.symbol);
        else if (Stocks.searchError !== "")
            root.addError = Stocks.searchError;
        else
            root.addError = Tr.tr("No stock found for %1").arg(symbol);
    }

    title: Tr.tr("Stocks")
    isSubPage: true

    Component.onCompleted: Stocks.refresh(false)

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Connections {
            function onSearchResultsChanged(): void {
                root.resolvePending();
            }

            function onSearchErrorChanged(): void {
                root.resolvePending();
            }

            function onSearchingChanged(): void {
                if (!Stocks.searching)
                    root.resolvePending();
            }

            target: Stocks
        }

        Timer {
            id: searchTimer

            interval: 350
            onTriggered: Stocks.search(root.query)
        }

        SectionHeader {
            first: true
            text: Tr.tr("Your stocks")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            text: Tr.tr("Add a company to the watchlist, then enter how many shares you own if you want the stocks card and portfolio to track their value.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        Repeater {
            model: Stocks.symbols

            ConnectedRect {
                id: stockRow

                required property string modelData
                required property int index

                readonly property var quote: Stocks.quotes[stockRow.modelData] ?? null
                readonly property bool missing: !stockRow.quote && !Stocks.loading

                Layout.fillWidth: true
                first: stockRow.index === 0
                last: stockRow.index === Stocks.symbols.length - 1
                implicitHeight: stockLayout.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: stockLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: stockRow.modelData
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.small
                        }

                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: stockRow.quote ? `${Stocks.formatPrice(stockRow.quote.price)} · ${Stocks.formatPercent(stockRow.quote.change)}` : (Stocks.loading ? Tr.tr("Checking...") : Tr.tr("No quote — check the ticker"))
                            color: stockRow.missing ? Colours.palette.m3error : Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }
                    }

                    ColumnLayout {
                        spacing: 0

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: Tr.tr("Shares")
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                        }

                        StyledTextField {
                            id: sharesInput

                            Layout.preferredWidth: 84
                            horizontalAlignment: Text.AlignRight
                            placeholderText: "0"
                            text: {
                                const shares = Stocks.sharesFor(stockRow.modelData);
                                return shares > 0 ? Stocks.formatShares(shares) : "";
                            }
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            validator: RegularExpressionValidator {
                                regularExpression: /^\d*(?:\.\d{0,4})?$/
                            }
                            onEditingFinished: root.setShares(stockRow.modelData, text)
                        }
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        isRound: true
                        inactiveOnColour: Colours.palette.m3error
                        onClicked: root.removeStock(stockRow.modelData)
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            visible: Stocks.symbols.length === 0
            wrapMode: Text.Wrap
            text: Tr.tr("No stocks yet. Search for a company below to add one.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            text: Tr.tr("Add a stock")
        }

        ConnectedRect {
            first: true
            last: Stocks.searchResults.length === 0 || Stocks.searching
            Layout.fillWidth: true
            implicitHeight: searchLayout.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: searchLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.medium

                StyledTextField {
                    id: searchInput

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Company name or ticker")
                    leadingIcon: "search"
                    verticalPadding: Tokens.padding.small
                    text: root.query

                    onTextEdited: value => {
                        root.query = value;
                        root.addError = "";
                        root.pendingSymbol = "";
                        if (value.trim() === "") {
                            searchTimer.stop();
                            Stocks.clearSearch();
                        } else {
                            searchTimer.restart();
                        }
                    }
                    onAccepted: root.requestAdd()
                }

                IconButton {
                    icon: "add"
                    type: IconButton.Filled
                    disabled: !root.query.trim() || Stocks.symbols.length >= Stocks.maxSymbols
                    onClicked: root.requestAdd()
                }
            }
        }

        Repeater {
            model: Stocks.searchResults

            NavRow {
                id: searchResult

                required property var modelData
                required property int index

                first: false
                last: searchResult.index === Stocks.searchResults.length - 1
                icon: "add"
                text: searchResult.modelData.symbol
                subtext: searchResult.modelData.exchange === "" ? searchResult.modelData.name : `${searchResult.modelData.name} · ${searchResult.modelData.exchange}`
                onClicked: root.addStock(searchResult.modelData.symbol)
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            visible: Stocks.searching || root.addError !== "" || (root.query.trim() !== "" && Stocks.searchResults.length === 0 && Stocks.searchError !== "")
            wrapMode: Text.Wrap
            text: {
                if (root.addError !== "")
                    return root.addError;
                if (Stocks.searching)
                    return Tr.tr("Searching Yahoo Finance...");
                return Stocks.searchError;
            }
            color: root.addError !== "" || (!Stocks.searching && Stocks.searchResults.length === 0 && Stocks.searchError !== "") ? Colours.palette.m3error : Colours.palette.m3outline
            font: Tokens.font.label.small
        }

        SectionHeader {
            text: Tr.tr("Card values")
        }

        SelectRow {
            first: true
            last: false
            label: Tr.tr("Stock card shows")
            subtext: Tr.tr("Use the price alone, or multiply it by the shares you own")
            menuItems: root.valueModes
            active: root.valueModes[root.valueModeIndex]
            onSelected: item => GlobalConfig.background.desktopWidgets.stockValueMode = item === root.valueModes[1] ? "holdings" : "relative"
        }

        StepperRow {
            last: true
            label: Tr.tr("Spotlight rotation")
            subtext: Tr.tr("How long each stock stays on the spotlight chart (seconds)")
            value: Math.round(Number(root.widgetsConfig.stockSpotlightInterval ?? 60000) / 1000)
            from: 10
            to: 600
            stepSize: 10
            onMoved: v => GlobalConfig.background.desktopWidgets.stockSpotlightInterval = Math.round(v) * 1000
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            Layout.bottomMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            text: Tr.tr("Holdings value uses the number of shares entered above. The portfolio widget always totals the shares, whichever option the stocks card uses.")
            color: Colours.palette.m3outline
            font: Tokens.font.label.small
        }
    }
}
