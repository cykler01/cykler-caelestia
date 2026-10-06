#!/usr/bin/env python3
"""Checks QML convention violations against a recorded baseline.

The fork has a backlog of violations that predates this check, so failing on
every one of them would leave every pull request red and teach nobody
anything. Instead the counts already recorded in the baseline are allowed, and
anything beyond them is an error. Fixing violations is always allowed, and the
report says which baseline entries have gone stale so they can be dropped with
--update.

Errors, which make the command exit 1:
  - a violation in a file that has no baseline entry at all, i.e. a new file
  - more violations of a rule than the baseline allows, including a rule
    appearing in a file that did not have it before

Warnings, which are merely reported:
  - a file or rule with fewer violations than the baseline, which can be
    recorded with --update so the allowance shrinks

By default every *.qml under the repo root is checked. Pass paths to check only
those. The report always goes to stderr, and colour is dropped when stderr is
not a terminal. The exit code is 1 when something is not allowed.

Usage:
  scripts/qml-lint-ratchet.py                  # check everything
  scripts/qml-lint-ratchet.py path/to/File.qml # check one file
  scripts/qml-lint-ratchet.py --update         # rewrite the baseline
"""

import argparse
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

RED = "\033[0;31m"
YELLOW = "\033[0;33m"
GREEN = "\033[0;32m"
BOLD = "\033[1m"
RESET = "\033[0m"

REPO_ROOT = Path(__file__).resolve().parent.parent
LINTER = REPO_ROOT / "scripts" / "qml-lint-conventions.py"
BASELINE = REPO_ROOT / "scripts" / "qml-lint-baseline.json"


def colour(code: str, text: str) -> str:
    return f"{code}{text}{RESET}" if sys.stderr.isatty() else text


def run_linter() -> Counter:
    """Violations as a Counter keyed by (file, rule) for the whole repo.

    --file takes a single path, so checking a subset is done by filtering what
    one repo-wide call returns instead of calling the linter once per file.
    The report goes to stderr whichever format is asked for, and the linter
    exits 1 when it finds anything, so its exit code is deliberately ignored.
    """
    result = subprocess.run(
        [sys.executable, str(LINTER), "--json"], cwd=REPO_ROOT, capture_output=True, text=True
    )
    try:
        report = json.loads(result.stderr)
    except json.JSONDecodeError:
        print(result.stderr, file=sys.stderr, end="")
        sys.exit("qml-lint-ratchet: could not read the linter's JSON report")

    return Counter((v["file"], v["rule"]) for v in report["violations"])


def read_baseline() -> Counter:
    if not BASELINE.is_file():
        sys.exit(f"qml-lint-ratchet: no baseline at {BASELINE.relative_to(REPO_ROOT)} - run --update")

    data = json.loads(BASELINE.read_text())
    return Counter({(path, rule): count for path, rules in data.items() for rule, count in rules.items()})


def write_baseline(counts: Counter) -> None:
    data: dict[str, dict[str, int]] = {}
    for (path, rule), count in sorted(counts.items()):
        data.setdefault(path, {})[rule] = count
    BASELINE.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def check(files: list[str]) -> int:
    current = run_linter()
    allowed = read_baseline()

    # Filtering both sides keeps a subset run from reporting every other file's
    # baseline as stale, and from failing on violations outside the subset
    if files:
        wanted = set(files)
        current = Counter({k: v for k, v in current.items() if k[0] in wanted})
        allowed = Counter({k: v for k, v in allowed.items() if k[0] in wanted})

    new = {k: v for k, v in current.items() if v > allowed.get(k, 0)}
    stale = {k: v for k, v in allowed.items() if v > current.get(k, 0)}
    unchanged = sum(v for k, v in current.items() if k not in new)

    for (path, rule), count in sorted(new.items()):
        where = f"baseline allows {allowed[(path, rule)]}" if (path, rule) in allowed else "no baseline entry for this file"
        print(colour(RED, f"{path}: {count} {rule} violation(s), {where}"), file=sys.stderr)

    if new:
        print(file=sys.stderr)
        print(colour(RED, f"{BOLD}New violation(s) - fix them, or record them with --update if they are deliberate:{RESET}"), file=sys.stderr)
        for (path, rule), count in sorted(new.items()):
            print(colour(RED, f"  {path}: {rule} {allowed.get((path, rule), 0)} -> {count}"), file=sys.stderr)

    for (path, rule), allowance in sorted(stale.items()):
        print(colour(YELLOW, f"{path}: {rule} down to {current.get((path, rule), 0)} from {allowance} - run --update to shrink the allowance"), file=sys.stderr)

    if not new:
        print(colour(GREEN, f"No new convention violations ({unchanged} known one(s) allowed)"), file=sys.stderr)

    return 1 if new else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("paths", nargs="*", help="files to check; every *.qml under the repo root by default")
    parser.add_argument("--update", action="store_true", help="rewrite the baseline from the repo as it is now")
    args = parser.parse_args()

    if args.update and args.paths:
        parser.error("--update rewrites the whole baseline, so it takes no paths")

    if args.update:
        write_baseline(run_linter())
        print(f"Wrote {BASELINE.relative_to(REPO_ROOT)}", file=sys.stderr)
        return 0

    missing = [p for p in args.paths if not (REPO_ROOT / p).is_file()]
    if missing:
        # A deleted file has nothing to check, which is not a failure
        print(f"Skipping {len(missing)} path(s) that are not files: {', '.join(missing)}", file=sys.stderr)

    return check([p for p in args.paths if p not in missing])


if __name__ == "__main__":
    sys.exit(main())
