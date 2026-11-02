#!/usr/bin/env python3
"""Stream lightweight per-process CPU, GPU and disk-I/O percentages as JSON."""

import json
import os
import re
import subprocess
import time


def read_cpu_total():
    with open("/proc/stat", encoding="ascii") as proc_stat:
        fields = proc_stat.readline().split()[1:]
    return sum(int(value) for value in fields)


def read_memory_total():
    try:
        with open("/proc/meminfo", encoding="ascii") as meminfo:
            for line in meminfo:
                if line.startswith("MemTotal:"):
                    return int(line.split()[1]) * 1024
    except (FileNotFoundError, ValueError):
        pass
    return 1


def read_network_usage():
    try:
        output = subprocess.run(
            ["ss", "-tinpH"],
            capture_output=True,
            text=True,
            timeout=1.2,
            check=False,
        ).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return {}

    usage = {}
    current_pid = None
    for line in output.splitlines():
        if line and not line[0].isspace():
            match = re.search(r"pid=(\d+)", line)
            current_pid = int(match.group(1)) if match else None
        if current_pid is None:
            continue
        for key, value in re.findall(r"\b(bytes_sent|bytes_received):(\d+)", line):
            usage[current_pid] = usage.get(current_pid, 0) + int(value)
    return usage


def read_gpu_usage():
    try:
        output = subprocess.run(
            ["nvidia-smi", "pmon", "-c", "1", "-s", "u"],
            capture_output=True,
            text=True,
            timeout=1.2,
            check=False,
        ).stdout
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return {}

    usage = {}
    for line in output.splitlines():
        fields = line.split()
        if len(fields) < 3 or fields[0].startswith("#") or not fields[1].isdigit():
            continue
        try:
            sm = float(fields[3]) if len(fields) > 3 and fields[3] != "-" else None
        except ValueError:
            sm = None
        if sm is not None:
            pid = int(fields[1])
            usage[pid] = max(usage.get(pid, 0.0), sm)
    return usage


def read_process(pid):
    try:
        with open(f"/proc/{pid}/stat", encoding="utf-8") as stat_file:
            stat = stat_file.read()
        end = stat.rfind(")")
        name = stat[stat.find("(") + 1 : end]
        fields = stat[end + 2 :].split()
        cpu_ticks = int(fields[11]) + int(fields[12])
        start_time = int(fields[19])

        io = {}
        with open(f"/proc/{pid}/io", encoding="ascii") as io_file:
            for line in io_file:
                key, value = line.split(":", 1)
                if key in ("read_bytes", "write_bytes"):
                    io[key] = int(value)

        with open(f"/proc/{pid}/cmdline", "rb") as cmdline_file:
            args = [part.decode(errors="replace") for part in cmdline_file.read().split(b"\0") if part]
        with open(f"/proc/{pid}/statm", encoding="ascii") as statm_file:
            rss_bytes = int(statm_file.read().split()[1]) * os.sysconf("SC_PAGE_SIZE")
        command = " ".join(args) if args else name
        return {
            "pid": pid,
            "name": name,
            "command": command,
            "cpu_ticks": cpu_ticks,
            "start_time": start_time,
            "io_bytes": io.get("read_bytes", 0) + io.get("write_bytes", 0),
            "rss_bytes": rss_bytes,
        }
    except (FileNotFoundError, PermissionError, ProcessLookupError, ValueError, IndexError):
        return None


def snapshot(previous, previous_total, cpu_count, previous_time):
    total = read_cpu_total()
    now = time.monotonic()
    elapsed = max(0.001, now - previous_time) if previous_time is not None else 1
    memory_total = read_memory_total()
    network_usage = read_network_usage()
    delta_total = max(1, total - previous_total) if previous_total is not None else 1
    rows = []
    next_previous = {}
    total_io = 0

    for entry in os.scandir("/proc"):
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        if pid <= 1 or pid == os.getpid():
            continue
        proc = read_process(pid)
        if proc is None:
            continue

        key = (pid, proc["start_time"])
        old = previous.get(key)
        delta_cpu = max(0, proc["cpu_ticks"] - old[0]) if old else 0
        delta_io = max(0, proc["io_bytes"] - old[1]) if old else 0
        net_bytes = network_usage.get(pid, 0)
        delta_net = max(0, net_bytes - old[2]) if old else 0
        next_previous[key] = (proc["cpu_ticks"], proc["io_bytes"], net_bytes)
        total_io += delta_io
        proc["cpu"] = delta_cpu / delta_total * cpu_count * 100
        proc["disk_bytes"] = delta_io
        proc["memory"] = proc.pop("rss_bytes") / memory_total * 100
        proc["network"] = delta_net / elapsed
        rows.append(proc)

    gpu = read_gpu_usage()
    for proc in rows:
        proc["gpu"] = gpu.get(proc["pid"])
        proc["disk"] = proc["disk_bytes"] / total_io * 100 if total_io else 0
        for key in ("cpu_ticks", "start_time", "io_bytes", "disk_bytes"):
            del proc[key]
    rows.sort(key=lambda proc: (proc["cpu"], proc["network"]), reverse=True)
    return rows[:250], next_previous, total, now


def main():
    previous = {}
    previous_total = None
    previous_time = None
    cpu_count = os.cpu_count() or 1
    while True:
        rows, previous, previous_total, previous_time = snapshot(previous, previous_total, cpu_count, previous_time)
        print(json.dumps(rows, ensure_ascii=False), flush=True)
        time.sleep(2)


if __name__ == "__main__":
    main()
