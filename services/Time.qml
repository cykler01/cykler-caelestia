pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n

Singleton {
    id: root

    // Things that show seconds (the dashboard's clock card) hold a count here while they exist. With none of those
    // and no seconds in the bar's clock, the clock only ticks once a minute, which keeps the shell asleep in between.
    property int secondsUsers

    property alias enabled: clock.enabled
    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds

    readonly property string timeStr: format(Units.twelveHourClock ? "hh:mm:A" : "hh:mm")
    readonly property list<string> timeComponents: timeStr.split(":")
    readonly property string hourStr: timeComponents[0] ?? ""
    readonly property string minuteStr: timeComponents[1] ?? ""
    readonly property string amPmStr: timeComponents[2] ?? ""

    function format(fmt: string): string {
        return Qt.formatDateTime(clock.date, fmt);
    }

    SystemClock {
        id: clock

        precision: root.secondsUsers > 0 || GlobalConfig.bar.clock.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
