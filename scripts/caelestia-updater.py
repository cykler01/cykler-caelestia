#!/usr/bin/env python3
import json
import shutil
import subprocess
import sys
import tarfile
import tempfile
from datetime import datetime
from pathlib import Path

STATE_DIR = Path.home() / ".local/state/caelestia-updater"
BACKUP_DIR = STATE_DIR / "backups"
HISTORY_FILE = STATE_DIR / "history.json"
CAELESTIA_CONFIG = Path.home() / ".config/caelestia"

HYPR_KEYWORDS = {
    "hyprland", "hyprland-git", "hyprpaper", "hyprlock", "hypridle",
    "xdg-desktop-portal-hyprland", "aquamarine", "hyprutils",
    "hyprlang", "hyprgraphics", "hyprcursor", "hyprwayland-scanner",
}


def run(cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True)


def aur_helper():
    for helper in ("paru", "yay"):
        if shutil.which(helper):
            return helper
    return None


def prune_backups(entries):
    if not BACKUP_DIR.exists():
        return
    keep = {
        Path(e["config_backup"]).resolve()
        for e in entries
        if e.get("config_backup")
    }
    for archive in BACKUP_DIR.glob("caelestia-config-*.tar.gz"):
        if archive.resolve() not in keep:
            archive.unlink(missing_ok=True)


def load_history():
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if not HISTORY_FILE.exists():
        return []
    try:
        entries = json.loads(HISTORY_FILE.read_text())
        valid = [
            e for e in entries
            if e.get("snapper_id") is not None
            or (e.get("config_backup") and Path(e["config_backup"]).exists())
        ]
        if len(valid) != len(entries):
            save_history(valid)
        else:
            prune_backups(valid)
        return valid
    except Exception:
        return []


def save_history(entries):
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    trimmed = entries[:25]
    HISTORY_FILE.write_text(json.dumps(trimmed, indent=2))
    prune_backups(trimmed)


def create_snapper_snapshot(target: str):
    if not shutil.which("snapper"):
        return None
    res = run([
        "pkexec", "snapper", "-c", "root", "create",
        "--type", "pre",
        "--print-number",
        "--description", f"caelestia-updater: {target}",
    ])
    if res.returncode != 0:
        return None
    num = res.stdout.strip()
    return int(num) if num.isdigit() and int(num) > 0 else None


def git_head(repo: Path | None):
    if not repo or not (repo / ".git").exists():
        return None
    res = run(["git", "rev-parse", "--short", "HEAD"], cwd=repo)
    return res.stdout.strip() if res.returncode == 0 else None


def backup_caelestia_config(snap_tag: str):
    if not CAELESTIA_CONFIG.exists():
        return None
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    archive_path = BACKUP_DIR / f"caelestia-config-{snap_tag}.tar.gz"
    with tarfile.open(archive_path, "w:gz") as tar:
        tar.add(CAELESTIA_CONFIG, arcname="caelestia")
    return str(archive_path)


def is_shell_pkg(pkg_name: str):
    return pkg_name == "caelestia-shell" or pkg_name.startswith("caelestia-shell-")


def is_hypr_pkg(pkg_name: str):
    return pkg_name in HYPR_KEYWORDS or pkg_name.startswith("hypr")


def is_caelestia_pkg(pkg_name: str):
    return "caelestia" in pkg_name and not is_shell_pkg(pkg_name)


def list_pending_updates():
    if not shutil.which("checkupdates"):
        return [], False, "pacman-contrib (checkupdates) is required to check repo updates safely"

    helper = aur_helper()
    repo_pkgs = []
    aur_pkgs = []
    errors = []

    res = run(["checkupdates"])
    if res.returncode == 0:
        repo_pkgs = res.stdout.splitlines()
    elif res.returncode != 2:
        errors.append(res.stderr.strip() or f"checkupdates failed ({res.returncode})")

    if helper:
        res = run([helper, "-Qua"])
        if res.returncode == 0:
            aur_pkgs = res.stdout.splitlines()
        elif res.returncode != 1 and res.stderr.strip():
            errors.append(res.stderr.strip())

    combined = []
    for line in repo_pkgs + aur_pkgs:
        clean = line.strip()
        if not clean:
            continue
        pkg_name = clean.split()[0].lower()
        if is_shell_pkg(pkg_name):
            continue
        combined.append(clean)

    if errors and not combined:
        return [], False, errors[0]
    return combined, True, ""


