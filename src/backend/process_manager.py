from __future__ import annotations

try:
    import psutil
except Exception:  # pragma: no cover
    psutil = None

from utils.helpers import human_size


class ProcessManagerService:
    def list_processes(self, sort_by: str = "memory") -> dict:
        if not psutil:
            return {"ok": False, "message": "缺少 psutil 依赖", "items": []}

        rows: list[dict] = []
        for proc in psutil.process_iter(
            ["pid", "name", "username", "memory_info", "cpu_percent", "exe"]
        ):
            try:
                info = proc.info
                mem_bytes = info["memory_info"].rss if info.get("memory_info") else 0
                rows.append(
                    {
                        "pid": info.get("pid"),
                        "name": info.get("name") or "未知进程",
                        "user": info.get("username") or "",
                        "cpu": round(info.get("cpu_percent") or 0, 1),
                        "memory": mem_bytes,
                        "memoryText": human_size(mem_bytes),
                        "exe": info.get("exe") or "",
                    }
                )
            except Exception:
                continue

        if sort_by == "cpu":
            rows.sort(key=lambda item: item["cpu"], reverse=True)
        elif sort_by == "name":
            rows.sort(key=lambda item: item["name"].lower())
        else:
            rows.sort(key=lambda item: item["memory"], reverse=True)

        return {"ok": True, "items": rows}

    def process_detail(self, pid: int) -> dict:
        if not psutil:
            return {"ok": False, "message": "缺少 psutil 依赖"}
        try:
            proc = psutil.Process(pid)
            memory = proc.memory_info()
            return {
                "ok": True,
                "detail": {
                    "pid": proc.pid,
                    "name": proc.name(),
                    "status": proc.status(),
                    "exe": proc.exe(),
                    "cmdline": " ".join(proc.cmdline()),
                    "memory": human_size(memory.rss),
                    "threads": proc.num_threads(),
                },
            }
        except Exception as exc:
            return {"ok": False, "message": f"读取进程详情失败: {exc}"}

    def terminate(self, pid: int, force: bool = False) -> dict:
        if not psutil:
            return {"ok": False, "message": "缺少 psutil 依赖"}
        try:
            proc = psutil.Process(pid)
            name = proc.name()
            if force:
                proc.kill()
            else:
                proc.terminate()
            return {"ok": True, "message": f"已结束进程: {name} ({pid})"}
        except Exception as exc:
            return {"ok": False, "message": f"结束进程失败: {exc}"}
