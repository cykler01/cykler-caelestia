#!/usr/bin/env python3
#
# runner.py -- runs cykler-caelestia's own install.sh in a pty, outside the
# shell, so a reload or a restart of the shell cannot take the install down
# halfway through.
#
# the window follows <dir>/events.jsonl (one json object a line) and answers on
# <dir>/answers, a fifo. the password goes into sudo once and is never kept.
#
#   runner.py --src <checkout> --dir <runtime dir> [-- install.sh flags...]

import argparse
import fcntl
import json
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import threading
import time
from collections import deque

# csi, osc, charset picks and keypad modes, then any stray control but \t \n \r
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[()][0-9A-Za-z]|\x1b[=>78]|[\x00-\x08\x0b\x0c\x0e-\x1a\x1c-\x1f\x7f]")
PASSWORD = re.compile(r"(?i)(password|passphrase)[^\n]{0,80}:\s*$")
YESNO = re.compile(r"[\[(]\s*([YyNn])\s*/\s*([YyNn])\s*[\])]\s*[:?]?\s*$")
TEXTISH = re.compile(r"[:?>]\s*$")
# install.sh says where it is when CYKLER_INSTALLER is set. a marker is looked
# for anywhere in the line, not just at its start: a prompt that is still
# waiting leaves its text on the line, and the next marker lands on the end of
# it -- matching only at the start would drop the phase and log the marker
MARK = re.compile(r"@@cykler:(\w+)[ \t]*([^\n]*)")
# ninja counts its own work, which is the only honest progress here
NINJA = re.compile(r"^\[(\d+)/(\d+)\]")
# pacman's running total, for the long stretch where it downloads
PACMAN = re.compile(r"^\s*\(\s*(\d+)\s*/\s*(\d+)\s*\)")

# the pty's first job: sudo once and keep it warm. the install is long and its
# root parts come last, so a timestamp that expired mid-build would prompt again
WRAPPER = r"""
command -v sudo >/dev/null 2>&1 || exit 96
sudo -v -p '[caelestia] password for %u: ' || exit 97
printf '@@cykler:authok\n'
( while sleep 50; do sudo -n -v 2>/dev/null || exit 0; done ) &
keep=$!
trap 'kill "$keep" 2>/dev/null; sudo -k 2>/dev/null' EXIT
cd "$CYKLER_SRC" || exit 98
[ -f ./install.sh ] || exit 98
bash ./install.sh "$@"
"""

# what each phase is called in the window, and how far through it sits. the
# weights are rough but ordered: deps dominate a first install, build a rebuild
PHASES = [
    ("auth", "Asking for your password", 0.00),
    ("deps", "Installing dependencies", 0.04),
    ("configure", "Configuring the build", 0.55),
    ("build", "Building", 0.60),
    ("install", "Installing", 0.92),
    ("done", "Done", 1.00),
]
PHASE_AT = {name: at for name, _, at in PHASES}
# where an add-on sits: after the shell is in, before the end
ADDON_AT = 0.96
PHASE_TEXT = {name: text for name, text, _ in PHASES}


def collapse(line):
    # a carriage return redraws the line, so only its last drawing counts
    line = line.rstrip("\r")
    if "\r" in line:
        segs = [s for s in line.split("\r") if s.strip()]
        line = segs[-1] if segs else ""
    return line


class Events:
    def __init__(self, path):
        self.lock = threading.Lock()
        self.f = open(path, "a", buffering=1, encoding="utf-8")

    def emit(self, e, **kw):
        kw["e"] = e
        kw["t"] = round(time.time(), 3)
        with self.lock:
            self.f.write(json.dumps(kw, ensure_ascii=False) + "\n")