def classify_updates(all_pkgs: list[str]):
    hypr_pkgs = []
    caelestia_pkgs = []
    sys_pkgs = []

    for p in all_pkgs:
        pkg_name = p.split()[0].lower()
        if is_hypr_pkg(pkg_name):
            hypr_pkgs.append(p)
        elif is_caelestia_pkg(pkg_name):
            caelestia_pkgs.append(p)
        else:
            sys_pkgs.append(p)

    return sys_pkgs, hypr_pkgs, caelestia_pkgs


def cmd_status():
    all_pkgs, can_check, check_error = list_pending_updates()
    sys_pkgs, hypr_pkgs, caelestia_pkgs = classify_updates(all_pkgs)

    payload = {
        "can_check": can_check,
        "check_error": check_error,
        "cachyos": {"count": len(sys_pkgs), "items": sys_pkgs[:15]},
        "hyprland": {"count": len(hypr_pkgs), "items": hypr_pkgs},
        "caelestia": {"count": len(caelestia_pkgs), "items": caelestia_pkgs},
        "history": load_history(),
    }
    print(json.dumps(payload))


def record_restore_point(target: str, note: str, snap_id=None, config_backup=None, repo: Path | None = None):
    if snap_id is None and not config_backup:
        return
    history = load_history()
    entry = {
        "id": datetime.now().strftime("%Y%m%d-%H%M%S"),
        "timestamp": datetime.now().strftime("%d %b %Y, %H:%M"),
        "target": target,
        "note": note,
        "snapper_id": snap_id,
        "config_backup": config_backup,
        "shell_head": git_head(repo),
    }
    history.insert(0, entry)
    save_history(history)


def stream_cmd(cmd, cwd=None):
    proc = subprocess.Popen(
        cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    )
    assert proc.stdout is not None
    tail = []
    for line in proc.stdout:
        clean = line.rstrip()
        tail.append(clean)
        tail = tail[-15:]
        print(f"LOG:{clean}", flush=True)
    proc.wait()
    if proc.returncode != 0:
        joined = chr(10).join(tail).lower()
        if proc.returncode in (126, 127) or "authentication" in joined or "dismissed" in joined or "a password is required" in joined:
            raise RuntimeError("Authentication failed or polkit prompt was dismissed")
        raise RuntimeError(f"Command failed ({proc.returncode}): {tail[-1] if tail else str(cmd)}")


def pkg_install_cmd(pkgs: list[str] | None = None):
    helper = aur_helper()
    ignore_flags = ["--ignore", "caelestia-shell,caelestia-shell-git"]
    if helper:
        if pkgs is None:
            return [helper, "-Syu", "--noconfirm", "--sudo", "pkexec", *ignore_flags]
        return [helper, "-S", "--needed", "--noconfirm", "--sudo", "pkexec", *pkgs]
    if shutil.which("pacman"):
        if pkgs is None:
            return ["pkexec", "pacman", "-Syu", "--noconfirm", *ignore_flags]
        return ["pkexec", "pacman", "-S", "--needed", "--noconfirm", *pkgs]
    raise RuntimeError("Neither paru, yay, nor pacman was found in PATH")


