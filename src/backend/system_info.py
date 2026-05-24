from __future__ import annotations

import os
import platform
import socket
import time
from datetime import datetime, timedelta
from pathlib import Path

try:
    import psutil
except Exception:  # pragma: no cover
    psutil = None

try:
    import wmi
except Exception:  # pragma: no cover
    wmi = None

from utils.helpers import human_size, run_command


class SystemInfoService:
    def snapshot(self) -> dict:
        cpu_percent = psutil.cpu_percent(interval=0.08) if psutil else 0
        memory = psutil.virtual_memory() if psutil else None
        disk = psutil.disk_usage("C:/") if psutil else None
        boot_time = psutil.boot_time() if psutil else time.time()

        return {
            "ok": True,
            "cpu": round(cpu_percent, 1),
            "memory": round(memory.percent, 1) if memory else 0,
            "memoryUsed": human_size(memory.used) if memory else "未知",
            "memoryTotal": human_size(memory.total) if memory else "未知",
            "disk": round(disk.percent, 1) if disk else 0,
            "diskUsed": human_size(disk.used) if disk else "未知",
            "diskTotal": human_size(disk.total) if disk else "未知",
            "uptime": str(timedelta(seconds=int(time.time() - boot_time))),
            "temperature": self.temperature(),
            "host": socket.gethostname(),
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }

    def temperature(self) -> str:
        if psutil and hasattr(psutil, "sensors_temperatures"):
            try:
                temp_map = psutil.sensors_temperatures()
                for entries in temp_map.values():
                    if entries:
                        return f"{entries[0].current:.0f}°C"
            except Exception:
                pass
        return "需硬件支持"

    def hardware(self) -> dict:
        result = {
            "ok": True,
            "info": {
                "computer": socket.gethostname(),
                "system": platform.platform(),
                "processor": platform.processor()
                or os.environ.get("PROCESSOR_IDENTIFIER", "未知"),
                "python": platform.python_version(),
                "boot": "",
                "drives": [],
                "network": [],
                "gpu": [],
                "drivers": [],
            },
        }

        info = result["info"]
        if psutil:
            info["boot"] = datetime.fromtimestamp(psutil.boot_time()).strftime(
                "%Y-%m-%d %H:%M:%S"
            )
            for part in psutil.disk_partitions(all=False):
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    info["drives"].append(
                        {
                            "name": part.device,
                            "mount": part.mountpoint,
                            "type": part.fstype,
                            "total": human_size(usage.total),
                            "free": human_size(usage.free),
                            "percent": round(usage.percent, 1),
                        }
                    )
                except Exception:
                    continue

            for nic_name, addrs in psutil.net_if_addrs().items():
                ipv4 = [
                    item.address
                    for item in addrs
                    if getattr(item, "family", None) == socket.AF_INET
                ]
                if ipv4:
                    info["network"].append(
                        {"name": nic_name, "address": ", ".join(ipv4)}
                    )

        if wmi:
            try:
                client = wmi.WMI()
                info["gpu"] = [
                    {"name": adapter.Name, "driver": adapter.DriverVersion or "未知"}
                    for adapter in client.Win32_VideoController()
                ]
                info["drivers"] = [
                    {"name": d.DeviceName, "version": d.DriverVersion or "未知"}
                    for d in client.Win32_PnPSignedDriver()[:40]
                    if d.DeviceName
                ]
            except Exception:
                pass
        else:
            output = run_command(
                ["wmic", "path", "win32_VideoController", "get", "name"],
                timeout=6,
            )
            names = [line.strip() for line in output.splitlines() if line.strip()]
            if len(names) > 1:
                info["gpu"] = [{"name": name, "driver": "未知"} for name in names[1:]]

        return result

    def os_detail(self) -> dict:
        installed = ""
        try:
            output = run_command(
                [
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    "(Get-CimInstance Win32_OperatingSystem).InstallDate",
                ],
                timeout=6,
            )
            installed = output.strip()
        except Exception:
            installed = "未知"

        return {
            "ok": True,
            "name": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "installed": installed,
            "arch": platform.machine(),
            "python": platform.python_version(),
            "cwd": str(Path.cwd()),
        }
