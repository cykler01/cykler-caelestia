#!/usr/bin/env python3
"""Generates modules/nexus/SettingsIndex.qml from the Nexus settings pages.

The settings search matches individual rows, not just page names, so it needs a
flat list of every toggle, slider, stepper, picker and text field the settings
window can show, tagged with the page and sub-page stack that reaches it. That
list is mechanical, so it is generated here rather than hand written and left to
rot: this walks the page sources, pulls out the rows along with the section
header above each one, and writes them back out as a QML singleton.

Run it after adding, removing or renaming a settings row:

    python3 scripts/gen-settings-index.py

Pass --check to only verify the committed file is up to date (exit 1 when it is
not), which is what CI does, and --stdout to print the file instead of writing
it.

A row can carry extra search terms that are never shown, for spellings and
synonyms the labels do not use, with a comment on the line above its label:

    ToggleRow {
        // SEARCH: wifi wireless internet
        text: Tr.tr("Wi-Fi")
"""

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PAGES_DIR = REPO_ROOT / "modules" / "nexus" / "pages"
OUT_FILE = REPO_ROOT / "modules" / "nexus" / "SettingsIndex.qml"

# Each page's sub-page components, in the order PageCompRegistry.pageComps lists
# them: the position here is the index openSubPage() takes. Keyed by the page
# key in PageRegistry.pages.
PAGES: dict[str, list[str]] = {
    "wallpaper": ["WallpaperAndStyle", "WallpaperSelect", "WallpaperCategory", "ColourSelect"],
    "assets": ["AssetsPage"],
    "panels": [
        "PanelsPage", "DashboardPanel", "TaskbarPanel", "LauncherPanel", "SidebarPanel",
        "UtilitiesPanel", "BarWorkspaces", "BarActiveWindow", "BarTray", "BarStatusIcons",
        "BarClock", "NotchPanel", "OverviewPanel", "DesktopPanel", "LockPanel", "BarLayout",
        "SessionPanel", "LockWidgetsPanel", "WidgetsPanel", "AddWidgetPanel", "DashWidgetsPanel",
    ],
    "layout": ["LayoutPage"],
    "apps": ["AppsPage", "AllApps", "AppInfo"],
    "services": ["ServicesPage", "NotificationsPage", "DiscordPage", "NotificationSourcesPage"],
    "network": [
        "NetworkPage", "EthernetDetailPage", "AddNetworkPage", "NetworkDetailPage",
        "AddVpnPage", "AllNetworksPage", "SavedNetworksPage",
    ],
    "bluetooth": ["BluetoothPage", "BtDeviceInfo", "BluetoothPairing"],
    "display": ["MonitorsPane", "MonitorDetail"],
    "audio": ["AudioPage", "AppVolumes"],
    "input": ["InputPage"],
    "keybinds": ["KeybindsPage"],
    "power": ["BatteryPage"],
    "language": ["LanguageAndRegion"],
    "updates": ["UpdatesPage"],
    "about": ["AboutPage"],
}

# Sub-pages only reachable once something is picked on the page before them: a
# device, a monitor, a saved network. A search result cannot push those, so its
# rows link to the nearest page that opens without a selection, named here.
NEEDS_SELECTION = {
    "WallpaperCategory": "WallpaperSelect",
    "AppInfo": "AllApps",
    "EthernetDetailPage": "NetworkPage",
    "NetworkDetailPage": "NetworkPage",
    "AddVpnPage": "NetworkPage",
    "BtDeviceInfo": "BluetoothPage",
    "MonitorDetail": "MonitorsPane",
}

# Row types holding one setting. Anything else in a page is layout or chrome.
ROW_TYPES = {
    "AssetRow", "ComboBoxRow", "InfoRow", "NavRow", "PopupRow", "PowerProfileSelector",
    "RefreshRateSelector", "RowButton", "SelectRow", "SliderRow", "StepperRow",
    "TextFieldRow", "TimeoutRow", "ToggleRow", "TriStateRow",
}

# A label or subtext with a placeholder in it is filled in at runtime, so the
# source string is not what the page shows and is no use in a result.
PLACEHOLDER_RE = re.compile(r"%[0-9n]")

# Extra search terms per row, as `page/Component/Label`. Prefer a `// SEARCH:`
# comment in the page source; this is for rows whose source is awkward to touch.
EXTRA_KEYWORDS: dict[str, str] = {}