def cmd_update(target: str, repo: Path | None):
    tag = datetime.now().strftime("%Y%m%d-%H%M%S")
    try:
        if target not in ("cachyos", "hyprland", "caelestia", "all"):
            raise RuntimeError(f"Unknown update target: {target}")

        print("STEP:Creating pre-update restore point...", flush=True)
        pre_snap = create_snapper_snapshot(target)
        cfg_bak = backup_caelestia_config(tag) if target in ("caelestia", "all") else None
        record_restore_point(target, f"Before {target} update", snap_id=pre_snap, config_backup=cfg_bak, repo=repo)

        if target == "hyprland":
            print("STEP:Updating Hyprland ecosystem...", flush=True)
            all_pkgs, can_check, check_error = list_pending_updates()
            if not can_check:
                raise RuntimeError(check_error or "Cannot check pending updates")
            _, hypr_pkgs, _ = classify_updates(all_pkgs)
            pkgs = [p.split()[0] for p in hypr_pkgs if p]
            if pkgs:
                stream_cmd(pkg_install_cmd(pkgs))

        elif target == "caelestia":
            print("STEP:Updating Caelestia CLI & packages...", flush=True)
            all_pkgs, can_check, check_error = list_pending_updates()
            if not can_check:
                raise RuntimeError(check_error or "Cannot check pending updates")
            _, _, caelestia_pkgs = classify_updates(all_pkgs)
            pkgs = [p.split()[0] for p in caelestia_pkgs if p]
            if pkgs:
                stream_cmd(pkg_install_cmd(pkgs))
            else:
                helper = aur_helper()
                if not helper:
                    raise RuntimeError("Neither paru nor yay is installed to update caelestia-cli")
                stream_cmd(pkg_install_cmd(["caelestia-cli"]))

        elif target == "cachyos":
            print("STEP:Updating CachyOS & AUR packages...", flush=True)
            all_pkgs, can_check, check_error = list_pending_updates()
            if not can_check:
                raise RuntimeError(check_error or "Cannot check pending updates")
            sys_pkgs, _, _ = classify_updates(all_pkgs)
            pkgs = [p.split()[0] for p in sys_pkgs if p]
            if pkgs:
                stream_cmd(pkg_install_cmd(pkgs))

        elif target == "all":
            print("STEP:Updating all system & AUR packages...", flush=True)
            stream_cmd(pkg_install_cmd(None))

        print("DONE:1", flush=True)
    except Exception as exc:
        print(f"ERROR:{exc}", flush=True)
        sys.exit(1)


def restore_config_archive(archive_path: Path):
    with tempfile.TemporaryDirectory(prefix="caelestia-restore-") as tmpdir:
        tmp_root = Path(tmpdir)
        with tarfile.open(archive_path, "r:gz") as tar:
            tar.extractall(path=tmp_root, filter="data")

        extracted = tmp_root / "caelestia"
        if not extracted.is_dir():
            raise RuntimeError("Config backup archive is invalid or missing caelestia directory")

        ts = datetime.now().strftime("%Y%m%d-%H%M%S")
        staged_old = CAELESTIA_CONFIG.parent / f".caelestia-pre-rollback-{ts}"
        moved_existing = False
        try:
            if CAELESTIA_CONFIG.exists():
                CAELESTIA_CONFIG.rename(staged_old)
                moved_existing = True
            shutil.move(str(extracted), str(CAELESTIA_CONFIG))
            if moved_existing and staged_old.exists():
                shutil.rmtree(staged_old)
        except Exception:
            if CAELESTIA_CONFIG.exists():
                shutil.rmtree(CAELESTIA_CONFIG, ignore_errors=True)
            if moved_existing and staged_old.exists():
                staged_old.rename(CAELESTIA_CONFIG)
            raise


def cmd_rollback(entry_id: str):
    history = load_history()
    entry = next((h for h in history if h["id"] == entry_id), None)
    if not entry:
        print(f"ERROR:Restore point {entry_id} not found", flush=True)
        sys.exit(1)

    try:
        has_cfg = bool(entry.get("config_backup") and Path(entry["config_backup"]).exists())
        has_snap = bool(entry.get("snapper_id"))
        if not has_cfg and not has_snap:
            raise RuntimeError("This restore point has no Btrfs snapshot or config backup attached")

        if has_cfg:
            print("STEP:Restoring ~/.config/caelestia backup...", flush=True)
            restore_config_archive(Path(entry["config_backup"]))

        if has_snap:
            snap_id = entry["snapper_id"]
            print(f"STEP:Rolling back root filesystem to Snapper snapshot #{snap_id}...", flush=True)
            stream_cmd(["pkexec", "snapper", "-c", "root", "rollback", str(snap_id)])
            print("WARN:Btrfs snapshot restored. Reboot your PC to boot into the rolled-back system.", flush=True)

        print("DONE:1", flush=True)
    except Exception as exc:
        print(f"ERROR:{exc}", flush=True)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: caelestia-updater.py [status|update <target> [repo_path]|rollback <id>]")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "status":
        cmd_status()
    elif cmd == "update" and len(sys.argv) >= 3:
        repo_arg = Path(sys.argv[3]) if len(sys.argv) >= 4 and sys.argv[3] else None
        cmd_update(sys.argv[2], repo_arg)
    elif cmd == "rollback" and len(sys.argv) >= 3:
        cmd_rollback(sys.argv[2])
    else:
        sys.exit(1)
