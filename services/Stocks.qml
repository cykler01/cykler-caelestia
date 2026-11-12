pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// The stocks card's quotes, kept here rather than in the card: the widget stack is unloaded whenever
// windows cover the desktop, and a card that comes back should draw the last quotes immediately instead
// of starting at "Loading..." again. One request carries every selected symbol.
//
// The same service also holds the symbols the settings page is searching and the share counts used by
// the portfolio card. Those are deliberately kept separate from the quotes: Yahoo is only asked for a
// symbol once it has been picked, and changing an amount never throws away the prices on screen.
Singleton {
    id: root

    readonly property var config: GlobalConfig.background.desktopWidgets
    // Six fits a watchlist on one card. More than that turns the card into a scrolling list, which is
    // not something the desktop can be interacted with.
    readonly property int maxSymbols: 6
    // Quotes update slowly enough that a five minute cache is still current; the cards ask again when
    // they are rebuilt, but only a stale cache goes back out to the network.
    readonly property int ttl: 300000
    readonly property var symbols: root.normaliseSymbols(root.config.stockSymbols)
    // Whether the stocks card shows the quote itself or what the held shares are worth
    readonly property bool holdingsMode: String(root.config.stockValueMode ?? "relative") === "holdings"

    property var quotes: ({})
    property string error
    property bool loading: false
    property double fetchedAt: 0
    property string cachedKey: ""
    property string inFlightKey: ""
    property int generation: 0
    property var requestedSymbols: []
    // Symbols the last quote request could not return. The cards and the settings page use this to warn
    // about a typo without refusing to add the ticker in the first place.
    readonly property var missingSymbols: {
        void root.quotes;
        if (root.loading || root.requestedSymbols.length === 0)
            return [];

        const current = root.quotes;
        return root.requestedSymbols.filter(symbol => current[symbol] === undefined || current[symbol] === null);
    }

    // Symbol search for the settings page. Results are Company Name + exchange + ticker, so a user can
    // type "apple" and pick AAPL rather than having to know the ticker before adding it.
    property string searchQuery: ""
    property var searchResults: []
    property string searchError
    property bool searching: false
    property int searchGeneration: 0

    // Holdings with a quote. Reading `quotes` here makes the portfolio totals follow a refresh.
    readonly property var positions: {
        const out = [];
        const current = root.quotes;
        for (const symbol of root.symbols) {
            const shares = root.sharesFor(symbol);
            if (!(shares > 0))
                continue;

            const quote = current[symbol] ?? null;
            const price = Number(quote?.price ?? NaN);
            const previous = Number(quote?.previousClose ?? NaN);
            out.push({
                symbol: symbol,
                shares: shares,
                price: price,
                previousClose: previous,
                change: quote?.change ?? NaN,
                value: Number.isFinite(price) ? price * shares : NaN,
                previousValue: Number.isFinite(previous) ? previous * shares : NaN,
                dayChange: Number.isFinite(price) && Number.isFinite(previous) ? (price - previous) * shares : NaN,
                spark: quote?.spark ?? []
            });
        }
        return out;
    }
    readonly property var holdings: root.positions.filter(position => Number.isFinite(position.value))
    readonly property bool hasHoldings: root.positions.length > 0
    readonly property double portfolioValue: root.holdings.reduce((sum, position) => sum + position.value, 0)
    readonly property double portfolioPreviousValue: root.holdings.reduce((sum, position) => sum + (Number.isFinite(position.previousValue) ? position.previousValue : 0), 0)
    readonly property double portfolioChange: root.portfolioValue - root.portfolioPreviousValue
    readonly property double portfolioChangePercent: root.portfolioPreviousValue > 0 ? root.portfolioChange / root.portfolioPreviousValue * 100 : NaN
    // The same intraday shape as a single stock, but each point is the sum of the held shares at that
    // point. Quotes from the same request share an interval; if one series is shorter, its last point is
    // sampled across the longer range so the lines still combine into one comparable series.
    readonly property var portfolioSpark: {
        const rows = root.holdings.filter(position => position.spark.length > 1);
        if (rows.length === 0)
            return [];

        const length = Math.max(...rows.map(position => position.spark.length));
        const out = [];
        for (let i = 0; i < length; i++) {
            let total = 0;
            for (const row of rows) {
                const index = length === 1 ? 0 : Math.round(i * (row.spark.length - 1) / (length - 1));
                total += Number(row.spark[index] ?? 0) * row.shares;
            }
            out.push(total);
        }
        return out;
    }

    // Uppercase, deduplicated and URL-safe. The field in Settings accepts a comma-separated list, so
    // this also strips the spaces and punctuation someone may type around the tickers.
    function normaliseSymbols(input: var): var {
        let raw = [];
        if (Array.isArray(input))
            raw = input;
        else if (typeof input === "string")
            raw = input.split(/[,\s]+/);
        else if (input && input.length !== undefined)
            raw = Array.from(input);
        else
            raw = String(input ?? "").split(/[,\s]+/);

        const seen = {};
        const out = [];
        for (const item of raw) {
            const symbol = String(item ?? "").trim().toUpperCase();
            if (!/^[A-Z0-9.^=\\-]{1,12}$/.test(symbol) || seen[symbol])
                continue;

            seen[symbol] = true;
            out.push(symbol);
            if (out.length >= root.maxSymbols)
                break;
        }
        return out;
    }

    function sharesFor(symbol: var): double {
        const ticker = String(symbol ?? "").trim().toUpperCase();
        const rows = root.config.stockShares?.values ?? [];
        for (const row of rows) {
            if (String(row.symbol ?? "").trim().toUpperCase() === ticker)
                return Math.max(0, Number(row.shares ?? 0));
        }
        return 0;
    }

    // Kept as a list of {symbol, shares} rather than a map so it can be edited in the settings UI and
    // still serialises cleanly into the config.
    function setShares(symbol: var, shares: var): void {
        const ticker = String(symbol ?? "").trim().toUpperCase();
        if (ticker === "")
            return;

        const list = root.config.stockShares;
        if (!list)
            return;

        const index = list.values.findIndex(row => String(row.symbol ?? "").trim().toUpperCase() === ticker);
        const value = Number(shares);
        if (!Number.isFinite(value) || value <= 0) {
            if (index >= 0)
                list.remove(index);
            return;
        }

        if (index >= 0)
            list.at(index).shares = value;
        else
            list.insert({
                symbol: ticker,
                shares: value
            });
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

    function formatShares(value: var): string {
        const number = Number(value);
        if (!Number.isFinite(number))
            return "—";
        return Number.isInteger(number) ? String(number) : number.toFixed(4).replace(/\.?0+$/, "");
    }

    function requestUrl(symbols: var): string {
        const tickers = symbols.map(symbol => encodeURIComponent(symbol)).join(",");
        return `https://query1.finance.yahoo.com/v8/finance/spark?symbols=${tickers}&range=1d&interval=5m`;
    }

    // `force` skips the cache for the card's own refresh timer. The in-flight check keeps several cards
    // (or a preview and the desktop card) from asking for the same symbols at once.
    function refresh(force: bool): void {
        const symbols = root.symbols;
        if (symbols.length === 0) {
            root.generation += 1;
            root.quotes = ({});
            root.error = "";
            root.loading = false;
            root.fetchedAt = 0;
            root.cachedKey = "";
            root.inFlightKey = "";
            root.requestedSymbols = [];
            return;
        }

        const key = symbols.join(",");
        if (!force && root.fetchedAt > 0 && root.cachedKey === key && Date.now() - root.fetchedAt < root.ttl)
            return;
        if (root.inFlightKey === key)
            return;

        const generation = root.generation + 1;
        root.generation = generation;
        root.requestedSymbols = symbols;
        root.loading = true;
        root.inFlightKey = key;
        root.error = "";

        // Yahoo answers this endpoint without a key, but it is happier with a browser-shaped request.
        Requests.get(root.requestUrl(symbols), text => root.parse(generation, text), (reason, metadata, body) => root.fail(generation, reason, body), {
            "User-Agent": "Mozilla/5.0 (caelestia-shell)",
            "Accept": "application/json"
        });
    }

    // Search is separate from quotes: it resolves a company name to a ticker before it is added.
    function search(query: var): void {
        const text = String(query ?? "").trim();
        root.searchQuery = text;
        root.searchError = "";
        root.searching = text !== "";
        root.searchResults = [];
        root.searchGeneration += 1;
        const generation = root.searchGeneration;

        if (text === "")
            return;
        const url = `https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(text)}&quotesCount=10&newsCount=0`;
        Requests.get(url, body => root.parseSearch(generation, body), (reason, metadata, body) => root.failSearch(generation, reason, body), {
            "User-Agent": "Mozilla/5.0 (caelestia-shell)",
            "Accept": "application/json"
        });
    }

    function clearSearch(): void {
        root.searchGeneration += 1;
        root.searchQuery = "";
        root.searchResults = [];
        root.searchError = "";
        root.searching = false;
    }

    function parseSearch(generation: int, text: string): void {
        if (generation !== root.searchGeneration)
            return;

        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            root.failSearch(generation, Tr.tr("Could not read the stock search"));
            return;
        }

        const allowed = ["EQUITY", "ETF", "MUTUALFUND", "INDEX", "CRYPTOCURRENCY"];
        const next = [];
        for (const row of (data?.quotes ?? [])) {
            const symbol = String(row?.symbol ?? "").trim().toUpperCase();
            const type = String(row?.quoteType ?? "").toUpperCase();
            if (!allowed.includes(type) || !/^[A-Z0-9.^=\\-]{1,12}$/.test(symbol))
                continue;

            next.push({
                symbol: symbol,
                name: String(row.longname || row.shortname || symbol),
                exchange: String(row.exchDisp || row.exchange || ""),
                type: type
            });
            if (next.length >= 8)
                break;
        }

        root.searchResults = next;
        root.searchError = next.length === 0 ? Tr.tr("No matching stocks") : "";
        root.searching = false;
    }

    function failSearch(generation: int, reason: string, body: var): void {
        if (generation !== root.searchGeneration)
            return;

        let message = reason;
        if (body) {
            try {
                const data = JSON.parse(body);
                message = data?.finance?.error?.description ?? data?.error?.description ?? message;
            } catch (e) {
                // The body is not JSON; the request's own error is the useful part
            }
        }

        root.searchResults = [];
        root.searchError = message || Tr.tr("Could not search for stocks");
        root.searching = false;
        console.warn(lc, `Stocks search: ${root.searchError}`);
    }

    function parse(generation: int, text: string): void {
        if (generation !== root.generation)
            return;

        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            root.fail(generation, Tr.tr("Could not read the stock data"));
            console.warn(lc, `Stocks: unreadable response: ${e}`);
            return;
        }

        const failure = data?.spark?.error?.description ?? "";
        if (failure !== "") {
            root.fail(generation, failure);
            return;
        }

        const next = {};
        let found = 0;
        for (const symbol of root.requestedSymbols) {
            const row = data?.[symbol];
            if (!row)
                continue;

            const closes = [];
            for (const close of (row.close ?? [])) {
                if (typeof close === "number" && Number.isFinite(close))
                    closes.push(close);
            }
            if (closes.length === 0)
                continue;

            const price = closes[closes.length - 1];
            // `chartPreviousClose` is the close before the intraday session. Its sibling
            // `fulldayChangePercent` only describes the after-hours move, so the day's change is worked
            // out here instead of copied from the response.
            const previous = Number(row.chartPreviousClose ?? row.previousClose);
            const change = Number.isFinite(previous) && previous !== 0 ? (price / previous - 1) * 100 : NaN;

            next[symbol] = {
                symbol: symbol,
                price: price,
                previousClose: previous,
                change: change,
                spark: root.downsample(closes, 48)
            };
            found += 1;
        }

        if (found === 0) {
            root.fail(generation, Tr.tr("No quotes came back for these symbols"));
            return;
        }

        root.quotes = Object.assign({}, root.quotes, next);
        root.cachedKey = root.requestedSymbols.join(",");
        root.fetchedAt = Date.now();
        root.loading = false;
        root.inFlightKey = "";
        root.error = "";
    }

    function fail(generation: int, reason: string, body: var): void {
        if (generation !== root.generation)
            return;

        let message = reason;
        if (body) {
            try {
                const data = JSON.parse(body);
                message = data?.spark?.error?.description ?? message;
            } catch (e) {
                // The body is not JSON; the request's own error is the useful part
            }
        }

        root.loading = false;
        root.inFlightKey = "";
        // Back off for a full interval rather than hammering a feed that is down or rate limiting us
        root.fetchedAt = Date.now();
        root.error = message || Tr.tr("Could not fetch stock quotes");
        console.warn(lc, `Stocks: ${root.error}`);
    }

    // Intraday feeds can return a point per minute. The card draws a few dozen pixels, so keeping every
    // reading would only make the line busier without making it more accurate.
    function downsample(values: var, limit: int): var {
        if (values.length <= limit)
            return values;

        const out = [];
        for (let i = 0; i < limit; i++)
            out.push(values[Math.round(i * (values.length - 1) / (limit - 1))]);
        return out;
    }

    onSymbolsChanged: {
        root.quotes = ({});
        root.error = "";
        root.fetchedAt = 0;
        root.cachedKey = "";
        root.refresh(false);
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.stocks"
        defaultLogLevel: LoggingCategory.Warning
    }
}
