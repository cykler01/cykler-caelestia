.pragma library

// How the quick toggles card lays its buttons out, shared by the card itself and the settings preview
// that arranges them, so the two can't drift apart.

// A toggle's width in columns: what it asks for, kept to 1..columns
function spanOf(toggle, columns) {
    return Math.max(1, Math.min(columns, toggle.span ?? 1));
}

// The toggles in rows of at most `columns` columns, in order. A row that comes up short stretches its
// toggles across the card rather than leaving a gap
function pack(toggles, columns) {
    const rows = [];
    let row = [];
    let used = 0;
    for (const toggle of toggles) {
        const span = spanOf(toggle, columns);
        if (used + span > columns) {
            rows.push(row);
            row = [];
            used = 0;
        }
        row.push(toggle);
        used += span;
    }
    if (row.length > 0)
        rows.push(row);
    return rows;
}
