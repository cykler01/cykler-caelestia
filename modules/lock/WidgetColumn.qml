pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

// One side column: whichever widgets are enabled and assigned to `side`, in the order the
// settings editor (Nexus > Lock screen > Widgets) put them in, each claiming a share of the
// column's height proportional to its weight among the other visible widgets in it - see
// Config.lock.widgets (modules/nexus/pages/panels/LockWidgetsPanel.qml writes it).
//
// Pulled out of Content.qml so the settings page's live preview (LockScreenPreview.qml) can
// reuse the exact same rendering/share math instead of a second, divergent copy of it.
ColumnLayout {
    id: col

    required property string side
    required property real rootHeight
    required property var lock

    Layout.fillWidth: true
    spacing: Tokens.spacing.medium
    // Safety net: if some widget's own minimum content still doesn't fit its share (a very
    // low weight, or a screen too short for anything else), clip rather than spill past the
    // lock screen's own edge
    clip: true

    // Every entry's enabled/column/weight is read here so this is worked out again
    // whenever one changes, same as the desktop widgets' own placements property
    readonly property var items: {
        const entries = Config.lock.widgets.values;
        for (const e of entries)
            void [e.enabled, e.column, e.weight];
        return entries.filter(e => e.enabled && e.column === col.side);
    }

    // Guard against an empty or all-zero column so the share below never divides by zero
    readonly property real totalWeight: col.items.reduce((sum, e) => sum + e.weight, 0) || 1

    // The column's own spacing between items eats into the available height too - left out
    // of this, shares would sum to more than col.rootHeight once spacing is added on top,
    // pushing the last widget slightly past the bottom of the lock screen
    readonly property real budget: Math.max(0, col.rootHeight - Math.max(0, col.items.length - 1) * col.spacing)

    function shareOf(weight: real): real {
        return weight / col.totalWeight * col.budget;
    }

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
                    // Same deal as WeatherInfo's share above - Fetch picks how many lines to
                    // show by comparing rootHeight against fetch3/4LinesHeight
                    readonly property real share: col.shareOf(modelData.weight)

                    Layout.fillWidth: true
                    Layout.preferredHeight: fetchWidget.share
                    Layout.minimumHeight: 0
                    rootHeight: fetchWidget.share
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
                    Layout.preferredHeight: col.shareOf(modelData.weight)
                    Layout.minimumHeight: 0
                }
            }

            DelegateChoice {
                roleValue: "battery"
                delegate: Battery {
                    id: batteryWidget

                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: col.shareOf(modelData.weight)
                    Layout.minimumHeight: 0
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
