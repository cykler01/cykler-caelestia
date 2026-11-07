.pragma library

// Geometry shared by the desktop widgets and the settings editor that arranges them: a square grid of `unit` px
// cells, and widgets that snap to it. Sizes are in cells.

const unit = 40;
// Space left between a card and the edge of its footprint, so neighbours never touch
const gap = 8;
// Every card is the same width; the height depends on what it shows, and comes from WidgetCatalog.qml
const cardCells = 8;
// Distance from the screen edge, and between the default columns, in cells
const margin = 2;

// Fallback heights, for entries that arrive without one (the widget's own height wins when it is given)
const heights = {
    calendar: 8,
    clock: 4,
    weather: 7,
    pomodoro: 5,
    resources: 5,
    network: 4,
    media: 6,
    lyrics: 8,
    battery: 4,
    bluetooth: 5,
    fetch: 8,
    visualiser: 5,
    sticky: 6,
    photo: 7,
    github: 4,
    todo: 5
};

function heightOf(id) {
    return heights[id] ?? 5;
}

// Where each widget sits, parallel to `entries` ([{ id, enabled, col, row, right }]); `col` counts from the right edge
// when `right` is set, so the result is in the screen's own columns whatever its width. Widgets that have been placed keep
// their cell (kept on screen). Any other widget, and any placed one whose cell another has taken since (say it was
// turned off, something moved in, and it was turned back on), flows into the first free space in `columns` columns
// from the `position` corner, so no two widgets ever overlap.
function place(entries, gridCols, gridRows, columns, position, heights) {
    const out = entries.map((e, i) => {
        const placed = e.col >= 0 && e.row >= 0;
        // The card's variant decides how many cells it takes; the widget itself is the fallback
        const h = heights?.[i] > 0 ? heights[i] : heightOf(e.id);
        const col = e.right ? gridCols - cardCells - e.col : e.col;
        return {
            id: e.id,
            type: e.type ?? "",
            // Where this placement's entry sits in the entry list, which is how cards and drags are keyed
            index: i,
            enabled: e.enabled,
            placed: placed,
            w: cardCells,
            h: h,
            col: placed ? Math.max(0, Math.min(col, gridCols - cardCells)) : 0,
            row: placed ? Math.max(0, Math.min(e.row, gridRows - h)) : 0
        };
    });

    // Widgets that are off take no space
    const taken = [];
    for (const p of out) {
        if (!p.enabled || !p.placed)
            continue;
        if (hits(taken, p.col, p.row, p.w, p.h))
            p.placed = false;
        else
            taken.push(p);
    }

    const flow = out.filter(p => p.enabled && !p.placed);
    if (flow.length === 0)
        return out;

    const ncols = Math.max(1, columns);
    const right = position.endsWith("right");
    const bottom = position.startsWith("bottom");
    const x0 = right ? gridCols - margin - ncols * cardCells : margin;
    const spill = Math.floor(gridCols / cardCells);

    flow.forEach((p, k) => {
        // The column this card would take in turn, then the others, then columns further in from the corner
        const order = [];
        for (let i = 0; i < ncols; i++)
            order.push((k + i) % ncols);
        for (let i = 1; i <= spill; i++)
            order.push(right ? -i : ncols - 1 + i);

        for (const c of order) {
            const col = x0 + c * cardCells;
            if (col < 0 || col + p.w > gridCols)
                continue;
            const row = freeRow(taken, col, p.w, p.h, gridRows, bottom);
            if (row >= 0) {
                p.col = col;
                p.row = row;
                taken.push(p);
                return;
            }
        }

        // The screen is full; the corner is as good as anywhere
        p.col = Math.max(0, Math.min(x0, gridCols - p.w));
        p.row = bottom ? Math.max(0, gridRows - margin - p.h) : margin;
        taken.push(p);
    });
    return out;
}

// Is any of `rects` overlapped by a w x h widget at (col, row)?
function hits(rects, col, row, w, h) {
    for (const r of rects) {
        if (col < r.col + r.w && col + w > r.col && row < r.row + r.h && row + h > r.row)
            return true;
    }
    return false;
}

// The first row, working in from the top (or the bottom) edge, where a w x h widget fits in column `col`; -1 if none
function freeRow(rects, col, w, h, gridRows, fromBottom) {
    if (fromBottom) {
        for (let row = gridRows - margin - h; row >= 0; row--) {
            if (!hits(rects, col, row, w, h))
                return row;
        }
    } else {
        for (let row = margin; row + h <= gridRows; row++) {
            if (!hits(rects, col, row, w, h))
                return row;
        }
    }
    return -1;
}

// What to store for a widget that ended up at column `col`: counted from whichever edge it is nearer, so it keeps to
// that side on screens of other widths
function anchor(col, w, gridCols) {
    const right = col + w / 2 > gridCols / 2;
    return {
        right: right,
        col: right ? gridCols - w - col : col
    };
}

// Does a w x h widget at (col, row) overlap any enabled widget other than the one at `skip`?
function collides(placements, skip, col, row, w, h) {
    for (let i = 0; i < placements.length; i++) {
        const p = placements[i];
        if (i === skip || !p.enabled)
            continue;
        if (col < p.col + p.w && col + w > p.col && row < p.row + p.h && row + h > p.row)
            return true;
    }
    return false;
}
