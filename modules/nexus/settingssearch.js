.pragma library

// Matching for the settings search field. The old search only filtered page
// names, so finding one toggle meant knowing which page it was filed under;
// this scores every individual setting in SettingsIndex instead, forgivingly
// enough that a near miss still lands: a typo, the other spelling of a word, a
// word left out, or the setting called by a name the UI does not use.
//
// A query is split into words and every word has to match something, so
// "hover launcher" finds the launcher's hover toggle and nothing else, while
// the words themselves may land on different parts of the entry.

// Spellings of the same word, folded together so either finds the other. The
// UI is written in British English, which an American spelling would otherwise
// miss entirely ("color scheme" against "Colour scheme").
const SPELLINGS = [
    [/colour/g, "color"],
    [/behaviour/g, "behavior"],
    [/favourite/g, "favorite"],
    [/neighbour/g, "neighbor"],
    [/analogue/g, "analog"],
    [/catalogue/g, "catalog"],
    [/dialogue/g, "dialog"],
    [/centre/g, "center"],
    [/metre/g, "meter"],
    [/grey/g, "gray"],
    [/defence/g, "defense"],
    // -ise/-isation against -ize/-ization: visualiser, customise, equaliser
    [/([a-z]{2,})is(e|es|ed|er|ers|ing|ation|ations)\b/g, "$1iz$2"],
];

// Fields matched against, and how much a hit in each is worth. The label is
// what the row actually says, so it wins; the subtext is a sentence and matches
// loosely, so it is worth least.
const FIELDS = [
    ["label", 1],
    ["keywords", 0.85],
    ["section", 0.62],
    ["title", 0.6],
    ["pageLabel", 0.52],
    ["subtext", 0.48],
];

// Below this a match is too speculative to be worth a row in the results
const THRESHOLD = 0.26;

function normalise(text) {
    let out = String(text ?? "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
    for (let i = 0; i < SPELLINGS.length; i++)
        out = out.replace(SPELLINGS[i][0], SPELLINGS[i][1]);
    return out;
}

function tokenise(query) {
    const normalised = normalise(query);
    return normalised ? normalised.split(" ") : [];
}

// Damerau-Levenshtein distance, abandoned as soon as it passes `max`. The
// transposition case is what makes "brightnes"/"brigthness" cost one edit
// rather than two, since swapped letters are the usual way a word is mistyped.
function editDistance(a, b, max) {
    const al = a.length;
    const bl = b.length;
    if (Math.abs(al - bl) > max)
        return max + 1;

    let twoAgo = null;
    let prev = new Array(bl + 1);
    for (let j = 0; j <= bl; j++)
        prev[j] = j;

    for (let i = 1; i <= al; i++) {
        const cur = new Array(bl + 1);
        cur[0] = i;
        let best = i;
        for (let j = 1; j <= bl; j++) {
            const cost = a.charCodeAt(i - 1) === b.charCodeAt(j - 1) ? 0 : 1;
            let v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
            if (twoAgo && i > 1 && j > 1 && a.charCodeAt(i - 1) === b.charCodeAt(j - 2) && a.charCodeAt(i - 2) === b.charCodeAt(j - 1))
                v = Math.min(v, twoAgo[j - 2] + 1);
            cur[j] = v;
            if (v < best)
                best = v;
        }
        if (best > max)
            return max + 1;
        twoAgo = prev;
        prev = cur;
    }

    return prev[bl];
}

// How many edits a word of this length is allowed to be out by. One letter wrong
// in a short word usually means a different word, so short ones get no slack.
function tolerance(length) {
    if (length >= 8)
        return 2;
    if (length >= 4)
        return 1;
    return 0;
}

// The letters of `token` in order somewhere in `field`, scored by how tightly
// packed they are: this is what lets "dndchg" reach "Do not disturb changes",
// while a match spread across the whole sentence stays near the floor.
function subsequence(token, field) {
    let i = 0;
    let start = -1;
    let end = 0;
    for (let j = 0; j < field.length && i < token.length; j++) {
        if (field.charCodeAt(j) === token.charCodeAt(i)) {
            if (i === 0)
                start = j;
            end = j;
            i++;
        }
    }
    if (i < token.length)
        return 0;
    return token.length / (end - start + 1);
}

// One query word against one normalised field, from 0 (no match) to 1
function scoreToken(token, field) {
    if (!field)
        return 0;
    if (field === token)
        return 1;

    const words = field.split(" ");
    for (let i = 0; i < words.length; i++) {
        if (words[i] === token)
            return 0.96 - Math.min(i, 8) * 0.01;
    }
    for (let i = 0; i < words.length; i++) {
        if (words[i].startsWith(token))
            return 0.88 - Math.min(i, 8) * 0.01;
    }
    if (field.indexOf(token) >= 0)
        return 0.72;

    const tol = tolerance(token.length);
    if (tol > 0) {
        // A whole word mistyped
        for (let i = 0; i < words.length; i++) {
            const d = editDistance(token, words[i], tol);
            if (d <= tol)
                return 0.66 - d * 0.09;
        }
        // Half a word mistyped, so "blutooh" still reaches "bluetooth"
        for (let i = 0; i < words.length; i++) {
            if (words[i].length <= token.length)
                continue;
            const d = editDistance(token, words[i].slice(0, token.length), tol);
            if (d <= tol)
                return 0.56 - d * 0.09;
        }
    }

    const packed = subsequence(token, field);
    if (packed > 0)
        return 0.22 + packed * 0.22;
    return 0;
}

// Folds the strings an entry is matched on into one normalised bundle, once,
// rather than on every keystroke
function prepare(entry, extra) {
    const prepared = {
        entry,
        fields: {}
    };
    for (let i = 0; i < FIELDS.length; i++) {
        const name = FIELDS[i][0];
        prepared.fields[name] = normalise((extra && extra[name]) || entry[name] || "");
    }
    prepared.length = prepared.fields.label.length;
    return prepared;
}

function scoreEntry(tokens, prepared) {
    let total = 0;
    for (let t = 0; t < tokens.length; t++) {
        let best = 0;
        for (let f = 0; f < FIELDS.length; f++) {
            const score = scoreToken(tokens[t], prepared.fields[FIELDS[f][0]]) * FIELDS[f][1];
            if (score > best)
                best = score;
        }
        // Every word has to land somewhere, or this is not the setting asked for
        if (best === 0)
            return 0;
        total += best;
    }
    // A short label matching is a better answer than a long one matching, since
    // the query covers more of it
    return total / tokens.length + Math.max(0, 24 - prepared.length) * 0.001;
}

// Prepared entries, ranked, best first. `limit` caps how many come back.
function search(query, entries, limit) {
    const tokens = tokenise(query);
    if (tokens.length === 0)
        return [];

    const results = [];
    for (let i = 0; i < entries.length; i++) {
        const score = scoreEntry(tokens, entries[i]);
        if (score >= THRESHOLD)
            results.push({
                entry: entries[i].entry,
                score
            });
    }

    results.sort((a, b) => b.score - a.score);
    return limit > 0 ? results.slice(0, limit) : results;
}
