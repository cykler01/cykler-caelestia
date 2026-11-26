import QtQuick
import Caelestia.I18n
import qs.services

// The date or time as text: one of the formats offered, or a pattern of the user's own (Qt's
// date format: d, ddd, dddd, M, MMM, MMMM, yyyy, hh, mm, ...)
TextBlock {
    readonly property string pattern: {
        if ((opts.pattern ?? "") !== "")
            return opts.pattern;
        if (opts.format === "time")
            return Units.twelveHourClock ? "h:mm A" : "hh:mm";
        return opts.format ?? "dddd, d MMMM";
    }

    content: Time.format(pattern)
}
