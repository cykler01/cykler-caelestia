pragma Singleton

import Quickshell
import Caelestia.I18n

Singleton {
    property var _regexCache: ({})

    function percent(value: int): string {
        // TRANSLATORS: %1 = a number
        return Tr.tr("%1%").arg(value);
    }

    function percentOne(value: real): string {
        return percent(Math.round(value * 100));
    }

    // NOTE(fork): a byte count in the largest unit it fits, e.g. "1.4 GB". Decimal units, since
    // that is what the things being counted here (downloads, transfer sizes) are quoted in
    function bytes(value: real): string {
        const units = [Tr.trCtx("B", "bytes"), Tr.trCtx("kB", "kilobytes"), Tr.trCtx("MB", "megabytes"), Tr.trCtx("GB", "gigabytes"), Tr.trCtx("TB", "terabytes")];
        let size = Math.max(0, value);
        let unit = 0;
        while (size >= 1000 && unit < units.length - 1) {
            size /= 1000;
            unit++;
        }
        // No decimal on bytes, and none once the number is big enough to not need one
        const places = unit === 0 || size >= 100 ? 0 : 1;
        // TRANSLATORS: %1 = a number, %2 = a unit such as MB
        return Tr.trCtx("%1 %2", "a size, e.g. 1.4 GB").arg(size.toFixed(places)).arg(units[unit]);
    }

    function testRegexList(filterList: list<string>, target: string): bool {
        const regexChecker = /^\^.*\$$/;
        for (const filter of filterList) {
            if (regexChecker.test(filter)) {
                let re = _regexCache[filter];
                if (!re) {
                    re = new RegExp(filter);
                    _regexCache[filter] = re;
                }
                if (re.test(target))
                    return true;
            } else {
                if (filter === target)
                    return true;
            }
        }
        return false;
    }
}
