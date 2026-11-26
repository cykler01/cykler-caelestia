pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// One side column: whichever widgets are enabled and assigned to `side`, in the order the
// settings editor (Nexus > Lock screen > Widgets) put them in. The flexible widgets (weather,
// media, notifications) claim a share of the column's height proportional to their weight
// among the other flexible widgets in it; the fixed ones (fetch, resources, battery) keep
// their original natural content height from before the customisation system, and the
// flexible widgets only share out whatever height is left over - see Config.lock.widgets
// (modules/nexus/pages/panels/LockWidgetsPanel.qml writes it).
//
// Pulled out of Content.qml so the settings page's live preview (LockScreenPreview.qml) can
// reuse the exact same rendering/share math instead of a second, divergent copy of it.
ColumnLayout {
    id: col

    // "left" or "right", or "all" for the sidebar layout's single stack of every enabled widget
    required property string side
    required property real rootHeight
    required property var lock

    // Ids this column knows how to render - anything else in the config (a widget removed
    // from the code, say) is skipped rather than falling through the DelegateChooser below
    readonly property var knownIds: [...col.autoSized, "weather", "media", "notifs"]

    // Every entry's enabled/column/weight is read here so this is worked out again
    // whenever one changes, same as the desktop widgets' own placements property
    readonly property var items: {
        const entries = Config.lock.widgets.values;
        for (const e of entries)
            void [e.enabled, e.column, e.weight];
        const all = entries.filter(e => e.enabled && (col.side === "all" || e.column === col.side) && col.knownIds.includes(e.id));
        if (col.fitHeight < 0)
            return all;

        // Keep widgets in order for as long as each fits whole, and leave the rest out rather
        // than cutting the last one off part way through
        const out = [];
        let used = 0;
        for (const e of all) {
            const h = col.autoSized.includes(e.id) ? (col.measured[e.id] ?? 0) : col.minFlexHeight;
            const add = h + (out.length > 0 && h > 0 ? col.spacing : 0);
            if (used + add > col.fitHeight)
                break;
            used += add;
            out.push(e);
        }
        return out;
    }

    // NOTE(fork): the free-standing layouts (modules/lock/layouts) set this to the height they can
    // spare, and widgets that won't fit whole are dropped from the end of the list. Below zero
    // (the classic card) everything is kept and clipped as before
    property real fitHeight: -1
    // The least a weighted widget is worth showing at, for the fit above
    property real minFlexHeight: 125
    // Last known natural heights of the fixed-size widgets by id (0 while one has nothing to show,
    // like battery on a desktop), kept even after one is dropped so the fit can be redone
    property var measured: ({})

    // Ids of the widgets whose size is fixed to their natural content height rather than a
    // weight share - their weights are ignored. Audio and network read live service state whose
    // card height doesn't depend on it, so they size naturally too
    readonly property var autoSized: ["fetch", "resources", "battery", "network", "audio", "events", "day"]

    // Every delegate's modelData is its config entry, so visible delegates are counted from
    // the actual children rather than `items` - an invisible one (battery on a desktop, say)
    // can't be seen in the config alone, and mustn't reserve a share or a spacing gap
    readonly property int visibleCount: {
        let n = 0;
        for (const child of col.children) {
            const it = child as Item;
            if (it && it.visible && it.modelData !== undefined)
                ++n;
        }
        return n;
    }

    // Total height already claimed by the visible fixed-size widgets (their natural implicit
    // heights, resolved once the delegates exist), which the flexible shares come out of
    readonly property real autoHeight: {
        const auto = col.autoSized;
        let sum = 0;
        for (const child of col.children) {
            const it = child as Item;
            if (it && it.visible && it.modelData !== undefined && auto.includes(it.modelData.id))
                sum += it.implicitHeight;
        }
        return sum;
    }

    // Whether anything in here takes a weight share of the height. Without one the column has no
    // use for more than its natural height, so the free-standing layouts pack it instead of
    // stretching it (which would only spread the fixed cards apart)
    readonly property bool hasFlex: col.items.some(e => !col.autoSized.includes(e.id))

    // Guard against no (or all-zero) flexible widgets so the share below never divides by
    // zero - the fixed widgets' weights don't count, they don't use a share
    readonly property real flexTotalWeight: col.items.filter(e => !col.autoSized.includes(e.id)).reduce((sum, e) => sum + e.weight, 0) || 1

    // The column's own spacing between items eats into the available height too - left out
    // of this, shares would sum to more than col.rootHeight once spacing is added on top,
    // pushing the last widget slightly past the bottom of the lock screen
    readonly property real budget: Math.max(0, col.rootHeight - Math.max(0, col.visibleCount - 1) * col.spacing)

    function measure(item: Item): void {
        const id = item?.modelData?.id;
        if (!id || !col.autoSized.includes(id))
            return;
        const h = item.visible ? item.implicitHeight : 0;
        if (col.measured[id] === h)
            return;
        const m = Object.assign({}, col.measured);
        m[id] = h;
        col.measured = m;
    }

    // The height this column wants when each weighted widget gets `unit` px per unit of weight,
    // for layouts that size it to its contents instead of handing it a fixed slice of the screen
    function naturalHeight(unit: real): real {
        return col.autoHeight + (col.hasFlex ? col.flexTotalWeight * unit : 0) + Math.max(0, col.visibleCount - 1) * col.spacing;
    }

    // A flexible entry's share: the weight-slice of whatever budget is left after the
    // fixed-size widgets have taken their natural heights
    function shareOf(weight: real): real {
        const free = Math.max(0, col.budget - col.autoHeight);
        if (col.fitHeight < 0)
            return free / col.flexTotalWeight * weight;

        // When fitting (the free-standing layouts), every weighted widget was let in on the
        // promise of minFlexHeight, so each gets that first and only what's left is split by
        // weight - otherwise a light one can end up shorter than its content
        const n = col.items.filter(e => !col.autoSized.includes(e.id)).length;
        const base = Math.min(col.minFlexHeight, free / Math.max(1, n));
        return base + Math.max(0, free - base * n) / col.flexTotalWeight * weight;
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.medium
    // Safety net: if some widget's own minimum content still doesn't fit its share (a very
    // low weight, or a screen too short for anything else), clip rather than spill past the
    // lock screen's own edge
    clip: true

    // Measures every widget now in the column, a moment after any of them changes size
    Timer {
        id: measureTimer

        interval: 0
        onTriggered: {
            for (let i = 0; i < measureRepeater.count; i++)
                col.measure(measureRepeater.itemAt(i));
        }
    }

    Repeater {
        id: measureRepeater

        model: col.items

        // Deferred: measuring straight away writes `measured` while `items` (which reads it) is
        // still handing out the delegates it just made, which Qt reports as a binding loop. A
        // timer of the column's own rather than Qt.callLater, so a column torn down before it
        // fires (a preview closed, an element removed) takes the pending measure with it
        // instead of leaving it to run against a context that's gone
        onItemAdded: (index, item) => {
            measureTimer.restart();
            item.implicitHeightChanged.connect(measureTimer.restart);
            item.visibleChanged.connect(measureTimer.restart);
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "weather"
                delegate: WeatherInfo {
                    id: weatherWidget

                    required property var modelData
                    // WeatherInfo decides whether to show the forecast by comparing this
                    // against Tokens.sizes.lock.showForecastHeight - it needs its own actual
                    // share, not the whole column's budget, or it grows past its lane
                    readonly property real share: col.shareOf(modelData.weight)

                    Layout.fillWidth: true
                    // No Math.max against implicitHeight here - that let a widget whose
                    // content wants more room than its share force the whole column past the
                    // lock screen's edge. A fixed share plus clip (on this widget and the
                    // column) means content that doesn't fit gets clipped, never overflowed
                    Layout.preferredHeight: weatherWidget.share
                    Layout.minimumHeight: 0
                    rootHeight: weatherWidget.share
                }
            }

            DelegateChoice {
                roleValue: "fetch"
                delegate: Fetch {
                    id: fetchWidget

                    required property var modelData

                    Layout.fillWidth: true
                    // Fixed at its natural content height (it sized itself before the
                    // customisation system existed) - the fit-to-scale inside it is now
                    // always 1, so nothing gets shrunk or clipped
                    Layout.preferredHeight: fetchWidget.implicitHeight
                    Layout.minimumHeight: fetchWidget.implicitHeight
                    rootHeight: col.rootHeight
                }
            }

            DelegateChoice {
                roleValue: "network"
                delegate: NetworkCard {
                    id: networkWidget

                    required property var modelData

                    Layout.fillWidth: true
                    // Fixed natural height, as above for Fetch
                    Layout.preferredHeight: networkWidget.implicitHeight
                    Layout.minimumHeight: networkWidget.implicitHeight
                }
            }

            DelegateChoice {
                roleValue: "media"
                delegate: Media {
                    id: mediaWidget

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: col.shareOf(modelData.weight)
                    Layout.minimumHeight: 0
                    lock: col.lock
                }
            }

            DelegateChoice {
                roleValue: "resources"
                delegate: Resources {
                    id: resourcesWidget

                    required property var modelData

                    Layout.fillWidth: true
                    // Fixed natural height, as above for Fetch
                    Layout.preferredHeight: resourcesWidget.implicitHeight
                    Layout.minimumHeight: resourcesWidget.implicitHeight
                }
            }

            DelegateChoice {
                roleValue: "battery"
                delegate: Battery {
                    id: batteryWidget

                    required property var modelData

                    Layout.fillWidth: true
                    // Fixed natural height, as above for Fetch - and when there's nothing to
                    // show at all (no laptop battery) it's invisible and takes no height,
                    // which the shares above recompute around via col.autoHeight
                    Layout.preferredHeight: batteryWidget.implicitHeight
                    Layout.minimumHeight: batteryWidget.implicitHeight
                }
            }

            DelegateChoice {
                roleValue: "audio"
                delegate: AudioCard {
                    id: audioWidget

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: audioWidget.implicitHeight
                    Layout.minimumHeight: audioWidget.implicitHeight
                }
            }

            DelegateChoice {
                roleValue: "day"
                delegate: DayCard {
                    id: dayWidget

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: dayWidget.implicitHeight
                    Layout.minimumHeight: dayWidget.implicitHeight
                }
            }

            DelegateChoice {
                roleValue: "events"
                delegate: EventsCard {
                    id: eventsWidget

                    required property var modelData

                    Layout.fillWidth: true
                    // Fixed natural height, as above for Fetch: a few rows at most
                    Layout.preferredHeight: eventsWidget.implicitHeight
                    Layout.minimumHeight: eventsWidget.implicitHeight
                }
            }

            DelegateChoice {
                roleValue: "notifs"
                delegate: NotifCard {
                    id: notifWidget

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: col.shareOf(modelData.weight)
                    Layout.minimumHeight: 0
                    lock: col.lock
                }
            }
        }
    }
}
