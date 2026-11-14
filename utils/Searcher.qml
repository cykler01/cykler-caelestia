import "scripts/fzf.js" as Fzf
import "scripts/fuzzysort.js" as Fuzzy
import QtQuick
import Quickshell

Singleton {
    required property list<QtObject> list
    property string key: "name"
    property bool useFuzzy: false
    property var extraOpts: ({})

    // An optional say in the ordering from something the text cannot see - how often an app is
    // launched, say. Given an item, it returns a fraction of that item's match score to add to it,
    // so it settles ties and nudges near-ties without ever lifting a poor match over a good one.
    // Null leaves the ordering to the matcher alone
    property var rankBoost: null

    // Extra stuff for fuzzy
    property list<string> keys: [key]
    property list<real> weights: [1]

    readonly property var fzf: useFuzzy ? [] : new Fzf.Finder(list, Object.assign({
        selector
    }, extraOpts))
    readonly property list<var> fuzzyPrepped: useFuzzy ? list.map(e => {
        const obj = {
            _item: e
        };
        for (const k of keys)
            obj[k] = Fuzzy.prepare(e[k]);
        return obj;
    }) : []

    function transformSearch(search: string): string {
        return search;
    }

    function selector(item: var): string {
        // Only for fzf
        return item[key];
    }

    // Works on the absolute score so it still reads as a boost for a matcher whose scores can go
    // negative: for those, "better" is closer to zero
    function boostedScore(item: var, score: real): real {
        return rankBoost ? score + Math.abs(score) * rankBoost(item) : score;
    }

    function query(search: string): var {
        search = transformSearch(search.trim().replace(/\s+/g, " "));
        if (!search)
            return [...list];

        if (useFuzzy)
            return Fuzzy.go(search, fuzzyPrepped, Object.assign({
                all: true,
                keys,
                scoreFn: r => boostedScore(r.obj._item, weights.reduce((a, w, i) => a + r[i].score * w, 0))
            }, extraOpts)).map(r => r.obj._item);

        return fzf.find(search).map(r => ({
                    item: r.item,
                    score: boostedScore(r.item, r.score)
                })).sort((a, b) => {
            if (a.score === b.score)
                return selector(a.item).trim().length - selector(b.item).trim().length;
            return b.score - a.score;
        }).map(r => r.item);
    }
}
