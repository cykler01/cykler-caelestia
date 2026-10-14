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

    required property string side
    required property real rootHeight
    required property var lock

    // Every entry's enabled/column/weight is read here so this is worked out again
    // whenever one changes, same as the desktop widgets' own placements property
    readonly property var items: {
        const entries = Config.lock.widgets.values;
        for (const e of entries)
            void [e.enabled, e.column, e.weight];
        return entries.filter(e => e.enabled && e.column === col.side);
    }

    // Ids of the widgets whose size is fixed to their natural content height rather than a
    // weight share - their weights are ignored
    readonly property var autoSized: ["fetch", "resources", "battery"]

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

    // Guard against no (or all-zero) flexible widgets so the share below never divides by
    // zero - the fixed widgets' weights don't count, they don't use a share
    readonly property real flexTotalWeight: col.items.filter(e => !col.autoSized.includes(e.id)).reduce((sum, e) => sum + e.weight, 0) || 1

    // The column's own spacing between items eats into the available height too - left out
    // of this, shares would sum to more than col.rootHeight once spacing is added on top,
    // pushing the last widget slightly past the bottom of the lock screen
    readonly property real budget: Math.max(0, col.rootHeight - Math.max(0, col.visibleCount - 1) * col.spacing)

    // A flexible entry's share: the weight-slice of whatever budget is left after the
    // fixed-size widgets have taken their natural heights
    function shareOf(weight: real): real {
        return Math.max(0, col.budget - col.autoHeight) / col.flexTotalWeight * weight;
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.medium
    // Safety net: if some widget's own minimum content still doesn't fit its share (a very
    // low weight, or a screen too short for anything else), clip rather than spill past the
    // lock screen's own edge
    clip: true

    Repeater {
        model: col.items

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
