"""Collect current PC status: name, CPU/RAM load, uptime."""

import socket
import time

import psutil


def get_status() -> dict:
    memory = psutil.virtual_memory()
    return {
        "hostname": socket.gethostname(),
        # Measure CPU over a short interval; a single instant reading is meaningless.
        "cpu_percent": psutil.cpu_percent(interval=0.5),
        "ram_percent": memory.percent,
        "ram_used_gb": round(memory.used / 1024**3, 1),
        "ram_total_gb": round(memory.total / 1024**3, 1),
        "uptime_seconds": int(time.time() - psutil.boot_time()),
    }