# Pages built out of custom widgets rather than rows, so there is nothing to walk
# for. Their entries are listed by hand, as (section, label, subtext, keywords).
MANUAL_ENTRIES: dict[str, list[tuple[str, str, str, str]]] = {
    "LayoutPage": [
        ("", "Move the bar", "Drag the taskbar, dashboard, launcher and notch to another screen edge", "position place relocate side edge"),
        ("", "Desktop widget position", "Drag the desktop widgets and app icons to a corner", "wallpaper icons corner"),
        ("", "Reset layout", "Put every panel back where it started", "default restore"),
    ],
    "KeybindsPage": [
        ("", "Keyboard shortcuts", "View and change the Hyprland keybinds", "keybind hotkey shortcut binding hypr"),
    ],
    "MonitorsPane": [
        ("", "Arrange displays", "Drag the monitors to set how they sit next to each other", "monitor screen position arrangement multi"),
    ],
    "AllApps": [
        ("", "Favourite apps", "Pin apps to the top of the launcher", "pinned starred launcher"),
        ("", "Hidden apps", "Keep apps out of the launcher", "hide exclude launcher"),
    ],
    "AppVolumes": [
        ("", "Per app volume", "Set the volume of each app separately", "mixer application loudness"),
    ],
    "NotificationSourcesPage": [
        ("", "Notification sources", "Mute or allow notifications per app", "app block mute allow per app"),
    ],
    "LockWidgetsPanel": [
        ("", "Lock screen widgets", "Reorder, resize and show or hide what's on the lock screen", "lockscreen cards columns"),
    ],
    "DashWidgetsPanel": [
        ("", "Dashboard widgets", "Reorder, resize and show or hide the dashboard cards", "cards tiles home"),
    ],
    "BarLayout": [
        ("", "Taskbar layout", "Choose what the bar shows and in what order", "bar components order arrange"),
    ],
    "AddWidgetPanel": [
        ("", "Add a desktop widget", "Pick a widget and a variant to put on the wallpaper", "new card wallpaper"),
    ],
    "BluetoothPairing": [
        ("", "Pair a device", "Scan for and pair a new Bluetooth device", "connect new bluetooth scan"),
    ],
    "AllNetworksPage": [
        ("", "All networks", "Every Wi-Fi network in range", "wifi scan available ssid"),
    ],
    "SavedNetworksPage": [
        ("", "Saved networks", "Wi-Fi networks already stored, and forgetting them", "wifi known forget stored"),
    ],
}

STRING_RE = re.compile(
    r"""^\s*(?:Tr\.trCtx|Tr\.tr|qsTr)\(\s*"((?:[^"\\]|\\.)*)"|^\s*"((?:[^"\\]|\\.)*)"\s*$"""
)
OPEN_RE = re.compile(r"^(\s*)([A-Z][A-Za-z0-9_]*)\s*\{\s*$")
COMPONENT_RE = re.compile(r"^\s*component\s+([A-Z][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Za-z0-9_]*)\s*\{\s*$")
SEARCH_COMMENT_RE = re.compile(r"^\s*//\s*SEARCH:\s*(.+?)\s*$")


def literal(value: str) -> str | None:
    """Pulls the source string out of a binding, or None when it isn't a literal."""
    m = STRING_RE.match(value)
    if not m:
        return None
    return m.group(1) if m.group(1) is not None else m.group(2)


def find_sources() -> dict[str, Path]:
    return {p.stem: p for p in PAGES_DIR.rglob("*.qml")}


class Row:
    def __init__(self, section: str, label: str, subtext: str, keywords: str):
        self.section = section
        self.label = label
        self.subtext = subtext
        self.keywords = keywords


