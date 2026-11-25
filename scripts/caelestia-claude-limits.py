#!/usr/bin/env python3
"""Prints the signed-in Claude account's usage limits as one JSON line, for the desktop widget.

Reads the OAuth token Claude Code keeps in ~/.claude/.credentials.json (or $CLAUDE_CONFIG_DIR)
and asks Anthropic's usage endpoint, the same one Claude Code's /usage reads, how much of the
rolling 5-hour window and of the week has been used.

    {"type": "usage", "plan": "max", "fiveHour": {"used": 42.0, "resetsAt": 1764000000},
     "weekly": {"used": 18.0, "resetsAt": 1764500000}, "fetchedAt": 1763990000}
    {"type": "error", "reason": "signed-out" | "expired" | "network" | "http", "message": ...}

"used" is a percentage, 0-100; "resetsAt" is seconds since the epoch, or null while the window
has not started. The token is never refreshed here: that rotates the refresh token, which would
sign Claude Code itself out. An expired one is reported, and Claude Code renews it the next time
it runs.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime

URL = "https://api.anthropic.com/api/oauth/usage"
TIMEOUT_S = 15


def emit(obj: dict) -> None:
    print(json.dumps(obj, separators=(",", ":")), flush=True)


def fail(reason: str, message: str) -> None:
    emit({"type": "error", "reason": reason, "message": message})
    sys.exit(0)


def credentials() -> dict:
    base = os.environ.get("CLAUDE_CONFIG_DIR") or os.path.expanduser("~/.claude")
    try:
        with open(os.path.join(base, ".credentials.json")) as f:
            oauth = json.load(f).get("claudeAiOauth") or {}
    except (OSError, ValueError):
        oauth = {}
    if not oauth.get("accessToken"):
        fail("signed-out", "Not signed in to Claude Code")
    return oauth


def epoch(v) -> int | None:
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return int(v / 1000 if v > 1e12 else v)
    try:
        return int(datetime.fromisoformat(str(v).replace("Z", "+00:00")).timestamp())
    except ValueError:
        return None


def window(data: dict, key: str) -> dict | None:
    w = data.get(key)
    if not isinstance(w, dict):
        return None
    used = w.get("utilization")
    if not isinstance(used, (int, float)):
        return None
    return {"used": float(used), "resetsAt": epoch(w.get("resets_at"))}


def main() -> None:
    oauth = credentials()

    expires = epoch(oauth.get("expiresAt"))
    if expires is not None and expires <= time.time():
        fail("expired", "Sign-in expired, open Claude Code to renew it")

    req = urllib.request.Request(
        URL,
        headers={
            "Authorization": f"Bearer {oauth['accessToken']}",
            "anthropic-beta": "oauth-2025-04-20",
            "Accept": "application/json",
            "User-Agent": "caelestia-shell",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as r:
            data = json.load(r)
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            fail("expired", "Sign-in expired, open Claude Code to renew it")
        fail("http", f"HTTP {e.code}")
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        fail("network", str(getattr(e, "reason", e)))
    except ValueError:
        fail("http", "Unreadable response")

    if "--raw" in sys.argv:
        print(json.dumps(data, indent=2), file=sys.stderr)

    emit({
        "type": "usage",
        "plan": oauth.get("subscriptionType") or "",
        "fiveHour": window(data, "five_hour"),
        "weekly": window(data, "seven_day"),
        "fetchedAt": int(time.time()),
    })


if __name__ == "__main__":
    main()
