pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n

// The stocks card's quotes, kept here rather than in the card: the widget stack is unloaded whenever
// windows cover the desktop, and a card that comes back should draw the last quotes immediately instead
// of starting at "Loading..." again. One request carries every selected symbol.
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
    property var quotes: ({})
    property string error
    property bool loading: false
    property double fetchedAt: 0
    property string cachedKey: ""
    property string inFlightKey: ""
    property int generation: 0
    property var requestedSymbols: []

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
            if (!/^[A-Z0-9.^=\-]{1,12}$/.test(symbol) || seen[symbol])
                continue;

            seen[symbol] = true;
            out.push(symbol);
            if (out.length >= root.maxSymbols)
                break;
        }
        return out;
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