def block_end(lines: list[str], start: int) -> int:
    """Index of the line closing the block opened on `start`."""
    depth = 0
    for i in range(start, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth <= 0:
            return i
    return len(lines) - 1


def parse_props(lines: list[str], start: int, end: int) -> tuple[dict[str, str], str]:
    """The literal properties set directly on a block, plus its SEARCH terms."""
    props: dict[str, str] = {}
    keywords = ""
    depth = 0
    for i in range(start, end + 1):
        line = lines[i]
        if depth == 1:
            m = SEARCH_COMMENT_RE.match(line)
            if m:
                keywords = m.group(1)
            m = re.match(r"^\s*(\w+):\s*(.+?)\s*$", line)
            if m:
                value = literal(m.group(2))
                if value is not None:
                    props.setdefault(m.group(1), value)
        depth += line.count("{") - line.count("}")
    return props, keywords


def parse_page(path: Path) -> tuple[str, list[Row]]:
    """A page's title and its rows, in the order they are declared."""
    lines = path.read_text().split("\n")

    # Local `component Foo: ToggleRow` definitions count as rows where they are used
    local_rows = {
        m.group(1)
        for line in lines
        if (m := COMPONENT_RE.match(line)) and m.group(2) in ROW_TYPES
    }
    # ...and local wrappers around a ColumnLayout hold rows of their own, which
    # belong to whichever section the wrapper is used in
    local_groups: dict[str, int] = {
        m.group(1): idx
        for idx, line in enumerate(lines)
        if (m := COMPONENT_RE.match(line)) and m.group(2) not in ROW_TYPES
    }

    title = ""
    for i, line in enumerate(lines):
        m = re.match(r"^\s*title:\s*(.+?)\s*$", line)
        if m and (value := literal(m.group(2) if m.lastindex == 2 else m.group(1))) is not None:
            title = value
            break

    def walk(start: int, end: int, section: str, inside_group: bool) -> tuple[list[Row], str]:
        """Rows declared between two lines, and the section left open at the end.

        Sections run across nesting: a header inside a wrapper ColumnLayout still
        titles the rows after it, so the section is threaded through the recursion
        rather than reset per block.
        """
        rows: list[Row] = []
        i = start
        while i <= end:
            m = OPEN_RE.match(lines[i])
            if not m:
                i += 1
                continue
            typ = m.group(2)
            close = min(block_end(lines, i), end)
            if typ in local_groups and not inside_group:
                # Expand the wrapper where it is used, so its rows land in this section
                g_start = local_groups[typ]
                g_rows, section = walk(g_start + 1, block_end(lines, g_start), section, True)
                rows.extend(g_rows)
            elif typ == "SectionHeader":
                props, _ = parse_props(lines, i, close)
                section = props.get("text", "")
            elif typ in ROW_TYPES or typ in local_rows:
                props, keywords = parse_props(lines, i, close)
                label = props.get("label") or props.get("text")
                subtext = props.get("subtext", "")
                if PLACEHOLDER_RE.search(subtext):
                    subtext = ""
                if label and not PLACEHOLDER_RE.search(label):
                    rows.append(Row(section, label, subtext, keywords))
            else:
                # Layout or chrome, but the rows are usually nested inside it
                inner, section = walk(i + 1, close, section, inside_group)
                rows.extend(inner)
            i = close + 1
        return rows, section

    # Skip the local component definitions on the top-level pass; they are picked
    # up where they are used
    body_end = min(local_groups.values()) - 1 if local_groups else len(lines) - 1
    rows, _ = walk(0, body_end, "", False)
    return title, rows


def build() -> list[dict[str, object]]:
    sources = find_sources()
    titles: dict[str, str] = {}
    parsed: dict[str, list[Row]] = {}
    comp_page: dict[str, tuple[str, int]] = {}

    for page_key, comps in PAGES.items():
        for idx, comp in enumerate(comps):
            comp_page[comp] = (page_key, idx)

    for comp, (page_key, _) in comp_page.items():
        src = sources.get(comp)
        if src is None:
            sys.exit(f"No source found for {comp} (page {page_key})")
        titles[comp], parsed[comp] = parse_page(src)

    # Which page opens each sub-page, so a result can push the whole stack and the
    # back arrow walks out the way the user would have come in
    opener: dict[str, str] = {}
    for comp, (page_key, _) in comp_page.items():
        text = sources[comp].read_text()
        for m in re.finditer(r"openSubPage\((\d+)\)", text):
            target = PAGES[page_key][int(m.group(1))]
            opener.setdefault(target, comp)
    # Rows and lists in common/ open a few of them instead of the page itself
    for comp, text_file in (("EthernetDetailPage", "EthernetSection"), ("NetworkDetailPage", "NetworkList")):
        opener.setdefault(comp, "NetworkPage")

    def path_of(comp: str) -> list[int]:
        page_key, idx = comp_page[comp]
        if idx == 0:
            return []
        parent = opener.get(comp)
        if parent is None or parent == comp:
            return [idx]
        return path_of(parent) + [idx]

    entries: list[dict[str, object]] = []
    # Two rows reaching the same place under the same name are one result: a
    # detail page folded into its parent repeats IP address, Gateway and the rest
    seen: dict[tuple[str, tuple[int, ...], str], dict[str, object]] = {}
    for page_key, comps in PAGES.items():
        for comp in comps:
            # A sub-page needing a selection cannot be deep linked, so point its
            # rows at the last page that does open on its own
            link = NEEDS_SELECTION.get(comp, comp)
            path = path_of(link)
            rows = list(parsed[comp])
            for section, label, subtext, keywords in MANUAL_ENTRIES.get(comp, []):
                rows.append(Row(section, label, subtext, keywords))
            for row in rows:
                key = f"{page_key}/{comp}/{row.label}"
                extra = " ".join(filter(None, [row.keywords, EXTRA_KEYWORDS.get(key, "")]))
                dedup = (page_key, tuple(path), row.label)
                if dedup in seen:
                    merged = " ".join(filter(None, [str(seen[dedup]["keywords"]), extra]))
                    seen[dedup]["keywords"] = merged
                    continue
                entry = {
                    "page": page_key,
                    "path": path,
                    # The title of the page the result lands on, which is not always
                    # the one declaring the row. Also how the page checks a highlight
                    # is meant for it rather than for a page further in.
                    "title": titles[link],
                    "section": row.section,
                    "label": row.label,
                    "subtext": row.subtext,
                    "keywords": extra,
                }
                seen[dedup] = entry
                entries.append(entry)
    return entries


def qml_string(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'Tr.tr("{escaped}")'


def render(entries: list[dict[str, object]]) -> str:
    out = [
        "pragma Singleton",
        "",
        "import QtQuick",
        "import Caelestia.I18n",
        "",
        "// GENERATED by scripts/gen-settings-index.py - do not edit by hand.",
        "//",
        "// Every individual setting the Nexus pages show, so the search field can match a",
        "// toggle by name instead of only the page it sits on. `page` and `path` are the",
        "// page and the sub-page stack a result opens, `title` is what that page calls",
        "// itself, and `section` is the header above the row - together they are the",
        "// breadcrumb that tells two settings both named \"Enabled\" apart.",
        "QtObject {",
        "    id: root",
        "",
        "    readonly property list<var> entries: [",
    ]
    last_group = None
    body: list[str] = []
    for entry in entries:
        group = (entry["page"], tuple(entry["path"]))
        if last_group is not None and group != last_group:
            body.append("")
        last_group = group
        parts = [
            f'page: "{entry["page"]}"',
            f'path: [{", ".join(str(i) for i in entry["path"])}]',
        ]
        if entry["title"]:
            parts.append(f'title: {qml_string(entry["title"])}')
        if entry["section"]:
            parts.append(f'section: {qml_string(entry["section"])}')
        parts.append(f'label: {qml_string(entry["label"])}')
        if entry["subtext"]:
            parts.append(f'subtext: {qml_string(entry["subtext"])}')
        if entry["keywords"]:
            parts.append(f'keywords: "{entry["keywords"]}"')
        body.append("        {")
        for part in parts:
            body.append(f"            {part},")
        body[-1] = body[-1][:-1]
        body.append("        },")
    if body:
        body[-1] = body[-1][:-1]
    out.extend(body)
    out.extend(["    ]", "}", ""])
    return "\n".join(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="only verify the committed file matches")
    parser.add_argument("--stdout", action="store_true", help="print the file instead of writing it")
    args = parser.parse_args()

    rendered = render(build())

    if args.stdout:
        print(rendered, end="")
        return 0

    if args.check:
        current = OUT_FILE.read_text() if OUT_FILE.exists() else ""
        if current != rendered:
            print(
                f"{OUT_FILE.relative_to(REPO_ROOT)} is out of date - "
                "run python3 scripts/gen-settings-index.py",
                file=sys.stderr,
            )
            return 1
        return 0

    OUT_FILE.write_text(rendered)
    print(f"Wrote {OUT_FILE.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
