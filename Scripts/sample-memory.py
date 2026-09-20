#!/usr/bin/env python3
"""Read-only RSS/CPU sampling. Does not launch, quit, or change the observed app."""
import argparse
import csv
import datetime
import os
import pathlib
import statistics
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pid", type=int)
    parser.add_argument("--seconds", type=float, default=300)
    parser.add_argument("--interval", type=float, default=5)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    if args.pid <= 0 or args.seconds < 0 or args.interval <= 0:
        parser.error("PID and interval must be positive; seconds must be nonnegative")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    process_start = None
    resident_sizes = []
    with args.output.open("x", newline="") as output:
        writer = csv.writer(output)
        writer.writerow(["timestamp", "sample_elapsed_seconds", "process_elapsed", "rss_kib", "ps_cpu_percent"])
        while True:
            result = subprocess.run(
                ["ps", "-p", str(args.pid), "-o", "lstart=,etime=,rss=,pcpu="],
                text=True, capture_output=True, env={**os.environ, "LC_ALL": "C"}, check=True)
            fields = result.stdout.split()
            if len(fields) != 8:
                raise RuntimeError("Process disappeared or ps returned an unexpected result")
            identity = " ".join(fields[:5])
            if process_start is not None and identity != process_start:
                raise RuntimeError("PID was reused; refusing to combine different processes")
            process_start = identity
            elapsed = time.monotonic() - start
            resident_sizes.append(int(fields[6]))
            writer.writerow([datetime.datetime.now().astimezone().isoformat(), round(elapsed, 3),
                             fields[5], int(fields[6]), float(fields[7])])
            output.flush()
            if elapsed >= args.seconds:
                break
            time.sleep(min(args.interval, args.seconds - elapsed))
    print(f"{len(resident_sizes)} samples; RSS median {statistics.median(resident_sizes) / 1024:.2f} MiB, "
          f"peak {max(resident_sizes) / 1024:.2f} MiB. CSV: {args.output}")
    print("RSS is not Activity Monitor's Memory metric; ps CPU is its reported recent utilization.")


if __name__ == "__main__":
    main()
