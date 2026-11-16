pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.I18n
import qs.services

// Every temperature and fan the kernel exposes through hwmon, for the desktop's temperature card.
//
// Cpu and Gpu each report one temperature, which is all the bar and the dashboard need; the temperature card
// also wants the drives, the wireless card and the fans. Only polls while something holds a reference (see
// components/misc/Ref.qml), and slows down with the rest of the shell on battery.
Singleton {
    id: root

    property int refCount: 0
    readonly property int interval: 4000 * PowerSaving.pollSlowdown

    // [{ key, kind, label, value, crit }], CPU first, then graphics, drives, everything else and the fans.
    // `kind` is cpu, gpu, drive, wifi, other or fan; `value` is Celsius, or RPM for a fan; `crit` is where the
    // chip says it is in trouble, or 0 when it does not say
    property var readings: []
    // Whether a reading has come back yet, so a card can tell "no sensors" from "not read yet"
    property bool loaded

    readonly property var temperatures: root.readings.filter(r => r.kind !== "fan")
    readonly property var fans: root.readings.filter(r => r.kind === "fan")
    // -1 when the machine has no such sensor (no hwmon driver for the GPU, as with NVIDIA's own driver)
    readonly property real cpu: root.temperatures.find(r => r.kind === "cpu")?.value ?? -1
    readonly property real gpu: root.temperatures.find(r => r.kind === "gpu")?.value ?? -1
    readonly property var hottest: root.temperatures.reduce((h, r) => !h || r.value > h.value ? r : h, null)

    // How worrying a temperature is, from 0 (cool) to 1 (at its limit). Against the chip's own critical point
    // when it gives one, which matters for drives that throttle well below a processor's 100 degrees
    function heat(celsius: real, crit: real): real {
        const top = crit > 0 ? crit : 100;
        // Room temperature is the floor, so an idle machine reads as cool rather than a third of the way up
        return Math.max(0, Math.min(1, (celsius - 30) / (top - 30)));
    }

    // Which part a hwmon chip measures, by its driver name
    function kindFor(chip: string): string {
        if (/^(k10temp|k8temp|coretemp|zenpower|cpu_thermal|cpu-thermal)/.test(chip))
            return "cpu";
        if (/^(amdgpu|radeon|nouveau|i915|xe)$/.test(chip))
            return "gpu";
        if (/^(nvme|drivetemp)/.test(chip))
            return "drive";
        if (/^(iwlwifi|mt7\d+|ath\d+k|rtw|brcm)/.test(chip))
            return "wifi";
        return "other";
    }

    // The sensor that stands for the whole chip, when it has several: the processor's control temperature,
    // the graphics card's edge, a drive's composite
    readonly property var preferredLabels: ["Tctl", "Tdie", "Package id 0", "edge", "Composite"]

    function labelFor(kind: string, chip: string, count: int): string {
        const nth = count > 1 ? ` ${count}` : "";
        if (kind === "cpu")
            return Tr.tr("Processor") + nth;
        if (kind === "gpu")
            return Tr.tr("Graphics") + nth;
        if (kind === "drive")
            return (chip === "nvme" ? Tr.tr("NVMe drive") : Tr.tr("Drive")) + nth;
        if (kind === "wifi")
            return Tr.tr("Wi-Fi card") + nth;
        return chip;
    }

    function fanLabel(label: string, index: int): string {
        if (/cpu/i.test(label))
            return Tr.tr("CPU fan");
        if (/gpu/i.test(label))
            return Tr.tr("GPU fan");
        // TRANSLATORS: %1 = the fan's number
        return label !== "" ? label : Tr.tr("Fan %1").arg(index);
    }

    function parse(text: string): void {
        // hwmonN/file:value, one per line, straight from grep
        const chips = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(hwmon\d+)\/([a-z]+\d*)(?:_([a-z]+))?:(.*)$/);
            if (!m)
                continue;
            if (!chips[m[1]])
                chips[m[1]] = {
                    name: "",
                    sensors: {}
                };
            const chip = chips[m[1]];
            if (m[2] === "name") {
                chip.name = m[4].trim();
                continue;
            }
            if (!chip.sensors[m[2]])
                chip.sensors[m[2]] = {};
            chip.sensors[m[2]][m[3]] = m[4].trim();
        }

        const counts = {};
        const temps = [];
        const fans = [];

        // In hwmon order, so the list does not reshuffle between polls
        const ids = Object.keys(chips).sort((a, b) => parseInt(a.slice(5)) - parseInt(b.slice(5)));
        for (const id of ids) {
            const chip = chips[id];
            const kind = root.kindFor(chip.name);

            for (const [key, s] of Object.entries(chip.sensors)) {
                if (!key.startsWith("fan") || s.input === undefined)
                    continue;
                fans.push({
                    key: `${id}/${key}`,
                    kind: "fan",
                    label: root.fanLabel(s.label ?? "", fans.length + 1),
                    value: parseInt(s.input) || 0,
                    crit: 0
                });
            }

            // ACPI thermal zones are firmware guesses, often a fixed number that never moves, and the
            // unlabelled sensors of a board's super-I/O chip are mostly unconnected pins
            if (chip.name === "acpitz")
                continue;

            const candidates = Object.entries(chip.sensors).filter(([key, s]) => key.startsWith("temp") && s.input !== undefined).map(([key, s]) => ({
                        key,
                        label: s.label ?? "",
                        value: parseInt(s.input) / 1000,
                        crit: (parseInt(s.crit) || 0) / 1000
                    })).filter(c => c.value > 0 && c.value < 150 && (kind !== "other" || c.label !== ""));
            if (candidates.length === 0)
                continue;

            // One reading per chip for the parts we know, which is what the card has room for. A board
            // chip's labelled sensors are each their own thing, so those are all kept
            const picks = kind === "other" ? candidates : [candidates.find(c => root.preferredLabels.includes(c.label)) ?? candidates[0]];
            for (const p of picks) {
                counts[kind] = (counts[kind] ?? 0) + 1;
                temps.push({
                    key: `${id}/${p.key}`,
                    kind,
                    label: kind === "other" ? p.label : root.labelFor(kind, chip.name, counts[kind]),
                    value: p.value,
                    crit: p.crit > 0 && p.crit < 150 ? p.crit : 0
                });
            }
        }

        const order = ["cpu", "gpu", "drive", "wifi", "other"];
        temps.sort((a, b) => order.indexOf(a.kind) - order.indexOf(b.kind));

        root.readings = temps.concat(fans);
        root.loaded = true;
    }

    // Nothing is holding the readings any more; the next card to come along should not briefly show what
    // the machine was doing a while ago
    onRefCountChanged: {
        if (root.refCount <= 0) {
            root.readings = [];
            root.loaded = false;
        }
    }

    Timer {
        interval: root.interval
        running: root.refCount > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    // One grep over every file of interest rather than a read per file: a dozen sensors would otherwise be a
    // dozen processes every few seconds. The globs that match nothing stay as they are, and -s keeps grep
    // quiet about them
    Process {
        id: poll

        command: ["sh", "-c", "cd /sys/class/hwmon 2>/dev/null && grep -s . */name */temp*_input */temp*_label */temp*_crit */fan*_input */fan*_label"]

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
}