class Run:
    def __init__(self, a):
        self.a = a
        self.dir = a.dir
        os.makedirs(self.dir, exist_ok=True)
        self.ev = Events(os.path.join(self.dir, "events.jsonl"))
        self.log = open(os.path.join(self.dir, "install.log"), "a", buffering=1, encoding="utf-8")
        self.fifo = os.path.join(self.dir, "answers")
        if not os.path.exists(self.fifo):
            os.mkfifo(self.fifo, 0o600)

        self.pid = 0
        self.fd = -1
        self.carry = ""
        self.partial = ""
        self.answers = b""
        self.recent = deque(maxlen=12)
        self.ask = None
        self.asked_for = None
        self.seq = 0
        self.authok = False
        self.cancelled = False
        self.timed_out = False
        self.kill_at = 0.0
        self.last_out = time.monotonic()
        self.live_sent = ""
        self.live_at = 0.0
        self.phase = "auth"
        self.progress = 0.0
        self.warnings = []

    # --- the pty ---------------------------------------------------------

    def spawn(self):
        pid, fd = pty.fork()
        if pid == 0:
            env = dict(os.environ)
            env.update({
                "CYKLER_INSTALLER": "1",
                "CYKLER_SRC": os.path.abspath(self.a.src),
                "TERM": "dumb",
                "PAGER": "cat",
                "SYSTEMD_PAGER": "",
                "GIT_PAGER": "cat",
            })
            os.chdir(self.dir)
            os.execvpe("bash", ["bash", "-c", WRAPPER, "cykler-install"] + self.a.install_args, env)
        self.pid = pid
        self.fd = fd
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 132, 0, 0))
        self.ev.emit("phase", phase="auth", text=PHASE_TEXT["auth"], p=0.0, known=True)

    def send(self, text):
        try:
            os.write(self.fd, text.encode())
        except OSError:
            pass

    # --- output ----------------------------------------------------------

    def feed(self, text):
        self.last_out = time.monotonic()
        # anything new means a question on screen was not the last word
        if self.ask is not None:
            self.ev.emit("unask", n=self.ask["n"])
            self.ask = None
        self.asked_for = None
        s = self.carry + text
        k = s.rfind("\x1b")
        if k != -1 and len(s) - k < 32 and not ANSI.match(s, k):
            self.carry = s[k:]
            s = s[:k]
        else:
            self.carry = ""
        self.take(ANSI.sub("", s))

    def take(self, s):
        parts = s.split("\n")
        parts[0] = self.partial + parts[0]
        for line in parts[:-1]:
            self.line(collapse(line))
        tail = parts[-1]
        if "\r" in tail.rstrip("\r"):
            ended = tail.endswith("\r")
            tail = collapse(tail) + ("\r" if ended else "")
        self.partial = tail

    def line(self, text):
        m = MARK.search(text)
        while m:
            self.mark(m.group(1), m.group(2).strip())
            text = text[:m.start()] + text[m.end():]
            m = MARK.search(text)
        if not text.strip():
            return
        self.log.write(text + "\n")
        self.recent.append(text)
        low = text.lower()
        if "timed out reading password" in low:
            self.timed_out = True
        if text.strip().startswith("WARNING:") or low.startswith("warning:"):
            self.warnings.append(text.strip())
        self.step_progress(text)
        self.ev.emit("line", text=text)

    def mark(self, kind, rest):
        if kind == "authok":
            self.on_authok()
        elif kind == "phase":
            # add-ons are named by install.sh's own registry, so they are not
            # in the table above: they all sit between the install and the end
            if rest.startswith("addon:"):
                name = rest.split(":", 1)[1].replace("-", " ")
                self.phase_to(rest, "Installing the " + name)
            else:
                self.phase_to(rest, PHASE_TEXT.get(rest, rest.title()))
        elif kind == "note":
            self.ev.emit("note", text=rest)

    # progress inside a phase, from whatever is counting out loud
    def step_progress(self, text):
        span = 0.0
        base = 0.0
        frac = None
        m = NINJA.match(text.strip())
        if m and self.phase == "build":
            frac = int(m.group(1)) / max(1, int(m.group(2)))
            span = PHASE_AT["install"] - PHASE_AT["build"]
            base = PHASE_AT["build"]
        elif self.phase == "deps":
            m = PACMAN.match(text)
            if m:
                frac = int(m.group(1)) / max(1, int(m.group(2)))
                span = (PHASE_AT["configure"] - PHASE_AT["deps"]) * 0.9
                base = PHASE_AT["deps"]
        if frac is None:
            return
        self.set_progress(base + span * min(1.0, frac))
        self.ev.emit("progress", p=self.progress)

    def set_progress(self, p):
        self.progress = max(self.progress, min(1.0, p))

    def phase_to(self, phase, text, known=True):
        self.phase = phase
        at = ADDON_AT if phase.startswith("addon:") else PHASE_AT.get(phase, self.progress)
        self.set_progress(at)
        self.ev.emit("phase", phase=phase, text=text, p=self.progress, known=known)

    # --- questions -------------------------------------------------------

    def tick(self):
        now = time.monotonic()
        idle = now - self.last_out
        if self.carry and idle > 0.3:
            c = self.carry
            self.carry = ""
            self.take(ANSI.sub("", c))
        shown = collapse(self.partial)
        if shown != self.live_sent and now - self.live_at > 0.2:
            self.live_sent = shown
            self.live_at = now
            self.ev.emit("live", text=shown)
        if self.ask is None and shown.strip() and idle > 0.15 and shown != self.asked_for:
            self.classify(shown, idle)
        if self.kill_at and now > self.kill_at:
            self.kill_at = 0.0
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except OSError:
                pass

    def classify(self, shown, idle):
        kind = None
        default = ""
        m = YESNO.search(shown)
        if PASSWORD.search(shown):
            kind = "password"
        elif m:
            kind = "yesno"
            a, b = m.group(1), m.group(2)
            if a.isupper():
                default = a.lower()
            elif b.isupper():
                default = b.lower()
        elif idle > 2.5 and TEXTISH.search(shown):
            kind = "text"
        if kind is None:
            return
        self.asked_for = shown
        self.seq += 1
        retry = kind == "password" and any("try again" in l.lower() for l in list(self.recent)[-2:])
        context = [l for l in list(self.recent)[-5:] if l.strip() and not l.strip().startswith("==>")]
        self.ask = {
            "n": self.seq,
            "kind": kind,
            "text": shown.strip(),
            "def": default,
            "retry": retry,
            "context": context[-4:],
            "auth": not self.authok,
        }
        self.ev.emit("ask", **self.ask)

    def read_answers(self, ffd):
        try:
            chunk = os.read(ffd, 65536)
        except BlockingIOError:
            return
        self.answers += chunk
        while b"\n" in self.answers:
            raw, self.answers = self.answers.split(b"\n", 1)
            try:
                msg = json.loads(raw.decode("utf-8", "replace"))
            except ValueError:
                continue
            if msg.get("cancel"):
                self.cancel()
            elif self.ask is not None and msg.get("n") == self.ask["n"]:
                value = str(msg.get("value", "")).replace("\n", " ")
                kind = self.ask["kind"]
                self.send(value + "\n")
                self.ev.emit("answered", n=self.ask["n"])
                self.ask = None
                # an answer is not echoed by a password prompt, so log the fact
                if kind == "password":
                    self.log.write("(password sent)\n")

    def on_authok(self):
        if self.authok:
            return
        self.authok = True
        self.ev.emit("authok")
        self.set_progress(0.02)

    # --- lifetime ---------------------------------------------------------

    def cancel(self):
        if self.cancelled:
            return
        self.cancelled = True
        self.ev.emit("cancelled")
        try:
            os.killpg(self.pid, signal.SIGINT)
        except OSError:
            pass
        self.kill_at = time.monotonic() + 4

    def stop(self):
        try:
            os.killpg(self.pid, signal.SIGTERM)
        except OSError:
            pass

    def loop(self):
        ffd = os.open(self.fifo, os.O_RDONLY | os.O_NONBLOCK)
        try:
            while True:
                try:
                    r, _, _ = select.select([self.fd, ffd], [], [], 0.1)
                except InterruptedError:
                    continue
                if ffd in r:
                    self.read_answers(ffd)
                if self.fd in r:
                    try:
                        data = os.read(self.fd, 65536)
                    except OSError:
                        data = b""
                    if not data:
                        break
                    self.feed(data.decode("utf-8", "replace"))
                self.tick()
        finally:
            os.close(ffd)
        self.finish()

    def finish(self):
        if self.partial.strip():
            self.line(collapse(self.partial))
            self.partial = ""
        code = 0
        try:
            _, status = os.waitpid(self.pid, 0)
            code = os.waitstatus_to_exitcode(status)
        except (ChildProcessError, OSError):
            pass
        reason = ""
        if code == 96:
            reason = "sudo is not installed, so the install cannot reach root"
        elif code == 97:
            reason = "The password was not accepted" if not self.timed_out else "The password prompt timed out"
        elif code == 98:
            reason = "That folder has no install.sh to run"
        elif self.cancelled:
            reason = "Cancelled"
        if code == 0 and not self.cancelled:
            self.phase_to("done", PHASE_TEXT["done"])
        self.ev.emit("exit", code=code, reason=reason, cancelled=self.cancelled, warnings=self.warnings[-4:])
        self.log.close()


# install.sh's own flags are flags too, so argparse must never see them: it
# would die on the first --with it does not know, before a single event is
# written and with nothing on screen to say why. everything after -- is the
# install's, and without a -- the run's own options are taken off the front
def split_argv(argv):
    if "--" in argv:
        i = argv.index("--")
        return argv[:i], argv[i + 1:]
    mine = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--src", "--dir"):
            mine += argv[i:i + 2]
            i += 2
        elif a.startswith("--src=") or a.startswith("--dir=") or a in ("-h", "--help"):
            mine.append(a)
            i += 1
        else:
            break
    return mine, argv[i:]


def main():
    p = argparse.ArgumentParser(usage="%(prog)s --src <checkout> --dir <runtime dir> [-- install.sh flags...]")
    p.add_argument("--src", required=True, help="the checkout to install from")
    p.add_argument("--dir", required=True, help="runtime dir for events, answers and the log")
    mine, rest = split_argv(sys.argv[1:])
    a = p.parse_args(mine)
    a.install_args = rest
    run = Run(a)
    run.spawn()
    try:
        run.loop()
    except KeyboardInterrupt:
        run.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
